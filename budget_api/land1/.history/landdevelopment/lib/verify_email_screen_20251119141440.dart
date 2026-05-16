import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'verify_email_screen.dart';
import 'dart:async';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

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

  // OTP Controllers & Focus
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _otpVisible = false;
  bool _otpVerified = false;
  bool _otpSending = false;
  bool _resendAvailable = false;

  String _sessionId = "";
  Timer? _timer;
  int _secondsLeft = 30;

  bool _agree = false;
  bool _isLoading = false;

  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  // Clean dispose
  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ---- TIMER ----
  void _startTimer() {
    _secondsLeft = 30;
    _resendAvailable = false;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _resendAvailable = true;
          timer.cancel();
        }
      });
    });
  }

  // ---- SEND OTP ----
  Future<void> _sendOTP() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10-digit number")),
      );
      return;
    }

    setState(() => _otpSending = true);

    final url = Uri.parse(
        "https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN");

    try {
      final res = await http.get(url);
      setState(() => _otpSending = false);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["Status"] == "Success") {
          setState(() {
            _otpVisible = true;
            _sessionId = data["Details"] ?? "";
          });

          for (var c in _otpControllers) c.clear();
          _otpFocusNodes.first.requestFocus();

          _startTimer();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("OTP Sent"),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      setState(() => _otpSending = false);
    }
  }

  // ---- VERIFY OTP ----
  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter valid OTP")));
      return;
    }

    final url = Uri.parse(
        "https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp");

    try {
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data["Status"] == "Success") {
          setState(() {
            _otpVerified = true;
            _otpVisible = false;
          });

          // move focus to next field
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 200), () {
            FocusScope.of(context).requestFocus(FocusNode());
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Phone Verified"),
                backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid OTP")),
          );
        }
      }
    } catch (e) {
      // ignore silently
    }
  }

  // ---- OTP BOX ----
  Widget _otpBox(TextEditingController c, int index) {
    return Container(
      width: 45,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: c,
        focusNode: _otpFocusNodes[index],
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),

        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) {
              _otpFocusNodes[index + 1].requestFocus();
            }
          } else {
            if (index > 0) {
              _otpFocusNodes[index - 1].requestFocus();
            }
          }
        },
      ),
    );
  }
}
