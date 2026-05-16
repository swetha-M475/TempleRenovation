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

  // API Key - Keep this secure in a real production app
  final String _geminiApiKey = "AIzaSyC7rjITsgx4nG4-a3tA9dDkWUW2uP7HRI4";

  // Form controllers
  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  String _workPart = 'lingam';

  // Getters for easy access
  String get _projectId => widget.project['id'] as String;
  String get _userId => (widget.project['userId'] ?? '') as String;

  // Collection References
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
    super.dispose();
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteBill(String docId) async {
    try {
      await _billsRef.doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill deleted successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')));
    }
  }

  // --- AI EXTRACTION LOGIC ---
  Future<Map<String, dynamic>?> _extractBillData(File imageFile) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final bytes = await imageFile.readAsBytes();

      final prompt = TextPart(
          "You are a receipt scanner. Look at this bill and extract the Merchant Name and the Total Amount. "
          "Return ONLY a raw JSON object: {'name': 'String', 'amount': double}. No markdown, no explanation.");

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ]);

      String text = response.text ?? "{}";
      // Clean potential markdown formatting
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(text);
    } catch (e) {
      debugPrint("AI Extraction Error: $e");
      return null;
    }
  }

  // --- LOAD LATEST ACTIVITY ---
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
    } catch (e) {
      debugPrint("Load Activity Error: $e");
    }
  }

  // --- SUBMIT ACTIVITY ---
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work details saved')));
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  // --- UPLOAD BILL DIALOG ---
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFB6862C), width: 2)),
          title: Text('Upload Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF6A1F1A))),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isAiScanning ? null : () async {
                          final img = await _picker.pickImage(source: ImageSource.camera);
                          if (img != null) {
                            setStateSB(() => isAiScanning = true);
                            final data = await _extractBillData(File(img.path));
                            if (data != null) {
                              titleCtrl.text = data['name'] ?? "";
                              amountCtrl.text = data['amount']?.toString() ?? "";
                              selectedImages = [img];
                            }
                            setStateSB(() => isAiScanning = false);
                          }
                        },
                        icon: isAiScanning ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                        label: Text(isAiScanning ? "AI Scanning..." : "Scan with AI"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Store/Item Name')),
                    TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () async {
                        final imgs = await _picker.pickMultiImage();
                        if (imgs != null) setStateSB(() => selectedImages = imgs);
                      },
                      icon: const Icon(Icons.photo_library),
                      label: Text(selectedImages.isEmpty ? "Add Images" : "${selectedImages.length} Images Selected"),
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
                
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading bill...")));

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
              child: const Text('Save Bill'),
            ),
          ],
        );
      },
    );
  }

  // --- BILLS TAB ---
  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 54, width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: Text("ADD NEW BILL", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              onPressed: _showUploadBillDialog,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E3D2C)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return Center(child: Text("No history found", style: GoogleFonts.poppins(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  final String billId = docs[i].id;
                  final DateTime date = (bill['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFB6862C), width: 0.5)),
                    child: ExpansionTile(
                      title: Text(bill['title'] ?? 'Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      subtitle: Text("₹${bill['amount']} • ${date.day}/${date.month}/${date.year}"),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteBill(billId)),
                      children: [
                        if (bill['imageUrls'] != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Wrap(
                              spacing: 8,
                              children: (bill['imageUrls'] as List).map((url) => ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                              )).toList(),
                            ),
                          )
                      ],
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

  // --- ACTIVITIES TAB ---
  Widget _activitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Update Progress', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF6A1F1A))),
          const SizedBox(height: 15),
          TextField(controller: _godNameController, decoration: const InputDecoration(labelText: 'Name of Deity', border: OutlineInputBorder())),
          const SizedBox(height: 20),
          Text('Select Work Area:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          Wrap(
            children: ['lingam', 'avudai', 'nandhi', 'shed'].map((v) => SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: v, groupValue: _workPart, title: Text(v), onChanged: (val) => setState(() => _workPart = val!),
              ),
            )).toList(),
          ),
          const SizedBox(height: 10),
          TextField(controller: _peopleController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of Visitors', border: OutlineInputBorder())),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 55,
            child: ElevatedButton(
              onPressed: _loadingAdd ? null : _submitActivityForm,
              child: _loadingAdd ? const CircularProgressIndicator() : const Text('SAVE PROGRESS'),
            ),
          ),
        ],
      ),
    );
  }

  // --- TRANSACTIONS TAB ---
  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('transactions').where('projectId', isEqualTo: _projectId).orderBy('date', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text("Error loading transactions"));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No transactions recorded"));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) => Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
              title: Text(docs[i]['title']), 
              subtitle: Text("Amount: ₹${docs[i]['amount']}"),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      appBar: AppBar(
        title: Text('Project History', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6A1F1A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFB6862C),
          tabs: const [Tab(text: 'Update'), Tab(text: 'Ledger'), Tab(text: 'Bills'), Tab(text: 'Feedback')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(),
          _transactionsTab(),
          _billsTab(),
          ProjectChatSection(projectId: _projectId, currentRole: 'user'),
        ],
      ),
    );
  }
}