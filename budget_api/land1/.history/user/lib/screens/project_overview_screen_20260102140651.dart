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

  // Gemini API Key
  final String _geminiApiKey = "AIzaSyC7rjITsgx4nG4-a3tA9dDkWUW2uP7HRI4";

  // Activities form controllers
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

  // Helper: Logic to check if 1 hour has passed
  bool _canDelete(dynamic createdAt) {
    if (createdAt == null) return false;
    DateTime uploadTime;
    if (createdAt is Timestamp) {
      uploadTime = createdAt.toDate();
    } else if (createdAt is DateTime) {
      uploadTime = createdAt;
    } else {
      return false;
    }
    final difference = DateTime.now().difference(uploadTime);
    return difference.inHours < 1;
  }

  // Logic: Delete bill from Firestore
  Future<void> _deleteBill(String billId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Bill?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('This will remove the bill for both you and the admin. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _billsRef.doc(billId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _extractBillData(File imageFile) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final bytes = await imageFile.readAsBytes();

      final prompt = TextPart(
          "You are a receipt scanner. Look at this bill and extract the Merchant/Store Name and the Total Amount. "
          "Return the result ONLY as a JSON object like this: {'name': 'String', 'amount': double}. "
          "If you cannot see the name or amount, set them to null.");

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ]);

      final text = response.text ?? "{}";
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson);
    } catch (e) {
      debugPrint("AI Scan Error: $e");
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
        _donationController.text = data['amountDonated'] ?? '';
        _billingController.text = data['billingCurrent'] ?? '';
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
        'amountDonated': _donationController.text.trim(),
        'billingCurrent': _billingController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _loadLatestActivity();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work details saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
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
          title: Text('Upload Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF8E3D2C)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                        icon: isAiScanning ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                        label: Text(isAiScanning ? "AI Analyzing..." : "Scan with AI"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(labelText: 'Bill Name', filled: true, fillColor: const Color(0xFFFFF2D5)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Amount', filled: true, fillColor: const Color(0xFFFFF2D5)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final imgs = await _picker.pickMultiImage();
                        if (imgs != null) setStateSB(() => selectedImages = imgs);
                      },
                      child: const Text('Select Images Manually'),
                    ),
                    const SizedBox(height: 10),
                    if (selectedImages.isNotEmpty)
                      Wrap(spacing: 8, children: selectedImages.map((img) => Image.file(File(img.path), width: 50, height: 50, fit: BoxFit.cover)).toList()),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty || selectedImages.isEmpty) return;
                Navigator.pop(context);
                try {
                  final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                  final List<String> urls = [];
                  for (final x in selectedImages) {
                    final url = await CloudinaryService.uploadImage(imageFile: File(x.path), userId: _userId, projectId: _projectId);
                    urls.add(url);
                  }
                  await _billsRef.add({
                    'userId': _userId,
                    'projectId': _projectId,
                    'title': titleCtrl.text,
                    'amount': amount,
                    'imageUrls': urls,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  // UPDATED BILLS TAB WITH STREAMBUILDER
  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: Text("Upload New Bill", style: GoogleFonts.poppins(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)),
              onPressed: _showUploadBillDialog,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // NOTE: Requires Composite Index in Firebase
            stream: _billsRef
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: Indexing required or Permission denied."));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(child: Text('No bills found for this project.', style: GoogleFonts.poppins(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final docId = docs[index].id;
                  final createdAt = data['createdAt'];

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFB6862C))),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(data['title'] ?? 'Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (_canDelete(createdAt))
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  onPressed: () => _deleteBill(docId),
                                ),
                            ],
                          ),
                          Text("Amount: ₹${data['amount']}", style: GoogleFonts.poppins(color: Colors.brown)),
                          const SizedBox(height: 8),
                          if (data['imageUrls'] != null)
                            SizedBox(
                              height: 60,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: (data['imageUrls'] as List).map<Widget>((url) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _godNameController, decoration: const InputDecoration(labelText: 'God Name')),
            const SizedBox(height: 10),
            TextField(controller: _peopleController, decoration: const InputDecoration(labelText: 'People Visited'), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadingAdd ? null : _submitActivityForm, child: const Text("Save Work")),
          ],
        ),
      ),
    );
  }

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) => ListTile(title: Text(docs[i]['title'] ?? 'Txn'), subtitle: Text("₹${docs[i]['amount']}")),
        );
      },
    );
  }

  Widget _feedbackTab() => ProjectChatSection(projectId: _projectId, currentRole: 'user');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      appBar: AppBar(
        title: Text(widget.project['place'] ?? 'Overview', style: GoogleFonts.poppins()),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Activities'), Tab(text: 'Transactions'), Tab(text: 'Bills'), Tab(text: 'Feedback')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_activitiesTab(), _transactionsTab(), _billsTab(), _feedbackTab()],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _TabBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }
  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}