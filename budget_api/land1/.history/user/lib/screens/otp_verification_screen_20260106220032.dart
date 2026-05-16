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
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  String _sessionId = "";
  bool _isLoading = false;
  bool _otpSent = false;
  String _method = 'SMS';
  int _timer = 30;
  Timer? _countdown;
  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  void _startTimer() {
    setState(() => _timer = 30);
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timer == 0) t.cancel();
      else setState(() => _timer--);
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    String url = _method == 'SMS' 
        ? "https://2factor.in/API/V1/$apiKey/SMS/+91${widget.phoneNumber}/AUTOGEN/OTPSMS"
        : "https://2factor.in/API/V1/$apiKey/VOICE/+91${widget.phoneNumber}/AUTOGEN";

    try {
      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      if (data["Status"] == "Success") {
        _sessionId = data["Details"];
        setState(() => _otpSent = true);
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Code sent via $_method")));
      } else { throw data["Details"]; }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _verify() async {
    String otp = _controllers.map((e) => e.text).join();
    if (otp.length < 6) return;

    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
      final data = jsonDecode(res.body);

      if (data["Status"] == "Success") {
        UserCredential cred = await _auth.createUserWithEmailAndPassword(email: widget.email, password: widget.password);
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'name': widget.fullName, 'phone': widget.phoneNumber, 'aadhar': widget.aadhar,
          'address': widget.address, 'state': widget.state, 'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (r) => false);
      } else { throw "Invalid OTP"; }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP"), backgroundColor: const Color(0xFF5D4037)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("Send code to +91 ${widget.phoneNumber}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            if (!_otpSent) ...[
              ListTile(
                title: const Text("Receive via SMS"),
                leading: Radio(value: 'SMS', groupValue: _method, onChanged: (v) => setState(() => _method = v!)),
              ),
              ListTile(
                title: const Text("Receive via Phone Call"),
                leading: Radio(value: 'Phone', groupValue: _method, onChanged: (v) => setState(() => _method = v!)),
              ),
              ElevatedButton(onPressed: _isLoading ? null : _sendOtp, child: const Text("SEND OTP")),
            ] else ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (i) => _box(i))),
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _isLoading ? null : _verify, child: const Text("VERIFY & REGISTER")),
              if (_timer == 0) TextButton(onPressed: _sendOtp, child: const Text("Resend OTP")) else Text("Resend in $_timer s"),
            ]
          ],
        ),
      ),
    );
  }

  Widget _box(int i) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: _controllers[i], focusNode: _focusNodes[i],
        keyboardType: TextInputType.number, maxLength: 1, textAlign: TextAlign.center,
        decoration: const InputDecoration(counterText: "", border: OutlineInputBorder()),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) _focusNodes[i+1].requestFocus();
          if (v.isEmpty && i > 0) _focusNodes[i-1].requestFocus();
        },
      ),
    );
  }
}