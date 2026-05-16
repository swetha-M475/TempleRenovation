// lib/screens/create_project_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../utils/colors.dart';
import '../widgets/image_picker_widget.dart';
import '../services/cloudinary_service.dart';
import 'package:geolocator/geolocator.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Controllers
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _nearbyTownController = TextEditingController();
  final TextEditingController _talukController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _mapLocationController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _estimatedAmountController = TextEditingController();
  final TextEditingController _customDimensionController = TextEditingController();
  final TextEditingController _featureAmountController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedFeature;
  String? _type;
  String? _dimension;
  List<String> _selectedImages = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _predefinedDimensions = [
    {'name': '2 feet', 'amount': 50000},
    {'name': '3 feet', 'amount': 75000},
    {'name': '4 feet', 'amount': 100000},
  ];

  @override
  void initState() {
    super.initState();
    _fetchContractorDetails(); // Requirement: Fetch and auto-fill phone
  }

  // --- AUTO-FILL LOGIC ---
  Future<void> _fetchContractorDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetching from 'users' collection using the Auth UID
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _contactNameController.text = doc.data()?['name'] ?? '';
            // Specifically fetching phone number from Firebase
            _contactPhoneController.text = doc.data()?['phone'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching contractor details: $e");
    }
  }

  // --- VALIDATION ---
  bool _validateCurrentPage() {
    if (_currentPage == 0) {
      if (_placeController.text.trim().isEmpty || 
          _nearbyTownController.text.trim().isEmpty ||
          _mapLocationController.text.trim().isEmpty ||
          _selectedDate == null) {
        return _showWarning('Please fill all required location fields');
      }
      return true;
    } 
    
    if (_currentPage == 1) {
      if (_selectedFeature == null || _type == null) return _showWarning('Selection required');
      return true;
    } 
    
    if (_currentPage == 2) {
      if (_contactPhoneController.text.isEmpty) return _showWarning('Phone number is required');
      if (_selectedImages.length < 5) {
        return _showWarning('At least 5 site photos are required');
      }
      return true;
    }
    return false;
  }

  bool _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[800], behavior: SnackBarBehavior.floating),
    );
    return false;
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [_buildLocationPage(), _buildFeaturePage(), _buildContactPage()],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text('PROPOSE A PLAN', style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
      child: Row(
        children: [_step(0, 'Location'), _line(0), _step(1, 'Feature'), _line(1), _step(2, 'Details')],
      ),
    );
  }

  Widget _step(int step, String label) {
    bool active = _currentPage >= step;
    return Column(children: [
      CircleAvatar(radius: 15, backgroundColor: active ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
        child: Text('${step + 1}', style: TextStyle(color: active ? Colors.white : Colors.brown, fontSize: 12))),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10))
    ]);
  }

  Widget _line(int step) => Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 15), color: _currentPage > step ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA)));

  Widget _buildLocationPage() {
    return _pageContainer(child: Column(children: [
      _title('Location Information'),
      const SizedBox(height: 20),
      _plainTextField(_placeController, 'Place Name'),
      _plainTextField(_nearbyTownController, 'Nearby Town'),
      _plainTextField(_talukController, 'Taluk'),
      _plainTextField(_districtController, 'District'),
      Row(children: [
        Expanded(child: _plainTextField(_mapLocationController, 'GPS Coordinates', readOnly: true)),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.location_searching, color: Color(0xFF5D4037)), 
          onPressed: _detectAndFillLocation
        )
      ]),
      _datePickerField(),
    ]));
  }

  Widget _buildFeaturePage() {
    return _pageContainer(child: Column(children: [
      _title('Feature Selection'),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _featureItem('Lingam'),
        _featureItem('Avudai'),
        _featureItem('Nandhi'),
      ]),
      if (_selectedFeature != null) ...[
        const SizedBox(height: 30),
        _radioTile('Old / Existing Structure', 'old'),
        _radioTile('New Structure Construction', 'new'),
      ]
    ]));
  }

  Widget _buildContactPage() {
    return _pageContainer(child: Column(children: [
      _title('Contractor & Site Details'),
      const SizedBox(height: 20),
      _plainTextField(_contactNameController, 'Name'),
      _plainTextField(_contactPhoneController, 'Phone Number', keyboard: TextInputType.phone),
      _plainTextField(_estimatedAmountController, 'Total Estimated Cost (INR)', keyboard: TextInputType.number),
      const SizedBox(height: 25),
      const Align(alignment: Alignment.centerLeft, child: Text('Site Photos (Minimum 5 required)', style: TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(height: 10),
      ImagePickerWidget(
        maxImages: 10,
        onImagesSelected: (imgs) => setState(() => _selectedImages = imgs),
      ),
    ]));
  }

  // --- REQUIREMENT: PLAIN TEXTFIELD (NO ICONS/EMOJIS) ---
  Widget _plainTextField(TextEditingController c, String label, {bool readOnly = false, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: c,
        readOnly: readOnly,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.brown, fontSize: 14),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF5E6CA))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF5E6CA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF5D4037))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }

  // --- REQUIREMENT: BACK BUTTON ON ALL PHASES ---
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF5E6CA)))),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              if (_currentPage > 0) {
                _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              } else {
                Navigator.pop(context); // Close on first page
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5D4037),
              side: const BorderSide(color: Color(0xFF5D4037)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
              if (_validateCurrentPage()) {
                if (_currentPage < 2) {
                  _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                } else {
                  _submitData();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_currentPage < 2 ? 'Continue' : 'Submit Plan'),
          ),
        ),
      ]),
    );
  }

  // Helpers
  Widget _pageContainer({required Widget child}) => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF5E6CA))), child: child));
  
  Widget _title(String t) => Text(t, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF3E2723)));

  Widget _featureItem(String name) {
    bool sel = _selectedFeature == name.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _selectedFeature = name.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: sel ? const Color(0xFF5D4037) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF5D4037))),
        child: Text(name, style: TextStyle(color: sel ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _radioTile(String title, String value) => RadioListTile(
    title: Text(title, style: const TextStyle(fontSize: 14)),
    value: value, 
    groupValue: _type, 
    activeColor: const Color(0xFF5D4037),
    onChanged: (val) => setState(() => _type = val as String)
  );

  Widget _datePickerField() => ListTile(
    title: Text(_selectedDate == null ? 'Select Visit Date' : DateFormat('dd-MM-yyyy').format(_selectedDate!)),
    trailing: const Icon(Icons.calendar_today, size: 20),
    onTap: () async {
      final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
      if (p != null) setState(() => _selectedDate = p);
    }
  );

  Future<void> _detectAndFillLocation() async {
    Position pos = await Geolocator.getCurrentPosition();
    setState(() => _mapLocationController.text = "${pos.latitude}, ${pos.longitude}");
  }

  Future<void> _submitData() async {
    setState(() => _isLoading = true);
    // Add your Cloudinary and Firestore logic here
    await Future.delayed(const Duration(seconds: 2));
    Navigator.pop(context, true);
  }
}