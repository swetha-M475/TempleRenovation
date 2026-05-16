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
  
  // This is the constructor that was causing the "No named parameter" error
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

  // Form Controllers
  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();
  final TextEditingController _donationController = TextEditingController();
  final TextEditingController _billingController = TextEditingController();
  String _workPart = 'lingam';

  // Helper getters to access project data safely
  String get _projectId => (widget.project['id'] ?? '').toString();
  String get _userId => (widget.project['userId'] ?? '').toString();

  CollectionReference<Map<String, dynamic>> get _activitiesRef => _firestore.collection('activities');
  CollectionReference<Map<String, dynamic>> get _billsRef => _firestore.collection('bills');

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

  Future<void> _loadLatestActivity() async {
    try {
      final snap = await _activitiesRef
          .where('projectId', isEqualTo: _projectId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          _godNameController.text = data['godName'] ?? '';
          _peopleController.text = data['peopleVisited'] ?? '';
          _donationController.text = data['amountDonated'] ?? '';
          _billingController.text = data['billingCurrent'] ?? '';
          _workPart = (data['workPart'] ?? 'lingam') as String;
        });
      }
    } catch (e) {
      debugPrint("Error loading activity: $e");
    }
  }

  Future<Map<String, dynamic>?> _extractBillData(File imageFile) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final bytes = await imageFile.readAsBytes();
      final prompt = TextPart("Extract Merchant Name and Total Amount from this bill. Return JSON: {'name': 'string', 'amount': double}");
      final response = await model.generateContent([Content.multi([prompt, DataPart('image/jpeg', bytes)])]);
      final cleanJson = (response.text ?? "{}").replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson);
    } catch (e) {
      return null;
    }
  }

  Future<void> _showUploadBillDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];
    bool scanning = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSB) => AlertDialog(
          backgroundColor: const Color(0xFFFFF7E8),
          title: Text('Upload Bill', style: GoogleFonts.poppins(color: const Color(0xFF6A1F1A))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: scanning ? null : () async {
                    final img = await _picker.pickImage(source: ImageSource.camera);
                    if (img != null) {
                      setSB(() => scanning = true);
                      final data = await _extractBillData(File(img.path));
                      if (data != null) {
                        titleCtrl.text = data['name'] ?? "";
                        amountCtrl.text = data['amount']?.toString() ?? "";
                        selectedImages = [img];
                      }
                      setSB(() => scanning = false);
                    }
                  },
                  icon: scanning ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                  label: Text(scanning ? "Scanning..." : "Scan with AI"),
                ),
                const SizedBox(height: 10),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill Name')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final List<String> urls = [];
                for (var img in selectedImages) {
                  final url = await CloudinaryService.uploadImage(imageFile: File(img.path), userId: _userId, projectId: _projectId);
                  urls.add(url);
                }
                await _billsRef.add({
                  'projectId': _projectId,
                  'title': titleCtrl.text,
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'imageUrls': urls,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              },
              child: const Text('Upload'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project['place'] ?? 'Project Details', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF6A1F1A),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Work'), Tab(text: 'Bills'), Tab(text: 'Txns'), Tab(text: 'Chat')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(),
          _billsTab(),
          const Center(child: Text('Transactions')),
          ProjectChatSection(projectId: _projectId, currentRole: 'user'),
        ],
      ),
    );
  }

  Widget _activitiesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(controller: _godNameController, decoration: const InputDecoration(labelText: 'God Name')),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _submitActivityForm, child: const Text('Save Details')),
        ],
      ),
    );
  }

  Future<void> _submitActivityForm() async {
    await _activitiesRef.add({
      'projectId': _projectId,
      'godName': _godNameController.text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!')));
  }

  Widget _billsTab() {
    return Column(
      children: [
        ElevatedButton(onPressed: _showUploadBillDialog, child: const Text("Add Bill")),
        Expanded(
          child: StreamBuilder(
            stream: _billsRef.where('projectId', isEqualTo: _projectId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(docs[i]['title']),
                  subtitle: Text("₹${docs[i]['amount']}"),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}