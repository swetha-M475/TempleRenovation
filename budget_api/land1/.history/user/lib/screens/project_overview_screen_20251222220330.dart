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
  final ImagePicker _picker = ImagePicker();

  late TabController _tabController;
  bool _loadingAdd = false;

  String get _projectId => widget.project['id'];
  String get _userId => widget.project['userId'];

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  // ---------------- BILL UPLOAD ----------------
  Future<void> _showUploadBillDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E8),
          title: Text('Upload Bill',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6A1F1A))),
          content: StatefulBuilder(
            builder: (context, setSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Bill Name'),
                  ),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final imgs = await _picker.pickMultiImage();
                      if (imgs != null) {
                        setSB(() => selectedImages = imgs);
                      }
                    },
                    child: const Text('Select Images'),
                  ),
                  const SizedBox(height: 6),
                  Text('${selectedImages.length} images selected'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                final List<String> urls = [];
                for (final img in selectedImages) {
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

  // ---------------- BILLS TAB ----------------
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
              label: const Text("Upload Bill"),
              onPressed: _showUploadBillDialog,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _billsRef
                .where('userId', isEqualTo: _userId)
                .where('projectId', isEqualTo: _projectId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text('No bills yet'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final bill = docs[i];
                  final data = bill.data();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(data['title']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("₹${data['amount']}"),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 80,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: (data['imageUrls'] as List)
                                  .map<Widget>(
                                    (url) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Image.network(
                                        url,
                                        width: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await bill.reference.delete();
                        },
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

  // ---------------- PLACEHOLDERS (unchanged) ----------------
  Widget _activitiesTab() => const Center(child: Text('Activities'));
  Widget _transactionsTab() => const Center(child: Text('Transactions'));
  Widget _feedbackTab() => const Center(child: Text('Feedback'));

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
