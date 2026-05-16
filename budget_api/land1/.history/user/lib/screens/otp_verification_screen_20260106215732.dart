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
  final String fullName, username, phoneNumber, email, aadhar, address, state, country, password;

  const OTPVerificationScreen({
    super.key, required this.fullName, required this.username, required this.phoneNumber,
    required this.email, required this.aadhar, required this.address, required this.state,
    required this.country, required this.password,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  String _sessionId = "";
  bool _isLoading = false;
  bool _isOtpSent = false;
  String _selectedMethod = 'SMS'; 
  int _timerCount = 30;
  Timer? _timer;
  
  // YOUR 2FACTOR API KEY
  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _timerCount = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timerCount > 0) {
          _timerCount--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // --- SEND OTP LOGIC ---
  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    final phone = widget.phoneNumber.trim();
    
    // Logic: 2Factor.in handles SMS and Voice Calls. 
    // WhatsApp usually requires a separate WhatsApp Business API.
    String url = _selectedMethod == 'Phone' 
      ? "https://2factor.in/API/V1/$apiKey/VOICE/+91$phone/AUTOGEN"
      : "https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN/OTPSMS";

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);
      
      if (data["Status"] == "Success") {
        setState(() {
          _sessionId = data["Details"];
          _isOtpSent = true;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Code sent via $_selectedMethod"), backgroundColor: Colors.blue)
        );
      } else {
        throw data["Details"] ?? "API Error";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
      );
    }
    setState(() => _isLoading = false);
  }

  // --- VERIFY OTP & REGISTER ---
  Future<void> _verifyAndRegister() async {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) return;

    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
      final data = jsonDecode(res.body);

      if (data["Status"] == "Success") {
        // 1. Create User in Firebase Auth
        UserCredential userCred = await _auth.createUserWithEmailAndPassword(
          email: widget.email, 
          password: widget.password.trim()
        );

        // 2. Save Profile to Firestore
        await _firestore.collection('users').doc(userCred.user!.uid).set({
          'name': widget.fullName,
          'username': widget.username,
          'phoneNumber': widget.phoneNumber,
          'email': widget.email,
          'aadhar': widget.aadhar,
          'address': widget.address,
          'state': widget.state,
          'country': widget.country,
          'createdAt': FieldValue.serverTimestamp(),
          'verified': true,
        });

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP code"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification Failed: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(title: const Text("OTP Verification"), backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text("Select Verification Method", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Sending to: +91 ${widget.phoneNumber}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            // Method Selection Tiles
            _methodTile("SMS Message", 'SMS', Icons.message_outlined),
            _methodTile("Phone Call", 'Phone', Icons.phone_callback_outlined),
            
            const SizedBox(height: 30),
            
            if (!_isOtpSent)
              ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("GET OTP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),

            if (_isOtpSent) ...[
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (i) => _otpBox(i))),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("VERIFY & REGISTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
              _timerCount > 0 
                ? Text("Resend available in $_timerCount s") 
                : TextButton(onPressed: _sendOtp, child: const Text("Resend Code")),
            ]
          ],
        ),
      ),
    );
  }

  Widget _methodTile(String title, String val, IconData icon) {
    bool isSelected = _selectedMethod == val;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = val),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5D4037).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF5D4037) : Colors.grey.shade300, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF5D4037) : Colors.grey),
            const SizedBox(width: 15),
            Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF5D4037))
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(counterText: "", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _otpFocusNodes[index - 1].requestFocus();
          if (v.length == 1 && index == 5) _verifyAndRegister();
        },
      ),
    );
  }
}