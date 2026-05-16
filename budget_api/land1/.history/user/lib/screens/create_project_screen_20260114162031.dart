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
    _fetchContractorData();
  }

  Future<void> _fetchContractorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          setState(() {
            _contactNameController.text = data['name']?.toString() ?? '';
            _contactPhoneController.text = data['phone']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

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
      if (_contactPhoneController.text.trim().isEmpty) return _showWarning('Phone number is required');
      if (_estimatedAmountController.text.trim().isEmpty) return _showWarning('Enter total cost');
      if (_selectedImages.length < 5) return _showWarning('Please upload at least 5 photos of the site');
      return true;
    }
    return false;
  }

  bool _showWarning(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  Future<void> _detectAndFillLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _mapLocationController.text =
            "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
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
        'visitDate': Timestamp.fromDate(_selectedDate!),
        'feature': _selectedFeature,
        'featureType': _type,
        'featureDimension': _dimension == 'custom'
            ? _customDimensionController.text.trim()
            : _dimension,
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

  Widget _plainTextField(
    TextEditingController c,
    String label, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        readOnly: readOnly,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF5E6CA).withOpacity(0.4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildContactPage() {
    return _buildFormContainer(
      child: Column(
        children: [
          _title('Contact Details', 'Contractor Information'),
          const SizedBox(height: 16),

          _plainTextField(
            _contactNameController,
            'Contact Name',
            readOnly: true,
            enabled: false,
          ),

          _plainTextField(
            _contactPhoneController,
            'Phone Number',
            keyboard: TextInputType.phone,
            readOnly: true,
            enabled: false,
          ),

          _plainTextField(
            _estimatedAmountController,
            'Total Estimated Cost',
            keyboard: TextInputType.number,
          ),

          const SizedBox(height: 20),
          ImagePickerWidget(
            maxImages: 10,
            onImagesSelected: (imgs) => setState(() => _selectedImages = imgs),
          ),
        ],
      ),
    );
  }

  // REMAINING UI CODE IS UNCHANGED
}
