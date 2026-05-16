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
        'createdAt': Timestamp.now(),
      });

      await _loadLatestActivity();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Work details saved')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingAdd = false);
    }
  }

  Future<void> _showUploadBillDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<XFile> images = [];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upload Bill'),
        content: StatefulBuilder(
          builder: (c, sb) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill Name')),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final picked = await _picker.pickMultiImage();
                  if (picked != null) sb(() => images = picked);
                },
                child: const Text('Select Images'),
              ),
              Wrap(
                children: images
                    .map((e) => Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.file(File(e.path), width: 60, height: 60, fit: BoxFit.cover),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty || images.isEmpty) return;
              Navigator.pop(context);

              final urls = <String>[];
              for (final img in images) {
                final url = await CloudinaryService.uploadImage(
                  imageFile: File(img.path),
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
                'createdAt': Timestamp.now(),
              });
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

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
              icon: const Icon(Icons.upload),
              label: const Text('Upload Bill'),
              onPressed: _showUploadBillDialog,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef
                .where('userId', isEqualTo: _userId)
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.docs.isEmpty) return const Center(child: Text('No bills yet'));

              return ListView(
                children: snap.data!.docs.map((doc) {
                  final d = doc.data();
                  return Card(
                    child: ListTile(
                      title: Text(d['title']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₹${d['amount']}'),
                          SizedBox(
                            height: 80,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: (d['imageUrls'] as List)
                                  .map((u) => Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Image.network(u, width: 80, height: 80, fit: BoxFit.cover),
                                      ))
                                  .toList(),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('Remove', style: TextStyle(color: Colors.red)),
                            onPressed: () => _billsRef.doc(doc.id).delete(),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _activitiesTab() => const SizedBox();
  Widget _transactionsTab() => const SizedBox();
  Widget _feedbackTab() => const SizedBox();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Activities'),
              Tab(text: 'Transactions'),
              Tab(text: 'Bills'),
              Tab(text: 'Feedback'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _activitiesTab(),
                _transactionsTab(),
                _billsTab(),
                _feedbackTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
