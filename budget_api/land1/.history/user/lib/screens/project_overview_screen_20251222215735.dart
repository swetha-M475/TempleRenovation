import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

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

  List<Map<String, dynamic>> _localBills = [];

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
    _loadBills();
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

  // ================= LOAD ACTIVITY =================
  Future<void> _loadLatestActivity() async {
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
      _workPart = data['workPart'] ?? 'lingam';
    });
  }

  // ================= SAVE ACTIVITY =================
  Future<void> _submitActivityForm() async {
    if (_godNameController.text.trim().isEmpty) return;

    setState(() => _loadingAdd = true);

    await _activitiesRef.add({
      'userId': _userId,
      'projectId': _projectId,
      'godName': _godNameController.text.trim(),
      'workPart': _workPart,
      'peopleVisited': _peopleController.text.trim(),
      'amountDonated': _donationController.text.trim(),
      'billingCurrent': _billingController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _loadLatestActivity();

    if (mounted) {
      setState(() => _loadingAdd = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Work details saved')));
    }
  }

  // ================= LOAD BILLS =================
  Future<void> _loadBills() async {
    final snap = await _billsRef
        .where('projectId', isEqualTo: _projectId)
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      _localBills = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'],
          'amount': data['amount'],
          'imageUrls': data['imageUrls'] ?? [],
          'date': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        };
      }).toList();
    });
  }

  // ================= UPLOAD BILL =================
  Future<void> _showUploadBillDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Upload Bill'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill Name')),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final imgs = await _picker.pickMultiImage();
                  if (imgs != null) selectedImages = imgs;
                },
                child: const Text('Select Images'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty ||
                    amountCtrl.text.isEmpty ||
                    selectedImages.isEmpty) return;

                Navigator.pop(context);

                final List<String> urls = [];
                for (final x in selectedImages) {
                  final url = await CloudinaryService.uploadImage(
                    imageFile: File(x.path),
                    userId: _userId,
                    projectId: _projectId,
                  );
                  urls.add(url);
                }

                await _billsRef.add({
                  'userId': _userId,
                  'projectId': _projectId,
                  'title': titleCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text) ?? 0,
                  'imageUrls': urls,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                await _loadBills();
              },
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  // ================= BILLS TAB =================
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
              label: const Text("Upload Bill"),
              onPressed: _showUploadBillDialog,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _localBills.isEmpty
              ? const Center(child: Text('No bills yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _localBills.length,
                  itemBuilder: (_, i) {
                    final bill = _localBills[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        title: Text(bill['title']),
                        subtitle: Text('₹${bill['amount']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await _billsRef.doc(bill['id']).delete();
                            await _loadBills();
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ================= OTHER TABS (UNCHANGED) =================
  Widget _activitiesTab() => const SizedBox();
  Widget _transactionsTab() => const SizedBox();
  Widget _feedbackTab() => const SizedBox();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: [
          _activitiesTab(),
          _transactionsTab(),
          _billsTab(),
          _feedbackTab(),
        ],
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Activities'),
          Tab(text: 'Transactions'),
          Tab(text: 'Bills'),
          Tab(text: 'Feedback'),
        ],
      ),
    );
  }
}
