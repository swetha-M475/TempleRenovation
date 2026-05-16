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

  // Colors based on Welcome Screen
  final Color bgColor = const Color(0xFFFFFDF5); // Ivory
  final Color accentColor = const Color(0xFF5D4037); // Bronze / Deep Sandalwood
  final Color cardColor = const Color(0xFFEFE6D5); // Light Sandalwood
  final Color textDark = const Color(0xFF3E2723);
  final Color textMuted = const Color(0xFF8D6E63);

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

  // OTP State
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _otpVisible = false;
  bool _otpVerified = false;
  bool _otpSending = false;
  String _sessionId = "";

  bool _agree = false;
  bool _isLoading = false;

  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _name.dispose(); _username.dispose(); _phone.dispose();
    _aadhar.dispose(); _address.dispose(); _state.dispose(); _country.dispose();
    _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  // --- Logic ---

  Future<void> _sendOTP() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) return;
    setState(() => _otpSending = true);
    try {
      final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["Status"] == "Success") {
          setState(() { _otpVisible = true; _sessionId = data["Details"] ?? ""; });
          _otpFocusNodes[0].requestFocus();
        }
      }
    } catch (e) {}
    setState(() => _otpSending = false);
  }

  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();
    final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
    if (res.statusCode == 200 && jsonDecode(res.body)["Status"] == "Success") {
      setState(() { _otpVerified = true; _otpVisible = false; });
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }
    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verify phone number first")));
      return;
    }
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please accept Terms")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uname = _username.text.trim();
      final hiddenEmail = "${uname.toLowerCase()}@aranpani.com";

      final userCred = await _auth.createUserWithEmailAndPassword(
          email: hiddenEmail, password: _password.text.trim());
      
      await _firestore.collection("users").doc(userCred.user!.uid).set({
        "name": _name.text.trim(),
        "username": uname,
        "phoneNumber": _phone.text.trim(),
        "aadharNumber": _aadhar.text.trim(),
        "address": _address.text.trim(),
        "state": _state.text.trim(),
        "country": _country.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
        "phoneVerified": true,
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgColor, const Color(0xFFF5E6CA)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                _buildLogo(),
                const SizedBox(height: 12),
                Text(
                  "Aranpani",
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 28, fontWeight: FontWeight.bold, color: accentColor,
                  ),
                ),
                Text(
                  "Create your sacred account",
                  style: GoogleFonts.poppins(fontSize: 14, color: textMuted),
                ),
                const SizedBox(height: 30),
                Form(
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
                      const SizedBox(height: 24),
                      _termsCheckbox(),
                      const SizedBox(height: 24),
                      _signupButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(Icons.temple_hindu_rounded, size: 40, color: bgColor),
    );
  }

  InputDecoration _fieldDecoration(String lbl, IconData ic) {
    return InputDecoration(
      labelText: lbl,
      labelStyle: GoogleFonts.poppins(color: textMuted, fontSize: 14),
      prefixIcon: Icon(ic, color: accentColor, size: 22),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }

  Widget _input(TextEditingController c, String lbl, IconData ic, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: textDark),
      decoration: _fieldDecoration(lbl, ic),
      validator: (v) => v!.isEmpty ? "Required field" : null,
    );
  }

  Widget _passwordField(TextEditingController c, String lbl) {
    return TextFormField(
      controller: c,
      obscureText: true,
      style: GoogleFonts.poppins(color: textDark),
      decoration: _fieldDecoration(lbl, Icons.lock_outline),
      validator: (v) => v!.length < 6 ? "Minimum 6 characters" : null,
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
                  maxLength: 10,
                  style: GoogleFonts.poppins(color: textDark),
                  decoration: _fieldDecoration("Phone Number", Icons.phone_outlined).copyWith(counterText: ""),
                  onChanged: (v) => setState(() {}),
                  validator: (v) => v!.length != 10 ? "Enter 10 digits" : null,
                ),
              ),
              if (_phone.text.length == 10 && !_otpVisible)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ElevatedButton(
                    onPressed: _otpSending ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: bgColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _otpSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("GET OTP"),
                  ),
                )
            ],
          ),
        if (_otpVisible && !_otpVerified) _otpUI(),
        if (_otpVerified)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text("Phone Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
          ),
      ],
    );
  }

  Widget _otpUI() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(6, (i) => _otpBox(i))),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _verifyOtp,
          child: Text("Verify OTP", style: GoogleFonts.poppins(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 40, height: 50, margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _otpControllers[index], focusNode: _otpFocusNodes[index],
        maxLength: 1, keyboardType: TextInputType.number, textAlign: TextAlign.center,
        decoration: InputDecoration(counterText: "", filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _otpFocusNodes[index - 1].requestFocus();
        },
      ),
    );
  }

  Widget _termsCheckbox() {
    return Row(children: [
      Checkbox(value: _agree, activeColor: accentColor, onChanged: (v) => setState(() => _agree = v ?? false)),
      Expanded(child: Text("I agree to the Terms & Conditions", style: GoogleFonts.poppins(color: textDark, fontSize: 13))),
    ]);
  }

  Widget _signupButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signup,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: bgColor,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : Text("CREATE ACCOUNT", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}