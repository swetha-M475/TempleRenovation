// lib/screens/create_project_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../utils/colors.dart';
import '../widgets/feature_selection_card.dart';
import '../widgets/image_picker_widget.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _nearbyTownController = TextEditingController();
  final TextEditingController _talukController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _mapLocationController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _estimatedAmountController =
      TextEditingController();
  final TextEditingController _customDimensionController =
      TextEditingController();
  final TextEditingController _featureAmountController =
      TextEditingController();

  DateTime? _selectedDate;

  String? _selectedFeature;
  String? _type;
  String? _dimension;

  final List<Map<String, dynamic>> _predefinedDimensions = [
    {'name': '2 feet', 'amount': 50000},
    {'name': '3 feet', 'amount': 75000},
    {'name': '4 feet', 'amount': 100000},
  ];

  List<String> _selectedImages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _placeController.dispose();
    _nearbyTownController.dispose();
    _talukController.dispose();
    _districtController.dispose();
    _mapLocationController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _estimatedAmountController.dispose();
    _customDimensionController.dispose();
    _featureAmountController.dispose();
    super.dispose();
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _placeController.text.isNotEmpty &&
            _nearbyTownController.text.isNotEmpty &&
            _talukController.text.isNotEmpty &&
            _districtController.text.isNotEmpty &&
            _mapLocationController.text.isNotEmpty &&
            _selectedDate != null;
      case 1:
        return _selectedFeature != null;
      case 2:
        return _contactNameController.text.isNotEmpty &&
            _contactPhoneController.text.isNotEmpty &&
            _estimatedAmountController.text.isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: const Color(0xFFD4AF37),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _createProject() async {
    if (!_validateCurrentPage()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please fill all required fields'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uuid = const Uuid();
      final user = FirebaseAuth.instance.currentUser!;
      final String projectId = uuid.v4();

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .set({
        'projectNumber': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': user.uid,
        'place': _placeController.text.trim(),
        'nearbyTown': _nearbyTownController.text.trim(),
        'taluk': _talukController.text.trim(),
        'district': _districtController.text.trim(),
        'mapLocation': _mapLocationController.text.trim(),
        'feature': _selectedFeature ?? '',
        'featureType': _type ?? '',
        'featureDimension': _dimension ?? '',
        'featureAmount': _featureAmountController.text.trim(),
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'estimatedAmount': _estimatedAmountController.text.trim(),
        'dateCreated': FieldValue.serverTimestamp(),
        'progress': 0,

        // NEW FIELD FOR ADMIN FLOW
        'status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Plan proposed successfully!'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0404), Color(0xFFD4AF37), Color(0xFFF5DEB3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildProgressIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildLocationPage(),
                    _buildFeaturePage(),
                    _buildContactPage(),
                  ],
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------
  // UI COMPONENTS (unchanged)
  // -----------------------
  Widget _buildHeader() { ... }

  Widget _buildProgressIndicator() { ... }

  Widget _buildLocationPage() { ... }

  Widget _buildFeaturePage() { ... }

  Widget _buildFeatureDetails(String featureName) { ... }

  Widget _featureButton(String title, IconData icon) { ... }

  Widget _buildContactPage() { ... }

  Widget _buildNavigationButtons() { ... }

  Widget _buildFormContainer({required Widget child}) { ... }

  Widget _textField(TextEditingController c, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text}) { ... }

  Widget _dateField() { ... }

  Widget _buildRadioOption(String title, String value) { ... }

  Widget _buildDimensionOption(String title, String subtitle, String value) { ... }

  Widget _title(String title, String subtitle) { ... }
}
