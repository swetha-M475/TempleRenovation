// lib/screens/project_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Add Work Dialog
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

  // Stream for activities
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

  // Activities Tab
  Widget _activitiesTab() {
    return Column(
      children: [
        const SizedBox(height: 16),

        // ⭐ ONLY ONE BUTTON → "+ Add Work"
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

        // Segmented Filter
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

        // Activity List
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

  // Segmented Button Widget
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

  // Transactions Tab
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

  // Bills Tab
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

        if (docs.isEmpty) {
          return Center(
            child: Text('No bills',
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
                  d['title'] ?? 'Bill',
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

  // Feedback Tab
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

  // Sliver delegate to pin the TabBar
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

  // Main Build
  @override
  Widget build(BuildContext context) {
    final projectName = widget.project['place'] ?? 'Project';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Header block (gradient)
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

            // Pinned TabBar
            _buildTabBar(),

            // TabBarView as SliverFillRemaining so it gets remaining space and is scrollable
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Activities wrapped in a Safe layout (already scrollable inside)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          children: [
                            // Activities content
                            Expanded(child: _activitiesTab()),
                          ],
                        ),
                      );
                    },
                  ),

                  // Transactions
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

                  // Bills
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

                  // Feedback
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

// TabBar delegate used to pin TabBar in CustomScrollView
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
