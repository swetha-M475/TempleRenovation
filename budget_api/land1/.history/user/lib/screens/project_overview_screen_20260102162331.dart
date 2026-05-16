import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'project_chat_section.dart';
import '/services/cloudinary_service.dart';

class ProjectOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  bool _loadingAdd = false;

  final ImagePicker _picker = ImagePicker();

  final String _geminiApiKey = "AIzaSyC7rjITsgx4nG4-a3tA9dDkWUW2uP7HRI4";

  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _donationController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  String _workPart = 'lingam';

  String get _projectId => widget.project['id'] as String;
  String get _userId => (widget.project['userId'] ?? '') as String;

  CollectionReference<Map<String, dynamic>> get _activitiesRef =>
      _firestore.collection('activities');

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLatestActivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _godNameController.dispose();
    _peopleController.dispose();
    _donationController.dispose();
    _billingController.dispose();
    super.dispose();
  }

  // --- DELETE BILL LOGIC ---
  Future<void> _deleteBill(String docId) async {
    try {
      await _billsRef.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete bill: $e')));
    }
  }

  // --- DELETE ACTIVITY LOGIC ---
  Future<void> _deleteActivity(String docId) async {
    try {
      await _activitiesRef.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity history deleted')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<Map<String, dynamic>?> _extractBillData(File imageFile) async {
    try {
      final model =
          GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final bytes = await imageFile.readAsBytes();

      final prompt = TextPart(
          "You are a receipt scanner. Look at this bill and extract the Merchant/Store Name and the Total Amount. "
          "Return the result ONLY as a JSON object like this: {'name': 'String', 'amount': double}. ");

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ]);

      final text = response.text ?? "{}";
      final cleanJson =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadLatestActivity() async {
    try {
      final snap = await _activitiesRef
          .where('projectId', isEqualTo: _projectId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;

      final data = snap.docs.first.data();
      setState(() {
        _godNameController.text = data['godName'] ?? '';
        _peopleController.text = data['peopleVisited'] ?? '';
        _workPart = (data['workPart'] ?? 'lingam') as String;
      });
    } catch (_) {}
  }

  Future<void> _submitActivityForm() async {
    final godName = _godNameController.text.trim();
    if (godName.isEmpty) return;
    setState(() => _loadingAdd = true);
    try {
      await _activitiesRef.add({
        'userId': _userId,
        'projectId': _projectId,
        'godName': godName,
        'workPart': _workPart,
        'peopleVisited': _peopleController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Work details saved')));
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  Future<void> _showUploadBillDialog() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];
    bool isAiScanning = false;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFB6862C), width: 2),
          ),
          title: Text('Upload Bill',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF8E3D2C))),
                        onPressed: isAiScanning ? null : () async {
                          final img = await _picker.pickImage(source: ImageSource.camera);
                          if (img != null) {
                            setStateSB(() => isAiScanning = true);
                            final data = await _extractBillData(File(img.path));
                            if (data != null) {
                              titleCtrl.text = data['name'] ?? titleCtrl.text;
                              amountCtrl.text = data['amount']?.toString() ?? amountCtrl.text;
                              selectedImages = [img];
                            }
                            setStateSB(() => isAiScanning = false);
                          }
                        },
                        icon: isAiScanning ? const CircularProgressIndicator() : const Icon(Icons.auto_awesome),
                        label: Text(isAiScanning ? "AI Analyzing..." : "Scan with AI"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill Name')),
                    TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final imgs = await _picker.pickMultiImage();
                        if (imgs != null) setStateSB(() => selectedImages = imgs);
                      },
                      child: const Text('Add Images Manually'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
                Navigator.pop(context);
                final List<String> urls = [];
                for (final x in selectedImages) {
                  final url = await CloudinaryService.uploadImage(imageFile: File(x.path), userId: _userId, projectId: _projectId);
                  urls.add(url);
                }
                await _billsRef.add({
                  'userId': _userId,
                  'projectId': _projectId,
                  'title': titleCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'imageUrls': urls,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              },
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  // --- BILLS TAB (FIXED: NOW SHOWS DATABASE HISTORY) ---
  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 54, width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload, color: Colors.white),
              label: Text("Upload Bill", style: GoogleFonts.poppins(color: Colors.white)),
              onPressed: _showUploadBillDialog,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No bill history found', style: GoogleFonts.poppins(color: Colors.grey)));
              }
              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  final billId = docs[i].id;
                  final createdAt = (bill['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFB6862C), width: 1)),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      title: Text(bill['title'] ?? 'Untitled', 
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("₹${bill['amount']}", style: GoogleFonts.poppins(color: Colors.brown)),
                          Text("Date: ${createdAt.day}/${createdAt.month}/${createdAt.year}"),
                          const SizedBox(height: 8),
                          if (bill['imageUrls'] != null)
                            SizedBox(
                              height: 60,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: (bill['imageUrls'] as List).map<Widget>((url) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
                                  ),
                                )).toList(),
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteBill(billId),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _activitiesTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update Work', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
            const SizedBox(height: 12),
            TextField(controller: _godNameController, decoration: const InputDecoration(labelText: 'Name of God')),
            const SizedBox(height: 16),
            Column(
              children: ['lingam', 'avudai', 'nandhi', 'shed'].map((v) => RadioListTile<String>(
                value: v, groupValue: _workPart, title: Text(v), onChanged: (val) => setState(() => _workPart = val!),
              )).toList(),
            ),
            TextField(controller: _peopleController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Visitors')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(onPressed: _submitActivityForm, child: const Text('Save Work')),
            ),
            const SizedBox(height: 32),
            Text('Work History', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activitiesRef.where('projectId', isEqualTo: _projectId).orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    return ListTile(
                      title: Text(data['godName'] ?? ''),
                      subtitle: Text("${data['workPart']} - ${data['peopleVisited']} people"),
                      trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteActivity(docs[index].id)),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) => Card(
            child: ListTile(title: Text(docs[i]['title']), subtitle: Text('₹${docs[i]['amount']}')),
          ),
        );
      },
    );
  }

  Widget _feedbackTab() {
    return ProjectChatSection(projectId: _projectId, currentRole: 'user');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6A1F1A), Color(0xFFB6862C)])),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Text('Project Overview', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(pinned: true, delegate: _TabBarDelegate(TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF8E3D2C),
              tabs: const [Tab(text: 'Activities'), Tab(text: 'Transactions'), Tab(text: 'Bills'), Tab(text: 'Feedback')],
            ))),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [_activitiesTab(), _transactionsTab(), _billsTab(), _feedbackTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _TabBarDelegate(this._tabBar);
  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: Colors.white, child: _tabBar);
  @override bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}