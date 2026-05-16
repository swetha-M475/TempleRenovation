// lib/screens/otp_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final String otpMethod; // RECEIVING THE CHOICE

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

  String? _verificationId;
  bool _loading = false;
  bool _resendAvailable = false;
  int _resendTimer = 30;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    // If otpMethod is 'Phone', Firebase usually sends a voice call if SMS fails, 
    // but for most standard setups, verifyPhoneNumber triggers the SMS flow.
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${widget.phoneNumber.trim()}",
      timeout: const Duration(seconds: 30),
      verificationCompleted: (credential) {},
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${e.message}"), backgroundColor: const Color(0xFF6D1B1B)));
      },
      codeSent: (verificationId, _) {
        setState(() => _verificationId = verificationId);
      },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
  }

  void _startResendTimer() async {
    setState(() { _resendAvailable = false; _resendTimer = 30; });
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() { _resendTimer--; });
    }
    if (mounted) setState(() { _resendAvailable = true; });
  }

  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6 || _verificationId == null) return;

    try {
      setState(() => _loading = true);
      PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: otp);
      await _auth.signInWithCredential(credential);

      User firebaseUser = (await _auth.createUserWithEmailAndPassword(email: widget.email.trim(), password: widget.password.trim())).user!;

      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'name': widget.fullName,
        'username': widget.username,
        'phoneNumber': widget.phoneNumber,
        'email': widget.email,
        'otpMethod': widget.otpMethod, // Save method used
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification failed: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verification"), backgroundColor: const Color(0xFF6D1B1B), foregroundColor: const Color(0xFFFFF4D6)),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4A0404), Color(0xFF6D1B1B), Color(0xFFFFF7E8)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text("Checking ${widget.otpMethod} for OTP", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
            Text("+91 ${widget.phoneNumber}", style: GoogleFonts.poppins(color: const Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(6, (i) => _otpBox(i))),
            const SizedBox(height: 30),
            _resendAvailable 
              ? TextButton(onPressed: _sendOtp, child: Text("Resend Code", style: TextStyle(color: Color(0xFFD4AF37))))
              : Text("Resend in $_resendTimer sec", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 40),
            _loading ? CircularProgressIndicator() : ElevatedButton(
              onPressed: _verifyOtp,
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFD4AF37), padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
              child: Text("VERIFY", style: TextStyle(color: Color(0xFF4A1010), fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 45,
      margin: EdgeInsets.symmetric(horizontal: 5),
      child: TextField(
        controller: _otpControllers[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(color: Colors.white, fontSize: 20),
        decoration: InputDecoration(counterText: "", filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        onChanged: (v) { if (v.length == 1 && index < 5) FocusScope.of(context).nextFocus(); },
      ),
    );
  }
}