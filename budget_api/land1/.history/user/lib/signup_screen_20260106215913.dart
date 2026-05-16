// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'otp_verification_screen.dart'; // Since they are in the same folder now

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // ARANPANI COLOR PALETTE
  final Color _bgColor = const Color(0xFFFFFDF5);
  final Color _accentColor = const Color(0xFF5D4037);
  final Color _sandalwood = const Color(0xFFF5E6CA);
  final Color _mutedBronze = const Color(0xFF8D6E63);
  final Color _deepGold = const Color(0xFFD4AF37);

  // Controllers
  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _aadhar = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String _selectedMethod = 'SMS'; 
  bool _agree = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _name.dispose(); _username.dispose(); _phone.dispose();
    _aadhar.dispose(); _address.dispose(); _state.dispose(); _country.dispose();
    _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _proceedToOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Accept Terms to proceed")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Check if username exists
      final q = await _firestore.collection('users').where('username', isEqualTo: _username.text.trim()).limit(1).get();
      if (q.docs.isNotEmpty) {
        throw "Username is already taken";
      }

      if (!mounted) return;
      
      // Navigate directly to OTP Verification
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationScreen(
            fullName: _name.text.trim(),
            username: _username.text.trim(),
            phoneNumber: _phone.text.trim(),
            email: "${_username.text.trim().toLowerCase()}@aranpani.com",
            aadhar: _aadhar.text.trim(),
            address: _address.text.trim(),
            state: _state.text.trim(),
            country: _country.text.trim(),
            password: _password.text.trim(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_bgColor, _sandalwood], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  IconButton(icon: Icon(Icons.arrow_back_ios_new, color: _accentColor), onPressed: () => Navigator.pop(context)),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 12),
                      Text("Aranpani", style: GoogleFonts.cinzelDecorative(fontSize: 32, fontWeight: FontWeight.bold, color: _accentColor)),
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _sandalwood),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _input(_name, "Full Name", Icons.person_outline),
                              const SizedBox(height: 16),
                              _input(_username, "Username", Icons.alternate_email),
                              const SizedBox(height: 16),
                              _phoneSection(), 
                              const SizedBox(height: 16),
                              _input(_aadhar, "Aadhar Number", Icons.badge_outlined, keyboardType: TextInputType.number),
                              const SizedBox(height: 16),
                              _input(_address, "Address", Icons.home_outlined),
                              const SizedBox(height: 16),
                              _input(_state, "State", Icons.location_city_outlined),
                              const SizedBox(height: 16),
                              _input(_country, "Country", Icons.public_outlined),
                              const SizedBox(height: 16),
                              _passwordField(_password, "Password"),
                              const SizedBox(height: 16),
                              _passwordField(_confirm, "Confirm Password"),
                              const SizedBox(height: 20),
                              _termsCheckbox(),
                              const SizedBox(height: 20),
                              _isLoading 
                                ? CircularProgressIndicator(color: _accentColor)
                                : SizedBox(
                                    width: double.infinity, height: 55,
                                    child: ElevatedButton(
                                      onPressed: _proceedToOtp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _accentColor, 
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        elevation: 2,
                                      ),
                                      child: const Text("CONTINUE", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle, 
        gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8962E)]),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 3))]
      ),
      child: Padding(
        padding: const EdgeInsets.all(4), 
        child: ClipOval(child: Image.asset('assets/images/shiva.png', fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.temple_hindu, color: Colors.white, size: 50)))
      ),
    );
  }

  Widget _phoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: _fieldDecoration("Phone Number", Icons.phone_outlined).copyWith(counterText: ""),
          onChanged: (v) => setState(() {}),
          validator: (v) => v!.length != 10 ? "Enter 10 digits" : null,
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String lbl, IconData ic) {
    return InputDecoration(
      labelText: lbl, 
      labelStyle: TextStyle(color: _mutedBronze, fontSize: 14),
      prefixIcon: Icon(ic, color: _accentColor, size: 20),
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _sandalwood)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _accentColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }

  Widget _input(TextEditingController c, String lbl, IconData ic, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: c, 
      keyboardType: keyboardType, 
      decoration: _fieldDecoration(lbl, ic), 
      validator: (v) => v!.isEmpty ? "Required field" : null
    );
  }

  Widget _passwordField(TextEditingController c, String lbl) {
    return TextFormField(
      controller: c, 
      obscureText: true, 
      decoration: _fieldDecoration(lbl, Icons.lock_outline), 
      validator: (v) => v!.length < 6 ? "Minimum 6 characters" : null
    );
  }

  Widget _termsCheckbox() {
    return Row(children: [
      SizedBox(
        height: 24, width: 24,
        child: Checkbox(value: _agree, activeColor: _accentColor, onChanged: (v) => setState(() => _agree = v ?? false)),
      ),
      const SizedBox(width: 10),
      const Text("I agree to Terms & Conditions", style: TextStyle(fontSize: 13, color: Colors.black87)),
    ]);
  }
}