import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../utils/colors.dart';
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

  List<String> _selectedImages = [];
  bool _isLoading = false;

  static const String _cloudName = 'dvjuryrnz';
  static const String _uploadPreset = 'aranpani_unsigned_upload';

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

  Future<String> _uploadToCloudinary(
      File image, String userId, String projectId) async {
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = 'aranpani/$userId/$projectId'
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final response = await request.send();
    final resStr = await response.stream.bytesToString();
    final data = json.decode(resStr);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Image upload failed');
    }

    return data['secure_url'];
  }

  Future<void> _createProject() async {
    if (!_validateCurrentPage()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final projectId = const Uuid().v4();

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
        'status': 'pending',
        'progress': 0,
        'removedByUser': false,
      });

      List<String> imageUrls = [];
      for (final path in _selectedImages) {
        final url = await _uploadToCloudinary(File(path), user.uid, projectId);
        imageUrls.add(url);
      }

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'images': imageUrls});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan proposed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_currentPage < 2) {
                    _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut);
                  } else {
                    _createProject();
                  }
                },
          child: _isLoading
              ? const CircularProgressIndicator()
              : Text(_currentPage < 2 ? 'Next' : 'Submit'),
        ),
      ),
    );
  }

  Widget _buildLocationPage() {
    return Center(child: Text('Location Page'));
  }

  Widget _buildFeaturePage() {
    return Center(child: Text('Feature Page'));
  }

  Widget _buildContactPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ImagePickerWidget(
            maxImages: 5,
            onImagesSelected: (imgs) => _selectedImages = imgs,
          ),
        ],
      ),
    );
  }
}
