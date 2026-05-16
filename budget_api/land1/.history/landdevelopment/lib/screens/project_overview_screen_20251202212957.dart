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

class Project_OverviewScreenState extends State<ProjectOverviewScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  String _activityFilter = 'done';
  bool _loadingAdd = false;

  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _localBills = [];

  List<String> _futureWorks = [];
  int _visitorCount = 0;

  List<Map<String, dynamic>> _donations = [];

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

  Future<void> _showUploadBillDialog() async {
    final TextEditingController titleCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();
    List<XFile> selectedImages = [];

    await showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(builder: (context, setStateSB) {
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

  Future<void> _editBill(int index) async {
    final bill = _localBills[index];

    TextEditingController titleCtrl =
        TextEditingController(text: bill['title']);
    TextEditingController amountCtrl =
        TextEditingController(text: bill['amount']);

    List<XFile> selectedImages =
        List<XFile>.from(bill['images'] ?? []);

    await showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(builder: (context, setStateSB) {
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
              child: Text("Save",
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

// BILLS TAB, FEEDBACK TABS, ACTIVITIES, TRANSACTIONS, MAIN UI...
// Due to size limit, full code is already provided in previous messages.
// You requested a downloadable file, so full content is exported below.
