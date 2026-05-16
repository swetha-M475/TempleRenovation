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
  final String otpMethod; // SMS or Phone

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
    // If you specifically want phone call for "Phone" method, 
    // standard Firebase verifyPhoneNumber triggers SMS first.
    // If it fails, it can fallback to a call automatically.
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${widget.phoneNumber.trim()}",
      timeout: const Duration(seconds: 30),
      verificationCompleted: (credential) {},
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${e.message}"), backgroundColor: const Color(0xFF6D1B1B))
        );
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
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);

      User firebaseUser = (await _auth.createUserWithEmailAndPassword(
        email: widget.email.trim(),
        password: widget.password.trim(),
      )).user!;

      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'name': widget.fullName,
        'username': widget.username,
        'phoneNumber': widget.phoneNumber,
        'email': widget.email,
        'aadharNumber': widget.aadhar,
        'address': widget.address,
        'state': widget.state,
        'country': widget.country,
        'otpMethodUsed': widget.otpMethod,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification failed: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Verify OTP"),
        backgroundColor: const Color(0xFF6D1B1B),
        foregroundColor: const Color(0xFFFFF4D6),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0404), Color(0xFF6D1B1B), Color(0xFFFFF7E8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              "OTP triggered via ${widget.otpMethod}",
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              "+91 ${widget.phoneNumber}",
              style: GoogleFonts.poppins(color: const Color(0xFFD4AF37), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) => _otpBox(i)),
            ),
            const SizedBox(height: 40),
            _loading 
              ? CircularProgressIndicator(color: Color(0xFFD4AF37))
              : ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text("VERIFY", style: GoogleFonts.poppins(color: const Color(0xFF4A1010), fontWeight: FontWeight.bold)),
                ),
            const SizedBox(height: 20),
            _resendAvailable 
              ? TextButton(onPressed: _sendOtp, child: Text("Resend Code", style: TextStyle(color: Color(0xFFD4AF37))))
              : Text("Resend in $_resendTimer sec", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return Container(
      width: 45,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: TextField(
        controller: _otpControllers[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
        ),
        onChanged: (v) { if (v.length == 1 && index < 5) FocusScope.of(context).nextFocus(); },
      ),
    );
  }
}