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
    _fetchContractorData(); // Requirement 1: Auto-fill on init
  }

  // --- REQUIREMENT 1: FETCH & AUTO-FILL CONTRACTOR DATA ---
  Future<void> _fetchContractorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _contactNameController.text = doc.data()?['name'] ?? '';
            _contactPhoneController.text = doc.data()?['phone'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  // --- REFINED VALIDATION ---
  bool _validateCurrentPage() {
    if (_currentPage == 0) {
      if (_placeController.text.trim().isEmpty) return _showWarning('Place name is required');
      if (_nearbyTownController.text.trim().isEmpty) return _showWarning('Nearby town is required');
      if (_talukController.text.trim().isEmpty) return _showWarning('Taluk is required');
      if (_districtController.text.trim().isEmpty) return _showWarning('District is required');
      if (_mapLocationController.text.trim().isEmpty) return _showWarning('Please capture GPS coordinates');
      if (_selectedDate == null) return _showWarning('Please select a visit date');
      return true;
    } 
    
    if (_currentPage == 1) {
      if (_selectedFeature == null) return _showWarning('Please select a feature type');
      if (_type == null) return _showWarning('Please select condition type');
      if (_type == 'new' && _dimension == null) return _showWarning('Please select a dimension');
      return true;
    } 
    
    if (_currentPage == 2) {
      if (_contactNameController.text.trim().isEmpty) return _showWarning('Contact name is required');
      if (_contactPhoneController.text.trim().length != 10) return _showWarning('Enter 10-digit phone number');
      if (_estimatedAmountController.text.trim().isEmpty) return _showWarning('Enter total cost');
      
      // REQUIREMENT 3: At least 5 images validation
      if (_selectedImages.length < 5) {
        return _showWarning('Please upload at least 5 photos of the site');
      }
      return true;
    }
    return false;
  }

  bool _showWarning(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFB71C1C), behavior: SnackBarBehavior.floating),
    );
    return false;
  }

  // --- GPS & HELPERS ---
  Future<void> _detectAndFillLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _mapLocationController.text = "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      });
    } catch (e) {
      _showWarning("Could not fetch location. Ensure GPS is on.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createProject() async {
    if (!_validateCurrentPage()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final projectId = const Uuid().v4();
      List<String> uploadedImageUrls = [];

      for (final imgPath in _selectedImages) {
        final url = await CloudinaryService.uploadImage(
          imageFile: XFile(imgPath),
          userId: user.uid,
          projectId: projectId,
        );
        if (url != null) uploadedImageUrls.add(url);
      }

      await FirebaseFirestore.instance.collection('projects').doc(projectId).set({
        'projectId': projectId,
        'userId': user.uid,
        'place': _placeController.text.trim(),
        'nearbyTown': _nearbyTownController.text.trim(),
        'taluk': _talukController.text.trim(),
        'district': _districtController.text.trim(),
        'mapLocation': _mapLocationController.text.trim(),
        'visitDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        'feature': _selectedFeature,
        'featureType': _type,
        'featureDimension': _dimension == 'custom' ? _customDimensionController.text.trim() : _dimension,
        'featureAmount': _featureAmountController.text.trim(),
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'estimatedAmount': _estimatedAmountController.text.trim(),
        'imageUrls': uploadedImageUrls,
        'dateCreated': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showWarning('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text('Propose a Plan', style: GoogleFonts.cinzel(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Row(children: [
        _step(0, 'Location'), _line(0),
        _step(1, 'Feature'), _line(1),
        _step(2, 'Details'),
      ]),
    );
  }

  Widget _step(int step, String label) {
    final active = _currentPage >= step;
    return Column(children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: active ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
        child: Text('${step + 1}', style: TextStyle(fontSize: 12, color: active ? Colors.white : const Color(0xFF8D6E63))),
      ),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    ]);
  }

  Widget _line(int step) {
    return Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4), color: _currentPage > step ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA)));
  }

  // --- PAGES ---

  Widget _buildLocationPage() {
    return _buildFormContainer(child: Column(children: [
      _title('Location Info', 'Enter details of the site'),
      const SizedBox(height: 16),
      _textField(_placeController, 'Place', Icons.location_on_outlined),
      const SizedBox(height: 12),
      _textField(_nearbyTownController, 'Nearby Town', Icons.location_city),
      const SizedBox(height: 12),
      _textField(_talukController, 'Taluk', Icons.map_outlined),
      const SizedBox(height: 12),
      _textField(_districtController, 'District', Icons.domain_outlined),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _textField(_mapLocationController, 'Map Location', Icons.pin_drop, readOnly: true)),
        const SizedBox(width: 8),
        Container(decoration: BoxDecoration(color: const Color(0xFF5D4037), borderRadius: BorderRadius.circular(12)),
          child: IconButton(icon: const Icon(Icons.my_location, color: Colors.white), onPressed: _detectAndFillLocation)),
      ]),
      const SizedBox(height: 12),
      InkWell(onTap: () => _selectDate(context), child: _dateField()),
    ]));
  }

  Widget _buildFeaturePage() {
    return _buildFormContainer(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('Select Feature', 'Choose structure type'),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        SizedBox(width: MediaQuery.of(context).size.width * 0.38, child: _featureButton('Lingam', Icons.temple_hindu)),
        SizedBox(width: MediaQuery.of(context).size.width * 0.38, child: _featureButton('Avudai', Icons.architecture)),
        SizedBox(width: MediaQuery.of(context).size.width * 0.38, child: _featureButton('Nandhi', Icons.pets)),
      ]),
      if (_selectedFeature != null) _buildFeatureDetails(),
    ]));
  }

  Widget _buildFeatureDetails() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text('Condition Type', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _buildRadioOption('Old/Existing', 'old')),
        const SizedBox(width: 8),
        Expanded(child: _buildRadioOption('New Structure', 'new')),
      ]),
      if (_type == 'new') ...[
        const SizedBox(height: 20),
        Text('Choose Dimensions', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._predefinedDimensions.map((dim) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildDimensionOption(dim['name'], 'Estimate: Rs ${dim['amount']}', dim['name']))),
        _buildDimensionOption('Other', 'Custom Size', 'custom'),
        if (_dimension == 'custom') ...[
          const SizedBox(height: 12),
          _textField(_customDimensionController, 'Size (e.g. 5 ft)', Icons.straighten),
          const SizedBox(height: 12),
          _textField(_featureAmountController, 'Req. Amount (Rs)', Icons.currency_rupee, keyboard: TextInputType.number),
        ],
      ],
    ]);
  }

  Widget _buildContactPage() {
    return _buildFormContainer(child: Column(children: [
      _title('Contact Details', 'Contractor Information'),
      const SizedBox(height: 16),
      _textField(_contactNameController, 'Contact Name', Icons.person),
      const SizedBox(height: 12),
      _textField(_contactPhoneController, 'Phone Number', Icons.phone, keyboard: TextInputType.phone),
      const SizedBox(height: 12),
      _textField(_estimatedAmountController, 'Total Estimated Cost', Icons.account_balance_wallet, keyboard: TextInputType.number),
      const SizedBox(height: 20),
      // REQUIREMENT 3: Label update
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Site Photos', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
        Text('(At least 5 required)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 12),
      ImagePickerWidget(
        maxImages: 10,
        onImagesSelected: (imgs) => setState(() => _selectedImages = imgs),
      ),
    ]));
  }

  // --- REQUIREMENT 2: NAVIGATION BUTTONS (BACK ON ALL PHASES) ---
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF5E6CA)))),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              if (_currentPage > 0) {
                _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              } else {
                Navigator.pop(context); // Exit screen on first phase
              }
            },
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF5D4037), side: const BorderSide(color: Color(0xFF5D4037)), padding: const EdgeInsets.symmetric(vertical: 15)),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
              if (_validateCurrentPage()) {
                if (_currentPage < 2) {
                  _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                } else {
                  _createProject();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_currentPage < 2 ? 'Continue' : 'Submit Proposal'),
          ),
        ),
      ]),
    );
  }

  // UI Helpers (Form Container, Textfield, Radio, etc.)
  Widget _buildFormContainer({required Widget child}) {
    return SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(20), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF5E6CA).withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF5E6CA))), child: child));
  }

  Widget _textField(TextEditingController c, String label, IconData icon, {TextInputType keyboard = TextInputType.text, bool readOnly = false}) {
    return TextFormField(controller: c, keyboardType: keyboard, readOnly: readOnly, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF5D4037), size: 20), filled: true, fillColor: Colors.white, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF5E6CA))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5D4037)))));
  }

  Widget _featureButton(String title, IconData icon) {
    final sel = _selectedFeature == title.toLowerCase();
    return InkWell(onTap: () => setState(() { _selectedFeature = title.toLowerCase(); _type = null; }), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: sel ? const Color(0xFFF5E6CA) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA), width: 1.5)), child: Column(children: [Icon(icon, color: sel ? const Color(0xFF5D4037) : const Color(0xFF8D6E63)), const SizedBox(height: 4), Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? const Color(0xFF3E2723) : const Color(0xFF8D6E63)))])));
  }

  Widget _buildRadioOption(String title, String value) {
    final sel = _type == value;
    return InkWell(onTap: () => setState(() { _type = value; _dimension = null; }), child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), decoration: BoxDecoration(color: sel ? const Color(0xFFF5E6CA) : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA))), child: Row(children: [Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: const Color(0xFF5D4037)), const SizedBox(width: 6), Expanded(child: Text(title, style: const TextStyle(fontSize: 12)))])));
  }

  Widget _buildDimensionOption(String title, String subtitle, String value) {
    final sel = _dimension == value;
    return InkWell(onTap: () => setState(() { _dimension = value; if (value != 'custom') { final d = _predefinedDimensions.firstWhere((x) => x['name'] == value); _featureAmountController.text = d['amount'].toString(); _estimatedAmountController.text = d['amount'].toString(); } }), child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: sel ? const Color(0xFFF5E6CA) : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA))), child: Row(children: [Icon(sel ? Icons.check_circle : Icons.circle_outlined, size: 20, color: const Color(0xFF5D4037)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey))])])));
  }

  Widget _title(String t, String s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))), Text(s, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF8D6E63)))]);
  }

  Widget _dateField() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF5E6CA))), child: Row(children: [const Icon(Icons.calendar_month, color: Color(0xFF5D4037), size: 20), const SizedBox(width: 12), Text(_selectedDate == null ? 'Visit Date' : DateFormat('dd-MM-yyyy').format(_selectedDate!), style: const TextStyle(fontSize: 14))]));
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => _selectedDate = picked);
  }
}