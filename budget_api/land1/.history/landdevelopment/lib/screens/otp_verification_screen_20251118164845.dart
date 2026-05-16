// lib/screens/otp_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'welcome_screen.dart';

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
    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${widget.phoneNumber.trim()}",
      timeout: const Duration(seconds: 30),
      verificationCompleted: (credential) async {
        // Auto verification for some numbers (rare)
      },
      verificationFailed: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("OTP send failed: ${e.message}"),
            backgroundColor: Colors.red,
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

      UserCredential phoneVerifiedUser =
          await _auth.signInWithCredential(credential);

      User firebaseUser = (await _auth.createUserWithEmailAndPassword(
        email: widget.email.trim(),
        password: widget.password.trim(),
      ))
          .user!;

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
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _otpControllers[index],
        autofocus: index == 0,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, color: Colors.white),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.4), width: 1)),
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Phone Verification",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF6A1F1A),
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0404), Color(0xFF7A1E1E), Color(0xFFF5DEB3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),
              Text("Enter OTP sent to",
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 15)),
              Text("+91 ${widget.phoneNumber}",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _otpBox(i)),
              ),

              const SizedBox(height: 20),
              _resendAvailable
                  ? TextButton(
                      onPressed: () {
                        _sendOtp();
                        _startResendTimer();
                      },
                      child: Text("Resend OTP",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFD4AF37),
                            fontWeight: FontWeight.w500,
                          )),
                    )
                  : Text("Resend in $_resendTimer sec",
                      style: GoogleFonts.poppins(color: Colors.white70)),

              const SizedBox(height: 30),

              _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : ElevatedButton(
                      onPressed: _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Verify",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
