import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  DateTime? _selectedDob;
  String? _email;
  String? _photoUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      setState(() {
        _nameController.text = data?['name'] ?? '';
        _addressController.text = data?['address'] ?? '';
        _stateController.text = data?['state'] ?? '';
        _countryController.text = data?['country'] ?? '';
        _email = data?['email'] ?? user.email;
        _photoUrl = data?['photoUrl'];

        final dobData = data?['dob'];
        if (dobData != null) {
          if (dobData is Timestamp) {
            _selectedDob = dobData.toDate();
          } else if (dobData is String) {
            _selectedDob = DateTime.tryParse(dobData);
          }
        }

        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Future<void> _pickImage() async {
    try {
      if (!kIsWeb) {
        final permissionStatus = await Permission.photos.request();
        if (permissionStatus.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Permission denied to access gallery')),
          );
          return;
        }
      }

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (picked == null) return;

      setState(() => _saving = true);
      final user = _auth.currentUser;
      if (user == null) return;

      final ref = _storage.ref().child('profile_images/${user.uid}.jpg');

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        final file = File(picked.path);
        if (!await file.exists()) throw Exception("File not found.");
        await ref.putFile(file);
      }

      final url = await ref.getDownloadURL();
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': url,
      });

      setState(() => _photoUrl = url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _selectDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFD4AF37)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _saveProfile() async {
    try {
      setState(() => _saving = true);
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'state': _stateController.text.trim(),
        'country': _countryController.text.trim(),
        if (_selectedDob != null) 'dob': Timestamp.fromDate(_selectedDob!),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.cinzelDecorative(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0404), Color(0xFF8B0000), Color(0xFFD4AF37)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _saving ? null : _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                backgroundImage:
                                    (_photoUrl != null && _photoUrl!.isNotEmpty)
                                        ? NetworkImage(_photoUrl!)
                                        : null,
                                child: (_photoUrl == null || _photoUrl!.isEmpty)
                                    ? const Icon(Icons.person,
                                        size: 60, color: Color(0xFFD4AF37))
                                    : null,
                              ),
                              Positioned(
                                bottom: 5,
                                right: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD4AF37),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit,
                                      size: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _email ?? '',
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                            _nameController, 'Full Name', Icons.person),
                        const SizedBox(height: 16),
                        _dobField(),
                        const SizedBox(height: 16),
                        _buildTextField(_addressController,
                            'Residential Address', Icons.home),
                        const SizedBox(height: 16),
                        _buildTextField(_stateController, 'State', Icons.map),
                        const SizedBox(height: 16),
                        _buildTextField(
                            _countryController, 'Country', Icons.public),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: 180,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              shadowColor: Colors.black.withOpacity(0.3),
                              elevation: 6,
                            ),
                            child: _saving
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(
                                    'Save',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dobField() {
    return InkWell(
      onTap: _selectDob,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          prefixIcon:
              const Icon(Icons.calendar_today, color: Color(0xFFD4AF37)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4AF37)),
          ),
        ),
        child: Text(
          _selectedDob == null
              ? 'Select DOB'
              : '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        labelStyle: GoogleFonts.poppins(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}
