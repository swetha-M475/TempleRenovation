// lib/screens/otp_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../welcome_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String fullName;
  final String username;
  final String phoneNumber;
  final String email;
  final String aadhar;
  final String address;
  final String state;
  final String country;
  final String password;
  final String otpMethod; // 'SMS' or 'Phone'

  const OTPVerificationScreen({
    super.key,
    required this.fullName,
    required this.username,
    required this.phoneNumber,
    required this.email,
    required this.aadhar,
    required this.address,
    required this.state,
    required this.country,
    required this.password,
    required this.otpMethod,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  String _sessionId = "";
  bool _loading = false;
  bool _resendAvailable = false;
  int _resendTimer = 30;
  Timer? _timer;

  // Your API Key
  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  @override
  void initState() {
    super.initState();
    _sendOtpViaAPI(); // Call the API immediately on load
  }

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _resendAvailable = false;
      _resendTimer = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _resendAvailable = true;
          timer.cancel();
        }
      });
    });
  }

  // --- 2FACTOR API CALLS ---

  Future<void> _sendOtpViaAPI() async {
    setState(() => _loading = true);
    final phone = widget.phoneNumber.trim();
    
    // CORRECTION: Explicitly defining endpoints to prevent SMS falling back to Call
    String url = "";
    if (widget.otpMethod == 'Phone') {
      // Voice Call Endpoint
      url = "https://2factor.in/API/V1/$apiKey/VOICE/+91$phone/AUTOGEN";
    } else {
      // SMS Endpoint - Added OTPSMS suffix to force SMS behavior
      url = "https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN/OTPSMS";
    }

    try {
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      
      if (data["Status"] == "Success") {
        _sessionId = data["Details"];
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP Sent via ${widget.otpMethod}")),
        );
      } else {
        throw data["Details"] ?? "Failed to send";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter 6 digits")));
      return;
    }

    setState(() => _loading = true);
    try {
      // 1. Verify with 2Factor API (Verification endpoint is standard for both)
      final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
      final data = jsonDecode(res.body);

      if (data["Status"] == "Success") {
        // 2. Create Firebase User with hidden email logic
        final hiddenEmail = "${widget.username.toLowerCase()}@aranpani.com";
        UserCredential userCred = await _auth.createUserWithEmailAndPassword(
          email: hiddenEmail,
          password: widget.password.trim(),
        );

        // 3. Save full user profile to Firestore
        await _firestore.collection('users').doc(userCred.user!.uid).set({
          'name': widget.fullName,
          'username': widget.username,
          'phoneNumber': widget.phoneNumber,
          'email': hiddenEmail,
          'aadharNumber': widget.aadhar,
          'address': widget.address,
          'state': widget.state,
          'country': widget.country,
          'createdAt': FieldValue.serverTimestamp(),
          'otpMethod': widget.otpMethod,
          'phoneVerified': true,
        });

        // 4. Navigate to Welcome
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid OTP code. Please try again."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5), // Ivory
      appBar: AppBar(
        title: Text("OTP Verification", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF5D4037), // Bronze
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 30),
              // Dynamic Icon based on method
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D4037).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.otpMethod == 'SMS' ? Icons.message_rounded : Icons.phone_forwarded_rounded,
                  size: 60,
                  color: const Color(0xFF5D4037),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "Verify Number",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723)),
              ),
              const SizedBox(height: 10),
              Text(
                "Code sent to +91 ${widget.phoneNumber}",
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700]),
              ),
              Text(
                "via ${widget.otpMethod}",
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37)),
              ),
              const SizedBox(height: 40),
              // OTP Input Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              const SizedBox(height: 50),
              _loading
                  ? const CircularProgressIndicator(color: Color(0xFF5D4037))
                  : SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5D4037),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                        ),
                        child: Text(
                          "VERIFY & REGISTER",
                          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Didn't receive the code? ", style: GoogleFonts.poppins(color: Colors.grey[600])),
                  _resendAvailable
                      ? TextButton(
                          onPressed: _sendOtpViaAPI,
                          child: const Text("Resend Now", style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                        )
                      : Text("Wait ${_resendTimer}s", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 45,
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF5E6CA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
          ),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
          // Optional: Auto-verify on last digit
          if (v.isNotEmpty && index == 5) {
            _verifyOtp();
          }
        },
      ),
    );
  }
}