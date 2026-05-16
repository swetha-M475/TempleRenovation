// lib/screens/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'screens/welcome_screen.dart';

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
  final String otpMethod; 

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
    
    // FIX: Use explicit endpoints. SMS now includes '/OTPSMS' to prevent voice fallback.
    String url = "";
    if (widget.otpMethod == 'Phone') {
      url = "https://2factor.in/API/V1/$apiKey/VOICE/+91$phone/AUTOGEN";
    } else {
      url = "https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN/OTPSMS";
    }

    try {
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      
      if (data["Status"] == "Success") {
        _sessionId = data["Details"];
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP Sent via ${widget.otpMethod}")));
      } else {
        throw data["Details"] ?? "Error";
      }
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
        UserCredential userCred = await _auth.createUserWithEmailAndPassword(
          email: widget.email,
          password: widget.password.trim(),
        );

        await _firestore.collection('users').doc(userCred.user!.uid).set({
          'name': widget.fullName,
          'username': widget.username,
          'phoneNumber': widget.phoneNumber,
          'email': widget.email,
          'aadharNumber': widget.aadhar,
          'address': widget.address,
          'state': widget.state,
          'country': widget.country,
          'createdAt': FieldValue.serverTimestamp(),
          'otpMethod': widget.otpMethod,
          'phoneVerified': true,
        });

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(title: const Text("Verify OTP"), backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Icon(widget.otpMethod == 'SMS' ? Icons.message : Icons.phone_in_talk, size: 60, color: const Color(0xFF5D4037)),
            const SizedBox(height: 20),
            Text("Sent to +91 ${widget.phoneNumber} via ${widget.otpMethod}"),
            const SizedBox(height: 40),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(6, (i) => _otpBox(i))),
            const SizedBox(height: 40),
            _loading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), minimumSize: const Size(double.infinity, 50)),
                  child: const Text("VERIFY & REGISTER", style: TextStyle(color: Colors.white)),
                ),
            const SizedBox(height: 20),
            _resendAvailable
              ? TextButton(onPressed: _sendOtpViaAPI, child: const Text("Resend OTP"))
              : Text("Resend in $_resendTimer s"),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 40, margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _otpControllers[index], focusNode: _otpFocusNodes[index],
        maxLength: 1, textAlign: TextAlign.center, keyboardType: TextInputType.number,
        decoration: InputDecoration(counterText: "", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) _otpFocusNodes[index + 1].requestFocus();
          if (v.isEmpty && index > 0) _otpFocusNodes[index - 1].requestFocus();
          if (v.length == 1 && index == 5) _verifyOtp();
        },
      ),
    );
  }
}