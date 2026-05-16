// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

// Import your welcome screen here
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

  // --- OTP & Logic Methods (Kept as previously discussed) ---
  
  void _startTimer() {
    _secondsLeft = 30;
    _resendAvailable = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) { _secondsLeft--; } 
        else { _resendAvailable = true; timer.cancel(); }
      });
    });
  }

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
          _startTimer();
        }
      }
    } catch (e) { /* Error handling */ }
    setState(() => _otpSending = false);
  }

  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();
    final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
    if (res.statusCode == 200 && jsonDecode(res.body)["Status"] == "Success") {
      setState(() { _otpVerified = true; _otpVisible = false; });
    }
  }

  // --- Updated Signup (No Email Verification) ---

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please verify your phone number first")));
      return;
    }
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please accept the Terms")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uname = _username.text.trim();
      
      // Check username
      final q = await _firestore.collection('users').where('username', isEqualTo: uname).limit(1).get();
      if (q.docs.isNotEmpty) throw "Username is already taken";

      // Create User
      final userCred = await _auth.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _password.text.trim());
      
      // Save Data
      await _firestore.collection("users").doc(userCred.user!.uid).set({
        "name": _name.text.trim(),
        "username": uname,
        "phoneNumber": _phone.text.trim(),
        "email": _email.text.trim(),
        "aadharNumber": _aadhar.text.trim(),
        "address": _address.text.trim(),
        "state": _state.text.trim(),
        "country": _country.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
        "phoneVerified": true,
        "emailVerified": true // Marked true as we are skipping manual verification
      });

      if (!mounted) return;
      // GO DIRECTLY TO WELCOME/HOME
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4A0404), // Deep Red/Maroon
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
                const SizedBox(height: 25),
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

  // --- UI WIDGETS ---

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
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 10),
                Text("Phone Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _otpUI() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _otpBox(i)),
        ),
        const SizedBox(height: 12),
        if (!_resendAvailable)
          Text("Resend in $_secondsLeft s", style: const TextStyle(color: Colors.white70)),
        if (_resendAvailable)
          TextButton(onPressed: _sendOTP, child: const Text("Resend OTP", style: TextStyle(color: Colors.amber))),
        const SizedBox(height: 10),
        ElevatedButton(onPressed: _verifyOtp, child: const Text("Verify OTP")),
      ],
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 40, height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(counterText: "", filled: true, fillColor: Colors.white.withOpacity(0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _otpFocusNodes[index - 1].requestFocus();
        },
      ),
    );
  }

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
        Checkbox(
          value: _agree, 
          activeColor: Colors.amber, 
          side: const BorderSide(color: Colors.white70),
          onChanged: (v) => setState(() => _agree = v ?? false),
        ),
        const Expanded(child: Text("I agree to Terms & Conditions", style: TextStyle(color: Colors.white, fontSize: 13))),
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
            ),
            child: ElevatedButton(
              onPressed: _signup,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
              child: const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          );
  }
}