import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloudinary_service.dart';

class ProjectOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _bills = [];
  bool _loading = false;

  String get _projectId => widget.project['id'];
  String get _userId => widget.project['userId'];

  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _firestore.collection('bills');

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  // ---------------- LOAD BILLS (Firestore) ----------------
  Future<void> _loadBills() async {
    final snap = await _billsRef
        .where('userId', isEqualTo: _userId)
        .where('projectId', isEqualTo: _projectId)
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      _bills = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'title': data['title'],
          'amount': data['amount'],
          'imageUrls': data['imageUrls'] ?? [],
          'date': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    });
  }

  // ---------------- UPLOAD BILL ----------------
  Future<void> _uploadBill() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    List<XFile> images = [];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upload Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Bill Title'),
            ),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final picked = await _picker.pickMultiImage();
                if (picked != null && picked.isNotEmpty) {
                  images = picked;
                }
              },
              child: const Text('Select Images'),
            ),
          ],
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
              setState(() => _loading = true);

              try {
                final List<String> urls = [];

                for (final img in images) {
                  final url = await CloudinaryService.uploadImage(
                    imageFile: File(img.path),
                    userId: _userId,
                    projectId: _projectId,
                    subFolder: 'bills', // 👈 IMPORTANT
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
              } finally {
                setState(() => _loading = false);
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: _uploadBill,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bills.isEmpty
              ? const Center(child: Text('No bills uploaded'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bills.length,
                  itemBuilder: (context, i) {
                    final bill = _bills[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill['title'],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('₹${bill['amount']}'),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 80,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: (bill['imageUrls'] as List)
                                    .map<Widget>(
                                      (url) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
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
                      ),
                    );
                  },
                ),
    );
  }
}
