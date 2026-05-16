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
  final String fullName, username, phoneNumber, email, aadhar, address, state, country, password, otpMethod; 

  const OTPVerificationScreen({
    super.key, required this.fullName, required this.username, required this.phoneNumber,
    required this.email, required this.aadhar, required this.address, required this.state,
    required this.country, required this.password, required this.otpMethod,
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
  bool _loading = false;
  bool _resendAvailable = false;
  int _resendTimer = 30;
  Timer? _timer;
  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  @override
  void initState() {
    super.initState();
    _sendOtpViaAPI(); 
  }

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() { _resendAvailable = false; _resendTimer = 30; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_resendTimer > 0) { _resendTimer--; } 
        else { _resendAvailable = true; timer.cancel(); }
      });
    });
  }

  Future<void> _sendOtpViaAPI() async {
    setState(() => _loading = true);
    final phone = widget.phoneNumber.trim();
    String url = widget.otpMethod == 'Phone' 
      ? "https://2factor.in/API/V1/$apiKey/VOICE/+91$phone/AUTOGEN"
      : "https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN/OTPSMS";

    try {
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      if (data["Status"] == "Success") {
        _sessionId = data["Details"];
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP Sent via ${widget.otpMethod}")));
      } else { throw data["Details"] ?? "Error"; }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
    setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) return;
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
      final data = jsonDecode(res.body);
      if (data["Status"] == "Success") {
        UserCredential userCred = await _auth.createUserWithEmailAndPassword(email: widget.email, password: widget.password.trim());
        await _firestore.collection('users').doc(userCred.user!.uid).set({
          'name': widget.fullName, 'username': widget.username, 'phoneNumber': widget.phoneNumber,
          'email': widget.email, 'aadharNumber': widget.aadhar, 'address': widget.address,
          'state': widget.state, 'country': widget.country, 'createdAt': FieldValue.serverTimestamp(),
          'phoneVerified': true,
        });
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
      } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP"))); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(title: const Text("Verify OTP"), backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white),
      body: SingleChildScrollView( // FIX: Added scroll view to prevent UI parts from disappearing
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(widget.otpMethod == 'SMS' ? Icons.message : Icons.phone_in_talk, size: 80, color: const Color(0xFF5D4037)),
              const SizedBox(height: 24),
              Text("Verification Code", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Enter the 6-digit code sent to\n+91 ${widget.phoneNumber}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              // OTP BOXES START
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              // OTP BOXES END
              const SizedBox(height: 40),
              _loading 
                ? const CircularProgressIndicator(color: Color(0xFF5D4037))
                : ElevatedButton(
                    onPressed: _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("VERIFY & REGISTER", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
              const SizedBox(height: 24),
              _resendAvailable
                ? TextButton(onPressed: _sendOtpViaAPI, child: const Text("Resend Code", style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold)))
                : Text("Resend in $_resendTimer seconds", style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 45, // Slightly wider for better finger tap area
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        autofocus: index == 0,
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.grey)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5D4037), width: 2)),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
          if (v.length == 1 && index == 5) {
            FocusScope.of(context).unfocus(); // Close keyboard on last digit
            _verifyOtp();
          }
        },
      ),
    );
  }
}