// lib/screens/project_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Added imports
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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
  String _activityFilter = 'done';
  bool _loadingAdd = false;

  // Added state for image picker
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // *********************************************************************
  // BILL UPLOAD DIALOG   (NEWLY ADDED)
  // *********************************************************************
  Future<void> _showUploadBillDialog() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    _selectedImages = [];

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
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6A1F1A),
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Bill Title',
                        labelStyle: GoogleFonts.poppins(color: Colors.brown),
                        filled: true,
                        fillColor: const Color(0xFFFFF2D5),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFB6862C)),
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          borderSide: const BorderSide(color: Color(0xFFB6862C)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E3D2C),
                      ),
                      onPressed: () async {
                        final picked = await _picker.pickMultiImage();
                        if (picked != null && picked.isNotEmpty) {
                          setStateSB(() {
                            _selectedImages = picked;
                          });
                        }
                      },
                      child: Text(
                        'Select Receipt Images',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _selectedImages.isEmpty
                        ? Text(
                            'No images selected',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          )
                        : Wrap(
                            spacing: 8,
                            children: _selectedImages
                                .map((img) => ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(img.path),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
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
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.brown),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E3D2C)),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim());

                if (title.isEmpty || amount == null) return;

                Navigator.pop(context);
                await _saveBillToFirestore(title, amount);
              },
              child: Text(
                'Upload',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // *********************************************************************
  // FIRESTORE + STORAGE UPLOAD LOGIC  (NEW)
  // *********************************************************************
  Future<void> _saveBillToFirestore(String title, double amount) async {
    try {
      List<String> uploadedUrls = [];

      // Upload each image to Firebase Storage
      for (var img in _selectedImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('bills/${widget.project['id']}/${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await ref.putFile(File(img.path));
        final url = await uploadTask.ref.getDownloadURL();
        uploadedUrls.add(url);
      }

      // Save bill document
      await _firestore.collection('bills').add({
        'projectId': widget.project['id'],
        'title': title,
        'amount': amount,
        'imageUrls': uploadedUrls,
        'date': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving bill: $e');
    }
  }

  // *********************************************************************
  // EXISTING ACTIVITY + TRANSACTION + BILL + FEEDBACK CODE
  // NOTHING EDITED HERE
  // *********************************************************************

  Future<void> _showAddActivityDialog() async {
    final _titleController = TextEditingController();
    String status = 'todo';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7E8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFB6862C), width: 2),
        ),
        title: Text(
          'Add Work',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6A1F1A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Work title',
                labelStyle: GoogleFonts.poppins(color: Colors.brown),
                filled: true,
                fillColor: const Color(0xFFFFF2D5),
                focusedBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: Color(0xFF8E3D2C), width: 2),
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: Color(0xFFB6862C), width: 1),
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    value: 'todo',
                    groupValue: status,
                    title: const Text('To be done'),
                    activeColor: Color(0xFF8E3D2C),
                    onChanged: (v) => status = v!,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    value: 'ongoing',
                    groupValue: status,
                    title: const Text('Ongoing'),
                    activeColor: Color(0xFF8E3D2C),
                    onChanged: (v) => status = v!,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.brown),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E3D2C),
            ),
            onPressed: () async {
              final title = _titleController.text.trim();
              if (title.isEmpty) return;

              Navigator.pop(context);
              setState(() => _loadingAdd = true);

              try {
                await _firestore.collection('activities').add({
                  'projectId': widget.project['id'],
                  'title': title,
                  'status': status,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              } finally {
                if (mounted) setState(() => _loadingAdd = false);
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _activitiesStream(
      String statusFilter) {
    final base = _firestore
        .collection('activities')
        .where('projectId', isEqualTo: widget.project['id']);

    if (statusFilter == 'all') {
      return base.orderBy('createdAt', descending: true).snapshots();
    }

    return base
        .where('status', isEqualTo: statusFilter)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _activitiesTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showAddActivityDialog,
              child: Text(
                '+ Add Work',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E3D2C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0D0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Color(0xFFB6862C), width: 1.5),
            ),
            child: Row(
              children: [
                _segmentedButton('To Be Done', 'todo'),
                _segmentedButton('Ongoing', 'ongoing'),
                _segmentedButton('Completed', 'done'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            color: const Color(0xFFFFF7E8),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _activitiesStream(_activityFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _activityFilter == 'todo'
                          ? 'No activities to be done'
                          : _activityFilter == 'ongoing'
                              ? 'No ongoing activities'
                              : 'No completed activities',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final title = data['title'] ?? '';
                    final status = data['status'] ?? '';
                    final id = docs[i].id;

                    return Card(
                      elevation: 2,
                      color: const Color(0xFFFFFDF5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                            color: Color(0xFFB6862C), width: 1),
                      ),
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: ListTile(
                        title: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6A1F1A),
                          ),
                        ),
                        subtitle: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.poppins(color: Colors.brown),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: Color(0xFF6A1F1A)),
                          onSelected: (v) async {
                            if (v == 'delete') {
                              await _firestore
                                  .collection('activities')
                                  .doc(id)
                                  .delete();
                            } else {
                              await _firestore
                                  .collection('activities')
                                  .doc(id)
                                  .update({'status': v});
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'todo', child: Text('Mark To Be Done')),
                            PopupMenuItem(
                                value: 'ongoing', child: Text('Mark Ongoing')),
                            PopupMenuItem(
                                value: 'done', child: Text('Mark Completed')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _segmentedButton(String label, String value) {
    final active = _activityFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activityFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF8E3D2C) : const Color(0xFFFFF7E8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: active ? Colors.white : Colors.brown,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _transactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('transactions')
          .where('projectId', isEqualTo: widget.project['id'])
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text('No transactions',
                style: GoogleFonts.poppins(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFB6862C), width: 1),
              ),
              child: ListTile(
                title: Text(
                  d['title'] ?? 'Txn',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6A1F1A)),
                ),
                subtitle: Text(
                  d['amount'] != null ? '₹${d['amount']}' : '',
                  style: GoogleFonts.poppins(color: Colors.brown),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _billsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('bills')
          .where('projectId', isEqualTo: widget.project['id'])
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final docs = snap.data?.docs ?? [];

        return Column(
          children: [
            const SizedBox(height: 16),

            // UPLOAD BILL BUTTON ADDED (but UI remains same style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload, color: Colors.white),
                  label: Text(
                    "Upload Bill",
                    style: GoogleFonts.poppins(
                        fontSize: 16, color: Colors.white),
                  ),
                  onPressed: _showUploadBillDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E3D2C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            docs.isEmpty
                ? Expanded(
                    child: Center(
                      child: Text('No bills yet',
                          style: GoogleFonts.poppins(color: Colors.grey)),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i].data();
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                                color: Color(0xFFB6862C), width: 1),
                          ),
                          child: ListTile(
                            title: Text(
                              d['title'] ?? 'Bill',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6A1F1A)),
                            ),
                            subtitle: Text(
                              d['amount'] != null
                                  ? "₹${d['amount']}"
                                  : "",
                              style:
                                  GoogleFonts.poppins(color: Colors.brown),
                            ),
                          ),
                        );
                      },
                    ),
                  )
          ],
        );
      },
    );
  }

  Widget _feedbackTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('feedback')
          .where('projectId', isEqualTo: widget.project['id'])
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text('No feedback yet',
                style: GoogleFonts.poppins(color: Colors.grey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d = docs[i].data();
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFB6862C), width: 1),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(
                  d['author'] ?? 'User',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6A1F1A)),
                ),
                subtitle: Text(
                  d['message'] ?? '',
                  style: GoogleFonts.poppins(color: Colors.brown),
                ),
              ),
            );
          },
        );
      },
    );
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
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Project Overview',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            projectName,
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildTabBar(),
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            Expanded(child: _activitiesTab()),
                          ],
                        ),
                      );
                    },
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            Expanded(child: _transactionsTab()),
                          ],
                        ),
                      );
                    },
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            Expanded(child: _billsTab()),
                          ],
                        ),
                      );
                    },
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            Expanded(child: _feedbackTab()),
                          ],
                        ),
                      );
                    },
                  ),
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
      child: Material(
        color: Colors.white,
        child: _tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return oldDelegate._tabBar != _tabBar;
  }
}
