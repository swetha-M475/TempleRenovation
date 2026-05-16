import 'dart:io';
import 'package:flutter/foundation.dart';
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

  String get _projectId => widget.project['id'];
  String get _userId => widget.project['userId'];

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
          builder: (c, sb) => SingleChildScrollView(
            child: Column(
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
                    final picked = await _picker.pickMultiImage();
                    if (picked != null) sb(() => images = picked);
                  },
                  child: const Text('Select Images'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: images
                      .map(
                        (img) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(
                                  img.path,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(img.path),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty ||
                  amountCtrl.text.isEmpty ||
                  images.isEmpty) return;

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
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.data!.docs.isEmpty) {
                return const Center(child: Text('No bills yet'));
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: snap.data!.docs.map((doc) {
                  final d = doc.data();
                  return Card(
                    child: ListTile(
                      title: Text(d['title']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₹${d['amount']}'),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 80,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: (d['imageUrls'] as List)
                                  .map(
                                    (u) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Image.network(
                                        u,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _billsRef.doc(doc.id).delete(),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.red),
                            ),
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
                const SizedBox(),
                const SizedBox(),
                _billsTab(),
                const SizedBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
