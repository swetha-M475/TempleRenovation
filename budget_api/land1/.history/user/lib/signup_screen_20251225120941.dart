// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import 'welcome_screen.dart'; 

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Controllers
  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _aadhar = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  // OTP Logic
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _otpVisible = false;
  bool _otpVerified = false;
  bool _otpSending = false;
  bool _resendAvailable = false;
  String _sessionId = "";
  Timer? _timer;
  int _secondsLeft = 30;

  bool _agree = false;
  bool _isLoading = false;

  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    _name.dispose(); _username.dispose(); _phone.dispose(); _email.dispose();
    _aadhar.dispose(); _address.dispose(); _state.dispose(); _country.dispose();
    _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  // ... (Keep the _startTimer, _sendOTP, _verifyOtp, _usernameAvailable methods from the previous code) ...
  // They are identical in logic, focusing on functionality.

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please verify your phone number first")));
      return;
    }
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please accept the Terms & Conditions")));
      return;
    }
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uname = _username.text.trim();
      final q = await _firestore.collection('users').where('username', isEqualTo: uname).limit(1).get();
      if (q.docs.isNotEmpty) throw "Username is already taken";

      final userCred = await _auth.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _password.text.trim());
      
      final user = userCred.user!;

      await _firestore.collection("users").doc(user.uid).set({
        "name": _name.text.trim(),
        "username": uname,
        "phoneNumber": _phone.text.trim(),
        "email": _email.text.trim(),
        "aadharNumber": _aadhar.text.trim(),
        "address": _address.text.trim(),
        "state": _state.text.trim(),
        "country": _country.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
        "emailVerified": true, // Skipping verification
        "phoneVerified": true
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Signup failed: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A0404), // Deep Maroon
              Color(0xFF7A1E1E), // Red-Brown
              Color(0xFFF5DEB3)  // Wheat
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildLogo(),
                const SizedBox(height: 16),
                Text(
                  "Aranpani",
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD4AF37), // Gold
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                        _input(_email, "Email Address", Icons.email_outlined, keyboardType: TextInputType.emailAddress),
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
                        _signupButton(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildLogo() {
    return Container(
      width: 100, height: 100,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8860B)]),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: const Center(child: Icon(Icons.temple_hindu_rounded, size: 55, color: Colors.white)),
    );
  }

  Widget _phoneSection() {
    return Column(
      children: [
        if (!_otpVerified)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 10,
                  decoration: _fieldDecoration("Phone Number", Icons.phone_outlined),
                  onChanged: (v) => setState(() {}),
                  validator: (v) => v!.length != 10 ? "Enter 10-digit number" : null,
                ),
              ),
              if (_phone.text.length == 10 && !_otpVisible)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ElevatedButton(
                    onPressed: _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("OTP", style: TextStyle(color: Colors.white)),
                  ),
                )
            ],
          ),
        if (_otpVisible && !_otpVerified) _otpUI(),
        if (_otpVerified)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.5))),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Text("Phone Verified", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
      ],
    );
  }

  // Shared Decoration for all fields
  InputDecoration _fieldDecoration(String lbl, IconData ic) {
    return InputDecoration(
      counterText: "",
      labelText: lbl,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      prefixIcon: Icon(ic, color: Colors.amber, size: 22),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }

  Widget _input(TextEditingController c, String lbl, IconData ic, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: c, keyboardType: keyboardType, style: const TextStyle(color: Colors.white),
      decoration: _fieldDecoration(lbl, ic),
      validator: (v) => v!.isEmpty ? "Enter $lbl" : null,
    );
  }

  Widget _passwordField(TextEditingController c, String lbl) {
    return TextFormField(
      controller: c, obscureText: true, style: const TextStyle(color: Colors.white),
      decoration: _fieldDecoration(lbl, Icons.lock_outline),
      validator: (v) => v!.isEmpty ? "Enter $lbl" : null,
    );
  }

  Widget _termsCheckbox() {
    return Row(
      children: [
        SizedBox(
          height: 24, width: 24,
          child: Checkbox(
            value: _agree, 
            activeColor: Colors.amber, 
            side: const BorderSide(color: Colors.white70),
            onChanged: (v) => setState(() => _agree = v ?? false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text("I agree to Terms & Conditions", style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
      ],
    );
  }

  Widget _signupButton() {
    return _isLoading
        ? const CircularProgressIndicator(color: Colors.amber)
        : Container(
            width: double.infinity, height: 55,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [Colors.amber.shade600, Colors.deepOrange.shade700]),
              boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: ElevatedButton(
              onPressed: _signup,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              child: const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          );
  }
  
  // Reuse existing OTP UI from previous step...
}