// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'otp_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  final Color _bgColor = const Color(0xFFFFFDF5);
  final Color _accentColor = const Color(0xFF5D4037);
  final Color _sandalwood = const Color(0xFFF5E6CA);

  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _aadhar = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _agree = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _name.dispose(); _username.dispose(); _phone.dispose();
    _aadhar.dispose(); _address.dispose(); _state.dispose(); 
    _country.dispose(); _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _proceedToOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please accept Terms & Conditions")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final q = await _firestore.collection('users').where('username', isEqualTo: _username.text.trim()).limit(1).get();
      if (q.docs.isNotEmpty) throw "Username already taken";

      if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text("Create Account", style: GoogleFonts.cinzelDecorative(fontSize: 28, fontWeight: FontWeight.bold, color: _accentColor)),
                const SizedBox(height: 20),
                _input(_name, "Full Name", Icons.person_outline),
                _input(_username, "Username", Icons.alternate_email),
                _input(_phone, "Phone Number", Icons.phone_android, keyboardType: TextInputType.phone),
                _input(_aadhar, "Aadhar Number", Icons.badge_outlined, keyboardType: TextInputType.number),
                _input(_address, "Address", Icons.home_outlined),
                _input(_state, "State", Icons.map_outlined),
                _input(_country, "Country", Icons.public),
                _input(_password, "Password", Icons.lock_outline, obscure: true),
                _input(_confirm, "Confirm Password", Icons.lock_reset, obscure: true),
                Row(
                  children: [
                    Checkbox(value: _agree, activeColor: _accentColor, onChanged: (v) => setState(() => _agree = v!)),
                    const Text("I agree to the Terms & Conditions"),
                  ],
                ),
                const SizedBox(height: 20),
                _isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _proceedToOtp,
                      style: ElevatedButton.styleFrom(backgroundColor: _accentColor, minimumSize: const Size(double.infinity, 50)),
                      child: const Text("CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String lbl, IconData ic, {bool obscure = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: lbl,
          prefixIcon: Icon(ic, color: _accentColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }
}