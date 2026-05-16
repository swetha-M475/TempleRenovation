// lib/screens/project_overview_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  String _activityFilter = 'done';
  bool _loadingAdd = false;

  final ImagePicker _picker = ImagePicker();

  // --------------------------------------------------------------
  // OFFLINE BILL STORAGE
  // --------------------------------------------------------------
  List<Map<String, dynamic>> _localBills = [];

  // --------------------------------------------------------------
  // FEEDBACK SUB-TABS STORAGE (ALL OFFLINE)
  // --------------------------------------------------------------
  List<String> _futureWorks = [];
  int _visitorCount = 0;

  List<Map<String, dynamic>> _donations = [];
  // donorName, amount

  // --------------------------------------------------------------
  // FEEDBACK TAB CONTROLLER
  // --------------------------------------------------------------
  late TabController _feedbackTabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _feedbackTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackTabController.dispose();
    super.dispose();
  }

  // ======================================================================
  // UPLOAD BILL DIALOG (OFFLINE)
  // ======================================================================
  Future<void> _showUploadBillDialog() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateSB) {
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
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Bill Name',
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
                    final imgs = await _picker.pickMultiImage();
                    if (imgs != null && imgs.isNotEmpty) {
                      setStateSB(() => selectedImages = imgs);
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
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    amountCtrl.text.trim().isEmpty) return;

                setState(() {
                  _localBills.insert(0, {
                    'title': titleCtrl.text.trim(),
                    'amount': amountCtrl.text.trim(),
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
      }),
    );
  }

  // ======================================================================
  // EDIT BILL
  // ======================================================================
  Future<void> _editBill(int index) async {
    final bill = _localBills[index];

    TextEditingController titleCtrl =
        TextEditingController(text: bill['title']);
    TextEditingController amountCtrl =
        TextEditingController(text: bill['amount']);

    List<XFile> selectedImages = List<XFile>.from(bill['images'] ?? []);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateSB) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF7E8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFB6862C), width: 2),
          ),
          title: Text(
            'Edit Bill',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6A1F1A),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Bill Name',
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
                    filled: true,
                    fillColor: const Color(0xFFFFF2D5),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFFB6862C)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E3D2C),
                  ),
                  onPressed: () async {
                    final imgs = await _picker.pickMultiImage();
                    if (imgs != null && imgs.isNotEmpty) {
                      setStateSB(() => selectedImages = imgs);
                    }
                  },
                  child: Text('Change Images',
                      style: GoogleFonts.poppins(color: Colors.white)),
                ),
                const SizedBox(height: 10),
                selectedImages.isEmpty
                    ? Text('No images',
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: GoogleFonts.poppins(color: Colors.brown)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E3D2C),
              ),
              onPressed: () {
                setState(() {
                  _localBills[index] = {
                    'title': titleCtrl.text.trim(),
                    'amount': amountCtrl.text.trim(),
                    'images': selectedImages,
                    'date': bill['date'],
                  };
                });

                Navigator.pop(context);
              },
              child:
                  Text("Save", style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  // ======================================================================
  // BILLS TAB (UPDATED)
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
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bill['title'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6A1F1A),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Color(0xFF6A1F1A)),
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _editBill(i);
                                } else if (v == 'delete') {
                                  setState(() {
                                    _localBills.removeAt(i);
                                  });
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text("Edit Bill")),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text("Delete Bill")),
                              ],
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("₹${bill['amount']}",
                                style:
                                    GoogleFonts.poppins(color: Colors.brown)),
                            const SizedBox(height: 4),
                            Text(
                              "Date: ${bill['date'].day}/${bill['date'].month}/${bill['date'].year}",
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
                                      .map<Widget>(
                                        (img) => Padding(
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
        ),
      ],
    );
  }

  // ======================================================================
  // FEEDBACK TAB (3 INTERNAL TABS)
  // ======================================================================
  Widget _feedbackTab() {
    return Column(
      children: [
        const SizedBox(height: 10),
        TabBar(
          controller: _feedbackTabController,
          labelColor: const Color(0xFF8E3D2C),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF8E3D2C),
          tabs: [
            Tab(child: Text("Future Works", style: GoogleFonts.poppins())),
            Tab(child: Text("Visitors", style: GoogleFonts.poppins())),
            Tab(child: Text("Donations", style: GoogleFonts.poppins())),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _feedbackTabController,
            children: [
              _futureWorksTab(),
              _visitorCountTab(),
              _donationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ======================================================================
  // FUTURE WORKS TAB
  // ======================================================================
  Widget _futureWorksTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showAddFutureWorkDialog,
              child: Text(
                "Add Future Work",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
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
        const SizedBox(height: 10),
        Expanded(
          child: _futureWorks.isEmpty
              ? Center(
                  child: Text("No future works",
                      style: GoogleFonts.poppins(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _futureWorks.length,
                  itemBuilder: (context, i) {
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                            color: Color(0xFFB6862C), width: 1),
                      ),
                      child: ListTile(
                        title: Text(_futureWorks[i],
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF6A1F1A),
                                fontWeight: FontWeight.w600)),
                        trailing: PopupMenuButton(
                          icon: const Icon(Icons.more_vert,
                              color: Color(0xFF6A1F1A)),
                          onSelected: (v) {
                            if (v == 'edit') {
                              _editFutureWork(i);
                            } else if (v == 'delete') {
                              setState(() {
                                _futureWorks.removeAt(i);
                              });
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text("Edit")),
                            PopupMenuItem(
                                value: 'delete', child: Text("Delete")),
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

  // Add future work
  Future<void> _showAddFutureWorkDialog() async {
    TextEditingController ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7E8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFB6862C), width: 2),
        ),
        title: Text("Add Future Work",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Color(0xFF6A1F1A))),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: "Work Title",
            labelStyle: GoogleFonts.poppins(color: Colors.brown),
            filled: true,
            fillColor: const Color(0xFFFFF2D5),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFB6862C)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text("Cancel", style: GoogleFonts.poppins(color: Colors.brown)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              setState(() {
                _futureWorks.add(ctrl.text.trim());
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E3D2C),
            ),
            child: Text("Add", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Edit future work
  Future<void> _editFutureWork(int index) async {
    TextEditingController ctrl =
        TextEditingController(text: _futureWorks[index]);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7E8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFB6862C), width: 2),
        ),
        title: Text("Edit",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Color(0xFF6A1F1A))),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: "Work Title",
            filled: true,
            fillColor: const Color(0xFFFFF2D5),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFB6862C)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text("Cancel", style: GoogleFonts.poppins(color: Colors.brown)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              setState(() => _futureWorks[index] = ctrl.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E3D2C),
            ),
            child:
                Text("Save", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  // VISITOR COUNT TAB
  // ======================================================================
  Widget _visitorCountTab() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          "Total Visitors",
          style: GoogleFonts.poppins(
              color: const Color(0xFF6A1F1A),
              fontSize: 20,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          "$_visitorCount",
          style: GoogleFonts.poppins(
              color: Colors.brown, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _editVisitorCount,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8E3D2C),
          ),
          child: Text("Edit Count",
              style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _editVisitorCount() async {
    TextEditingController ctrl =
        TextEditingController(text: _visitorCount.toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7E8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFB6862C), width: 2),
        ),
        title: Text("Edit Visitors",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Color(0xFF6A1F1A))),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Visitor Count",
            filled: true,
            fillColor: const Color(0xFFFFF2D5),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFB6862C)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: GoogleFonts.poppins(color: Colors.brown))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _visitorCount = int.tryParse(ctrl.text.trim()) ?? 0;
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E3D2C),
            ),
            child:
                Text("Save", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  // DONATIONS TAB
  // ======================================================================
  Widget _donationsTab() {
    double total = 0;
    for (var d in _donations) {
      total += double.tryParse(d['amount']) ?? 0;
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          "Total Donations: ₹$total",
          style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6A1F1A)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showAddDonationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E3D2C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text("Add Donation",
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _donations.isEmpty
              ? Center(
                  child: Text("No donations yet",
                      style: GoogleFonts.poppins(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _donations.length,
                  itemBuilder: (context, i) {
                    final d = _donations[i];

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                            color: Color(0xFFB6862C), width: 1),
                      ),
                      child: ListTile(
                        title: Text(
                          d['name'],
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6A1F1A)),
                        ),
                        subtitle: Text(
                          "₹${d['amount']}",
                          style: GoogleFonts.poppins(color: Colors.brown),
                        ),
                        trailing: PopupMenuButton(
                          icon: const Icon(Icons.more_vert,
                              color: Color(0xFF6A1F1A)),
                          onSelected: (v) {
                            if (v == 'edit') {
                              _editDonation(i);
                            } else if (v == 'delete') {
                              setState(() => _donations.removeAt(i));
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text("Edit")),
                            PopupMenuItem(
                                value: 'delete', child: Text("Delete")),
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

  Future<void> _showAddDonationDialog() async {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController amountCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7E8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFB6862C), width: 2),
        ),
        title: Text("Add Donation",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Color(0xFF6A1F1A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Donor Name",
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
                labelText: "Amount",
                filled: true,
                fillColor: const Color(0xFFFFF2D5),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFB6862C)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: GoogleFonts.poppins(color: Colors.brown))),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty ||
                  amountCtrl.text.trim().isEmpty) return;

              setState(() {
                _donations.add({
                  'name': nameCtrl.text.trim(),
                  'amount': amountCtrl.text.trim(),
                });
              });

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E3D2C),
            ),
            child: Text("Add", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _editDonation(int index) async {
    final d = _donations[index];

    TextEditingController nameCtrl = TextEditingController(text: d['name']);
    TextEditingController amountCtrl = TextEditingController(text: d['amount']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFF7E8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFB6862C), width: 2),
        ),
        title: Text("Edit Donation",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Color(0xFF6A1F1A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: "Donor Name",
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
                labelText: "Amount",
                filled: true,
                fillColor: const Color(0xFFFFF2D5),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFB6862C)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: GoogleFonts.poppins(color: Colors.brown))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _donations[index] = {
                  'name': nameCtrl.text.trim(),
                  'amount': amountCtrl.text.trim(),
                };
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E3D2C),
            ),
            child:
                Text("Save", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  // NOTHING BELOW IS MODIFIED (Activities, Transactions, UI Layout)
  // ======================================================================

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

  // MAIN TAB BAR
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
  bool shouldRebuild(covariant _TabBarDelegate old) => old._tabBar != _tabBar;
}
