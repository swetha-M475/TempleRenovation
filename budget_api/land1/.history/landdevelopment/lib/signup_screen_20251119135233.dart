// lib/screens/signup_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verify_email_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // FORM CONTROLLERS
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

  // OTP RELATED
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  bool _otpVisible = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;

  bool _phoneLocked = false; // added
  String _sessionId = "";

  static const String apiKey =
      "0b23b35d-c516-11f0-a6b2-0200cd936042"; // your API key

  bool _agree = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();

    // Reset verification if user deletes number
    _phone.addListener(() {
      if (_phone.text.length < 10) {
        setState(() {
          _otpVerified = false;
          _otpVisible = false;
          _phoneLocked = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    _email.dispose();
    _aadhar.dispose();
    _address.dispose();
    _state.dispose();
    _country.dispose();
    _password.dispose();
    _confirm.dispose();
    for (var c in _otpControllers) c.dispose();
    super.dispose();
  }

  // -------------------------
  // SEND OTP USING 2FACTOR
  // -------------------------
  Future<void> _sendOTP() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) {
      _showMsg("Enter valid 10-digit phone");
      return;
    }

    setState(() => _sendingOtp = true);

    final url =
        Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN");

    final res = await http.get(url);

    setState(() => _sendingOtp = false);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      if (data["Status"] == "Success") {
        _sessionId = data["Details"];
        setState(() => _otpVisible = true);
        _showMsg("OTP sent", green: true);
      } else {
        _showMsg("OTP sending failed");
      }
    } else {
      _showMsg("OTP sending failed");
    }
  }

  // -------------------------
  // VERIFY OTP
  // -------------------------
  Future<void> _verifyOTP() async {
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      _showMsg("Enter 6-digit OTP");
      return;
    }

    final url = Uri.parse(
        "https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp");

    final res = await http.get(url);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      if (data["Status"] == "Success") {
        setState(() {
          _otpVerified = true;
          _phoneLocked = true; // lock phone after verification
        });
        _showMsg("Phone verified successfully", green: true);
      } else {
        _showMsg("Invalid OTP");
      }
    } else {
      _showMsg("OTP verification failed");
    }
  }

  void _showMsg(String msg, {bool green = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: green ? Colors.green : Colors.red,
      ),
    );
  }

  // -------------------------
  // MAIN SIGNUP FUNCTION
  // -------------------------
  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_otpVerified) {
      _showMsg("Verify your phone number first");
      return;
    }

    if (!_agree) {
      _showMsg("Please accept Terms & Conditions");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uname = _username.text.trim();

      // Unique username check
      final q = await _firestore
          .collection("users")
          .where("username", isEqualTo: uname)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) throw "Username already exists";

      final userCred = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      final user = userCred.user!;
      await user.sendEmailVerification();

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
        "emailVerified": false,
        "phoneVerified": true,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user)),
      );
    } catch (e) {
      _showMsg("Signup error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // -------------------------
  // UI PART
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0404), Color(0xFF7A1E1E), Color(0xFFF5DEB3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // LOGO
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                    ),
                  ),
                  child: const Icon(Icons.temple_hindu_rounded,
                      size: 60, color: Colors.white),
                ),

                const SizedBox(height: 20),

                Text(
                  "Aranpani",
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD4AF37),
                  ),
                ),

                const SizedBox(height: 32),

                // FORM CONTAINER
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _input(_name, "Full Name", Icons.person),
                        const SizedBox(height: 16),
                        _input(_username, "Username", Icons.person_3),
                        const SizedBox(height: 16),
                        _phoneField(),
                        const SizedBox(height: 16),
                        _input(_email, "Email", Icons.email,
                            type: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        _input(_aadhar, "Aadhaar Number", Icons.badge,
                            type: TextInputType.number),
                        const SizedBox(height: 16),
                        _input(_address, "Address", Icons.home),
                        const SizedBox(height: 16),
                        _input(_state, "State", Icons.location_city),
                        const SizedBox(height: 16),
                        _input(_country, "Country", Icons.public),
                        const SizedBox(height: 16),
                        _passwordField(),
                        const SizedBox(height: 16),
                        _confirmPasswordField(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Checkbox(
                                value: _agree,
                                onChanged: (v) =>
                                    setState(() => _agree = v ?? false),
                                activeColor: Colors.amber),
                            Expanded(
                              child: Text("I agree to Terms & Conditions",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 14)),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : ElevatedButton(
                                onPressed: _signup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  minimumSize: const Size(double.infinity, 55),
                                ),
                                child: const Text(
                                  "Create Account",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------
  // PHONE FIELD + OTP
  // -------------------------
  Widget _phoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _phone,
          enabled: !_phoneLocked,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Phone Number",
            labelStyle: const TextStyle(color: Colors.white),
            prefixIcon: Icon(Icons.phone, color: Colors.amber.shade200),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.amber.shade200.withOpacity(0.7)),
            ),
            suffixIcon: _otpVerified
                ? const Icon(Icons.check_circle, color: Colors.green)
                : (_phone.text.length == 10
                    ? TextButton(
                        onPressed: _sendingOtp ? null : _sendOTP,
                        child: _sendingOtp
                            ? const SizedBox(
                                height: 15,
                                width: 15,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("Send",
                                style: TextStyle(color: Colors.amber)))
                    : null),
          ),
          validator: (v) =>
              v == null || v.length != 10 ? "Enter valid phone number" : null,
        ),
        const SizedBox(height: 10),
        if (_otpVisible && !_otpVerified) _otpArea(),
      ],
    );
  }

  // -------------------------
  // OTP INPUT BOXES
  // -------------------------
  Widget _otpArea() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            return Container(
              width: 42,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _otpControllers[i],
                maxLength: 1,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.3))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.amber.withOpacity(0.7))),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) {
                    FocusScope.of(context).nextFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _verifyOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
          ),
          child:
              const Text("Verify OTP", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  // -------------------------
  // HELPER INPUT FIELDS
  // -------------------------
  Widget _input(TextEditingController c, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.amber.shade200),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: (v) => v == null || v.trim().isEmpty ? "Enter $label" : null,
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _password,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: "Password",
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: Icon(Icons.lock, color: Colors.amber.shade200),
        suffixIcon: IconButton(
          icon:
              Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: (v) => v == null || v.length < 6 ? "Min 6 characters" : null,
    );
  }

  Widget _confirmPasswordField() {
    return TextFormField(
      controller: _confirm,
      obscureText: _obscureConfirm,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: "Confirm Password",
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: Icon(Icons.lock, color: Colors.amber.shade200),
        suffixIcon: IconButton(
          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: (v) => v != _password.text ? "Passwords do not match" : null,
    );
  }
}
