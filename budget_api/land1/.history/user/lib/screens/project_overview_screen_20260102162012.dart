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
  // Fixed Constructor
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

  // AI Extraction Logic
  Future<Map<String, dynamic>?> _extractBillData(File imageFile) async {
    try {
      final model =
          GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final bytes = await imageFile.readAsBytes();

      final prompt = TextPart(
          "You are a receipt scanner. Extract Merchant Name and Total Amount. "
          "Return ONLY JSON: {'name': 'String', 'amount': double}.");

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ]);

      final cleanJson = (response.text ?? "{}")
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work details saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  Future<void> _showUploadBillDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];
    bool isAiScanning = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          backgroundColor: const Color(0xFFFFF7E8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFB6862C), width: 2),
          ),
          title: Text('Upload Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A))),
          content: SingleChildScrollView(
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
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill Name')),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final imgs = await _picker.pickMultiImage();
                    if (imgs != null) setStateSB(() => selectedImages = imgs);
                  }, 
                  child: const Text("Pick Images")
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
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
        ),
      ),
    );
  }

  // --- UI TABS (RESTORED STREAM) ---

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
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef.where('projectId', isEqualTo: _projectId).orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i].data();
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFB6862C))),
                    child: ListTile(
                      title: Text(bill['title'] ?? '', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      subtitle: Text("₹${bill['amount']}"),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _godNameController, decoration: const InputDecoration(labelText: 'Name of God')),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _submitActivityForm, child: const Text("Save Work")),
        ],
      ),
    );
  }

  Widget _transactionsTab() {
    return const Center(child: Text("Transactions Tab"));
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF6A1F1A), Color(0xFFB6862C)]),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    Text(widget.project['place'] ?? 'Project', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF8E3D2C),
                  tabs: const [Tab(text: 'Work'), Tab(text: 'Txns'), Tab(text: 'Bills'), Tab(text: 'Chat')],
                ),
              ),
            ),
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
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }
  @override bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}