import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Ensure this matches your project structure
import 'splash_screen.dart'; 

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

  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepDeepRed = Color(0xFF4A0404);
  static const Color sandalwood = Color(0xFFF5E6CA);
  static const Color ivory = Color(0xFFFFFDF5);

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

      if (mounted) {
        setState(() {
          _nameController.text = data?['name'] ?? '';
          _addressController.text = data?['address'] ?? '';
          _stateController.text = data?['state'] ?? '';
          _countryController.text = data?['country'] ?? '';
          _email = data?['email'] ?? user.email;
          _photoUrl = data?['photoUrl'];

          final dobData = data?['dob'];
          if (dobData != null) {
            _selectedDob = (dobData is Timestamp) ? dobData.toDate() : DateTime.tryParse(dobData.toString());
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // LOGOUT FUNCTION
  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error logging out')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      if (!kIsWeb && await Permission.photos.request().isDenied) return;

      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (picked == null) return;

      setState(() => _saving = true);
      final user = _auth.currentUser!;
      final ref = _storage.ref().child('profile_images/${user.uid}.jpg');

      if (kIsWeb) {
        await ref.putData(await picked.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(picked.path));
      }

      final url = await ref.getDownloadURL();
      await _firestore.collection('users').doc(user.uid).update({'photoUrl': url});

      setState(() => _photoUrl = url);
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: deepDeepRed, body: Center(child: CircularProgressIndicator(color: primaryGold)));
    }

    return Scaffold(
      backgroundColor: ivory,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            backgroundColor: deepDeepRed,
            elevation: 0,
            automaticallyImplyLeading: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: primaryGold),
              onPressed: () => Navigator.of(context).pop(),
            ),
            // ADDED LOGOUT BUTTON HERE
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: primaryGold),
                onPressed: _handleLogout,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [deepDeepRed, Color(0xFF8B0000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(child: _buildAvatar()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
              child: Column(
                children: [
                  _buildSectionTitle("Personal Information"),
                  const SizedBox(height: 15),
                  _buildTextField(_nameController, 'Full Name', Icons.person_outline),
                  const SizedBox(height: 15),
                  _buildDobField(),
                  const SizedBox(height: 25),
                  _buildSectionTitle("Address Details"),
                  const SizedBox(height: 15),
                  _buildTextField(_addressController, 'Residential Address', Icons.home_outlined),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_stateController, 'State', Icons.map_outlined)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildTextField(_countryController, 'Country', Icons.public_outlined)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildSaveButton(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _saving ? null : _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: primaryGold, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 55,
              backgroundColor: sandalwood,
              backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty) ? NetworkImage(_photoUrl!) : null,
              child: (_photoUrl == null || _photoUrl!.isEmpty) ? const Icon(Icons.person, size: 55, color: deepDeepRed) : null,
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: primaryGold,
            child: _saving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown.withOpacity(0.8), letterSpacing: 1.1),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: deepDeepRed),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.brown.withOpacity(0.6), fontSize: 14),
        prefixIcon: Icon(icon, color: primaryGold, size: 22),
        filled: true,
        fillColor: sandalwood.withOpacity(0.2),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGold.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryGold, width: 2)),
      ),
    );
  }

  Widget _buildDobField() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDob ?? DateTime(2000),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: deepDeepRed)), child: child!),
        );
        if (picked != null) setState(() => _selectedDob = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: sandalwood.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryGold.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: primaryGold, size: 22),
            const SizedBox(width: 12),
            Text(
              _selectedDob == null ? 'Date of Birth' : '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}',
              style: GoogleFonts.poppins(color: _selectedDob == null ? Colors.brown.withOpacity(0.6) : deepDeepRed, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _saving ? null : () async {
          setState(() => _saving = true);
          await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
            'name': _nameController.text.trim(),
            'address': _addressController.text.trim(),
            'state': _stateController.text.trim(),
            'country': _countryController.text.trim(),
            if (_selectedDob != null) 'dob': Timestamp.fromDate(_selectedDob!),
          });
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Saved')));
        },
        style: ElevatedButton.styleFrom(backgroundColor: deepDeepRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _saving ? const CircularProgressIndicator(color: primaryGold) : Text("SAVE UPDATES", style: GoogleFonts.cinzel(color: primaryGold, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}