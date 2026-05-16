import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProjectOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final ImagePicker _picker = ImagePicker();

  // Local offline bills storage
  List<Map<String, dynamic>> _localBills = [];

  // For activities section only UI purpose
  String _activityFilter = 'done';

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

  // ======================================================================
  // UPLOAD BILL DIALOG (OFFLINE VERSION)
  // ======================================================================

  Future<void> _showUploadBillDialog() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];

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
                        labelText: 'Bill Name',
                        labelStyle: GoogleFonts.poppins(color: Colors.brown),
                        filled: true,
                        fillColor: const Color(0xFFFFF2D5),
                        enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Color(0xFFB6862C)),
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
                          borderSide:
                              const BorderSide(color: Color(0xFFB6862C)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E3D2C),
                      ),
                      onPressed: () async {
                        final imgs = await _picker.pickMultiImage();
                        if (imgs != null && imgs.isNotEmpty) {
                          setStateSB(() {
                            selectedImages = imgs;
                          });
                        }
                      },
                      child: Text(
                        'Select Images',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
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
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: Colors.brown)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E3D2C)),
              onPressed: () {
                final title = titleCtrl.text.trim();
                final amount = amountCtrl.text.trim();

                if (title.isEmpty || amount.isEmpty) return;

                // Add to local list
                setState(() {
                  _localBills.insert(0, {
                    'title': title,
                    'amount': amount,
                    'images': selectedImages,
                    'date': DateTime.now(),
                  });
                });

                Navigator.pop(context);
              },
              child: Text('Upload',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ======================================================================
  // BILLS TAB (FULLY OFFLINE)
  // ======================================================================

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
              label: Text(
                "Upload Bill",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
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
        Expanded(
          child: _localBills.isEmpty
              ? Center(
                  child: Text('No bills yet',
                      style: GoogleFonts.poppins(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _localBills.length,
                  itemBuilder: (context, i) {
                    final bill = _localBills[i];

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                            color: Color(0xFFB6862C), width: 1),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        title: Text(
                          bill['title'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6A1F1A),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "₹${bill['amount']}",
                              style: GoogleFonts.poppins(color: Colors.brown),
                            ),
                            const SizedBox(height: 8),
                            if (bill['images'] != null &&
                                bill['images'].isNotEmpty)
                              SizedBox(
                                height: 80,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: bill['images']
                                      .map<Widget>((img) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.file(
                                                File(img.path),
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                              ),
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

  // ======================================================================
  // STUB TABS FOR UI (EMPTY BUT KEEPS WORKING)
  // ======================================================================

  Widget _activitiesTab() {
    return Center(
        child: Text("Activities (offline mode)",
            style: GoogleFonts.poppins(color: Colors.grey)));
  }

  Widget _transactionsTab() {
    return Center(
        child: Text("Transactions (offline mode)",
            style: GoogleFonts.poppins(color: Colors.grey)));
  }

  Widget _feedbackTab() {
    return Center(
        child: Text("Feedback (offline mode)",
            style: GoogleFonts.poppins(color: Colors.grey)));
  }

  // ======================================================================
  // TAB BAR
  // ======================================================================

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

  // ======================================================================
  // BUILD
  // ======================================================================

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Overview',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          projectName,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
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
                  _activitiesTab(),
                  _transactionsTab(),
                  _billsTab(),
                  _feedbackTab(),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: Colors.white,
      child: Material(color: Colors.white, child: _tabBar),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) {
    return old._tabBar != _tabBar;
  }
}
