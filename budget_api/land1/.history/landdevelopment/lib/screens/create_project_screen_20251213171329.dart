import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final List<Map<String, dynamic>> _predefinedDimensions = [
    {'name': '2 feet', 'amount': 50000},
    {'name': '3 feet', 'amount': 75000},
    {'name': '4 feet', 'amount': 100000},
  ];

  List<String> _selectedImages = [];
  bool _isLoading = false;

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
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _toDMS(double value, bool isLat) {
    final absValue = value.abs();
    final degrees = absValue.floor();
    final minutesFull = (absValue - degrees) * 60;
    final minutes = minutesFull.floor();
    final seconds = (minutesFull - minutes) * 60;
    final direction = isLat ? (value >= 0 ? 'N' : 'S') : (value >= 0 ? 'E' : 'W');
    return '${degrees}°${minutes.toString().padLeft(2, '0')}\'' '${seconds.toStringAsFixed(1)}"$direction';
  }

  Future<void> _detectAndFillLocation() async {
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation);
    setState(() {
      _mapLocationController.text =
          '${_toDMS(pos.latitude, true)} ${_toDMS(pos.longitude, false)}';
    });
  }

  Future<void> _createProject() async {
    if (!_validateCurrentPage()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final projectId = const Uuid().v4();

      await FirebaseFirestore.instance.collection('projects').doc(projectId).set({
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
        'status': 'pending',
        'removedByUser': false,
      });

      // 🔹 CLOUDINARY IMAGE UPLOAD (ONLY ADDITION)
      List<String> imageUrls = [];
      for (final path in _selectedImages) {
        final url = await CloudinaryService.uploadImage(
          imageFile: File(path),
          userId: user.uid,
          projectId: projectId,
        );
        imageUrls.add(url);
      }

      if (imageUrls.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .update({'images': imageUrls});
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan proposed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- UI BELOW (UNCHANGED) ----------

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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'Create Project',
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LinearProgressIndicator(
        value: (_currentPage + 1) / 3,
        minHeight: 8,
        backgroundColor: Colors.grey[300],
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
      ),
    );
  }

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTextField('Place', _placeController),
          _buildTextField('Nearby Town', _nearbyTownController),
          _buildTextField('Taluk', _talukController),
          _buildTextField('District', _districtController),
          _buildTextField('Map Location', _mapLocationController),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _detectAndFillLocation,
            icon: const Icon(Icons.location_on),
            label: const Text('Detect Location'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _selectDate(context),
            child: Text(_selectedDate == null
                ? 'Select Date'
                : DateFormat('dd-MM-yyyy').format(_selectedDate!)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildDropdown(
            'Select Feature',
            ['Feature 1', 'Feature 2', 'Feature 3'],
            (value) => setState(() => _selectedFeature = value),
          ),
          if (_selectedFeature != null) ...[
            const SizedBox(height: 12),
            _buildDropdown(
              'Select Type',
              ['Type A', 'Type B', 'Type C'],
              (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              'Dimension',
              _predefinedDimensions.map((d) => d['name'] as String).toList(),
              (value) => setState(() => _dimension = value),
            ),
            if (_dimension == 'Custom') ...[
              const SizedBox(height: 12),
              _buildTextField('Custom Dimension', _customDimensionController),
            ],
            const SizedBox(height: 12),
            _buildTextField('Feature Amount', _featureAmountController),
          ],
        ],
      ),
    );
  }

  Widget _buildContactPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildTextField('Contact Name', _contactNameController),
          _buildTextField('Contact Phone', _contactPhoneController),
          _buildTextField('Estimated Amount', _estimatedAmountController),
          const SizedBox(height: 16),
          const ImagePickerWidget(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, Function(String?)? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            ElevatedButton(
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              child: const Text('Back'),
            ),
          if (_currentPage < 2)
            ElevatedButton(
              onPressed: _validateCurrentPage()
                  ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      )
                  : null,
              child: const Text('Next'),
            ),
          if (_currentPage == 2)
            ElevatedButton(
              onPressed: _isLoading ? null : _createProject,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Project'),
            ),
        ],
      ),
    );
  }
}
