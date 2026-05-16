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

  // Local bills cache for UI
  List<Map<String, dynamic>> _localBills = [];

  // TODO: PASTE YOUR API KEY HERE
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

  // AI Extraction Logic - Uses Gemini 1.5 Flash for speed
  Future<Map<String, dynamic>?> _extractBillData(File imageFile) async {
    try {
      final model =
          GenerativeModel(model: 'gemini-1.5-flash', apiKey: _geminiApiKey);
      final bytes = await imageFile.readAsBytes();

      final prompt = TextPart(
          "You are a receipt scanner. Look at this bill and extract the Merchant/Store Name and the Total Amount. "
          "Return the result ONLY as a JSON object like this: {'name': 'String', 'amount': double}. "
          "If you cannot see the name or amount, set them to null.");

      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ]);

      final text = response.text ?? "{}";
      // Remove any markdown formatting the AI might add
      final cleanJson =
          text.replaceAll('```json', '').replaceAll('```', '').trim();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Work details saved')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
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
          title: Text(
            'Upload Bill',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: const Color(0xFF6A1F1A)),
          ),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- AI SCANNER BUTTON ---
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF8E3D2C)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isAiScanning
                            ? null
                            : () async {
                                final img = await _picker.pickImage(
                                    source: ImageSource.camera);
                                if (img != null) {
                                  setStateSB(() => isAiScanning = true);
                                  final data =
                                      await _extractBillData(File(img.path));
                                  if (data != null) {
                                    titleCtrl.text =
                                        data['name'] ?? titleCtrl.text;
                                    amountCtrl.text =
                                        data['amount']?.toString() ??
                                            amountCtrl.text;
                                    selectedImages = [img];
                                  }
                                  setStateSB(() => isAiScanning = false);
                                }
                              },
                        icon: isAiScanning
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF8E3D2C)))
                            : const Icon(Icons.auto_awesome,
                                color: Color(0xFF8E3D2C)),
                        label: Text(
                            isAiScanning ? "AI Analyzing..." : "Scan with AI",
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF8E3D2C))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFB6862C), thickness: 0.5),
                    const SizedBox(height: 12),

                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Bill Name',
                        labelStyle: GoogleFonts.poppins(color: Colors.brown),
                        filled: true,
                        fillColor: const Color(0xFFFFF2D5),
                        enabledBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Color(0xFFB6862C)),
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: GoogleFonts.poppins(color: Colors.brown),
                        filled: true,
                        fillColor: const Color(0xFFFFF2D5),
                        enabledBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Color(0xFFB6862C)),
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E3D2C)),
                      onPressed: () async {
                        final imgs = await _picker.pickMultiImage();
                        if (imgs != null && imgs.isNotEmpty) {
                          setStateSB(() => selectedImages = imgs);
                        }
                      },
                      child: Text('Add Images Manually',
                          style: GoogleFonts.poppins(color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    selectedImages.isEmpty
                        ? Text('No images selected',
                            style: GoogleFonts.poppins(color: Colors.grey))
                        : Wrap(
                            spacing: 8,
                            children: selectedImages
                                .map((img) => ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(File(img.path),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover),
                                    ))
                                .toList(),
                          ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: Colors.brown))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E3D2C)),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    amountCtrl.text.trim().isEmpty ||
                    selectedImages.isEmpty) return;
                Navigator.pop(context);
                try {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  final now = DateTime.now();
                  final List<String> urls = [];
                  for (final x in selectedImages) {
                    final url = await CloudinaryService.uploadImage(
                        imageFile: File(x.path),
                        userId: _userId,
                        projectId: _projectId);
                    urls.add(url);
                  }
                  final doc = await _billsRef.add({
                    'userId': _userId,
                    'projectId': _projectId,
                    'title': titleCtrl.text.trim(),
                    'amount': amount,
                    'imageUrls': urls,
                    'createdAt': now,
                  });
                  setState(() {
                    _localBills.insert(0, {
                      'id': doc.id,
                      'title': titleCtrl.text.trim(),
                      'amount': amount,
                      'imageUrls': urls,
                      'date': now
                    });
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Upload failed: $e')));
                }
              },
              child: Text('Upload',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // UI TAB BUILDERS
  Widget _billsTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload, color: Colors.white),
              label: Text("Upload Bill",
                  style:
                      GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
              onPressed: _showUploadBillDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E3D2C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _localBills.isEmpty
              ? Center(
                  child: Text('No bills yet',
                      style: GoogleFonts.poppins(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _localBills.length,
                  itemBuilder: (context, i) {
                    final bill = _localBills[i];
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                              color: Color(0xFFB6862C), width: 1)),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        title: Text(bill['title'],
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6A1F1A))),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("₹${bill['amount']}",
                                style:
                                    GoogleFonts.poppins(color: Colors.brown)),
                            const SizedBox(height: 4),
                            Text(
                                "Date: ${bill['date'].day}/${bill['date'].month}/${bill['date'].year}",
                                style:
                                    GoogleFonts.poppins(color: Colors.brown)),
                            const SizedBox(height: 8),
                            if (bill['imageUrls'] != null &&
                                (bill['imageUrls'] as List).isNotEmpty)
                              SizedBox(
                                height: 80,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: (bill['imageUrls'] as List)
                                      .map<Widget>((url) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.network(
                                                  url as String,
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
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
            Text('Work Details',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6A1F1A))),
            const SizedBox(height: 12),
            TextField(
              controller: _godNameController,
              decoration: InputDecoration(
                labelText: 'Name of God',
                labelStyle: GoogleFonts.poppins(color: Colors.brown),
                filled: true,
                fillColor: const Color(0xFFFFF2D5),
                enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFB6862C)),
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Part of work',
                style: GoogleFonts.poppins(color: Colors.brown, fontSize: 13)),
            const SizedBox(height: 4),
            Column(
              children: ['lingam', 'avudai', 'nandhi', 'shed']
                  .map((v) => RadioListTile<String>(
                        value: v,
                        groupValue: _workPart,
                        activeColor: const Color(0xFF8E3D2C),
                        title: Text(v[0].toUpperCase() + v.substring(1)),
                        onChanged: (val) {
                          if (val != null) setState(() => _workPart = val);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _peopleController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of people visited',
                labelStyle: GoogleFonts.poppins(color: Colors.brown),
                filled: true,
                fillColor: const Color(0xFFFFF2D5),
                enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFB6862C)),
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loadingAdd ? null : _submitActivityForm,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E3D2C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: _loadingAdd
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Save Work',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('projectId', isEqualTo: _projectId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty)
          return Center(
              child: Text('No transactions',
                  style: GoogleFonts.poppins(color: Colors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFB6862C), width: 1)),
              child: ListTile(
                title: Text(d['title'] ?? 'Txn',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6A1F1A))),
                subtitle: Text('₹${d['amount'] ?? ''}',
                    style: GoogleFonts.poppins(color: Colors.brown)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _feedbackTab() {
    return ProjectChatSection(projectId: _projectId, currentRole: 'user');
  }

  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF8E3D2C),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8E3D2C),
          tabs: [
            Tab(child: Text('Activities', style: GoogleFonts.poppins())),
            Tab(child: Text('Transactions', style: GoogleFonts.poppins())),
            Tab(child: Text('Bills', style: GoogleFonts.poppins())),
            Tab(child: Text('Feedback', style: GoogleFonts.poppins())),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectName = widget.project['place'] ?? 'Project';
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A1F1A), Color(0xFFB6862C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Project Overview',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(projectName,
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 16)),
                      ],
                    )),
                  ],
                ),
              ),
            ),
            _buildTabBar(),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _activitiesTab(),
                  _transactionsTab(),
                  _billsTab(),
                  _feedbackTab()
                ],
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
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
        color: Colors.white,
        child: Material(color: Colors.white, child: _tabBar));
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      oldDelegate._tabBar != _tabBar;
}
3