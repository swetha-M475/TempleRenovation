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
  final String otpMethod; // New parameter to track SMS vs Phone

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

  @override
  void dispose() {
    for (var c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() async {
    setState(() {
      _resendAvailable = false;
      _resendTimer = 30;
    });

    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _resendTimer--;
      });
    }

    if (mounted) {
      setState(() {
        _resendAvailable = true;
      });
    }
  }

  Future<void> _sendOtp() async {
    // Note: Firebase verifyPhoneNumber sends an SMS. 
    // If your number is linked to a WhatsApp forwarding service, 
    // the user will receive it there.
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${widget.phoneNumber.trim()}",
      timeout: const Duration(seconds: 30),
      verificationCompleted: (credential) async {
        // Auto-verification handling
      },
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("OTP send failed: ${e.message}"),
            backgroundColor: const Color(0xFF6D1B1B),
          ),
        );
      },
      codeSent: (verificationId, _) {
        setState(() => _verificationId = verificationId);
      },
      codeAutoRetrievalTimeout: (id) {
        _verificationId = id;
      },
    );
  }

  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 6 digit OTP!")),
      );
      return;
    }

    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification not started")),
      );
      return;
    }

    try {
      setState(() => _loading = true);
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Sign in with phone credential
      await _auth.signInWithCredential(credential);

      // Create email/password user
      User firebaseUser = (await _auth.createUserWithEmailAndPassword(
        email: widget.email.trim(),
        password: widget.password.trim(),
      ))
          .user!;

      // Save user data to Firestore
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'name': widget.fullName,
        'username': widget.username,
        'phoneNumber': widget.phoneNumber,
        'email': widget.email,
        'aadharNumber': widget.aadhar,
        'address': widget.address,
        'state': widget.state,
        'country': widget.country,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'otpMethod': widget.otpMethod,
      });

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification failed: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _otpBox(int index) {
    return Container(
      width: 48,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _otpControllers[index],
        autofocus: index == 0,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context).nextFocus();
          }
          if (value.isEmpty && index > 0) {
            FocusScope.of(context).previousFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Logic for dynamic messaging based on user choice
    String instructionText = widget.otpMethod == 'SMS' 
        ? "Enter OTP received via SMS/WhatsApp" 
        : "Enter OTP received via Phone Call";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Verification",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF6D1B1B),
        foregroundColor: const Color(0xFFFFF4D6),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0404), Color(0xFF6D1B1B), Color(0xFFFFF7E8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(
                widget.otpMethod == 'SMS' ? Icons.message_rounded : Icons.phone_android_rounded,
                size: 60,
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(height: 20),
              Text(instructionText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text("+91 ${widget.phoneNumber}",
                  style: GoogleFonts.poppins(
                      color: const Color(0xFFD4AF37),
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              const SizedBox(height: 30),
              _resendAvailable
                  ? TextButton(
                      onPressed: () {
                        _sendOtp();
                        _startResendTimer();
                      },
                      child: Text("Resend Code",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                    )
                  : Text("Resend in $_resendTimer sec",
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 40),
              _loading
                  ? const CircularProgressIndicator(color: Color(0xFFD4AF37))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text("VERIFY NOW",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: const Color(0xFF4A1010))),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}