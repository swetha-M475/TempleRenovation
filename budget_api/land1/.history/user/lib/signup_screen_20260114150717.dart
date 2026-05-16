// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

import 'welcome_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // COLORS
  final Color _bgColor = const Color(0xFFFFFDF5);
  final Color _accentColor = const Color(0xFF5D4037);
  final Color _sandalwood = const Color(0xFFF5E6CA);
  final Color _mutedBronze = const Color(0xFF8D6E63);
  final Color _darkText = const Color(0xFF3E2723);

  // Controllers
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _aadhar = TextEditingController();
  final _address = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // Errors
  String? _usernameError;
  String? _phoneError;
  String? _aadharError;

  // OTP
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

  static const String apiKey =
      "0b23b35d-c516-11f0-a6b2-0200cd936042";

  Timer? _debounce;

  // ---------------- REAL-TIME DB CHECK ----------------

  void _onFieldChanged(String field, String value, int minLen) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.length >= minLen) {
        _checkDuplicate(field, value);
      } else {
        setState(() {
          if (field == "username") _usernameError = null;
          if (field == "phoneNumber") _phoneError = null;
          if (field == "aadharNumber") _aadharError = null;
        });
      }
    });
  }

  Future<void> _checkDuplicate(String field, String value) async {
    try {
      final snap = await _firestore
          .collection('users')
          .where(field, isEqualTo: value)
          .limit(1)
          .get();

      setState(() {
        if (snap.docs.isNotEmpty) {
          if (field == "username") {
            _usernameError = "Username already taken";
          }
          if (field == "phoneNumber") {
            _phoneError = "Phone number already registered";
          }
          if (field == "aadharNumber") {
            _aadharError = "Aadhar already registered";
          }
        } else {
          if (field == "username") _usernameError = null;
          if (field == "phoneNumber") _phoneError = null;
          if (field == "aadharNumber") _aadharError = null;
        }
      });
    } catch (_) {}
  }

  // ---------------- OTP ----------------

  void _startTimer() {
    _secondsLeft = 30;
    _resendAvailable = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _resendAvailable = true;
        t.cancel();
      }
    });
  }

  Future<void> _sendOTP() async {
    if (_phone.text.length != 10 || _phoneError != null) return;
    setState(() => _otpSending = true);
    try {
      final res = await http.get(Uri.parse(
          "https://2factor.in/API/V1/$apiKey/SMS/+91${_phone.text}/AUTOGEN"));
      final data = jsonDecode(res.body);
      if (data["Status"] == "Success") {
        setState(() {
          _otpVisible = true;
          _sessionId = data["Details"];
        });
        _startTimer();
      }
    } catch (_) {}
    setState(() => _otpSending = false);
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((e) => e.text).join();
    final res = await http.get(Uri.parse(
        "https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
    if (jsonDecode(res.body)["Status"] == "Success") {
      setState(() {
        _otpVerified = true;
        _otpVisible = false;
      });
    }
  }

  // ---------------- SIGNUP ----------------

  Future<void> _signup() async {
    if (_usernameError != null ||
        _phoneError != null ||
        _aadharError != null) return;

    if (!_formKey.currentState!.validate()) return;
    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verify phone number first")));
      return;
    }
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Accept terms")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final email = "${_username.text}@aranpani.com";
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: _password.text);

      await _firestore.collection("users").doc(cred.user!.uid).set({
        "name": _name.text,
        "username": _username.text,
        "phoneNumber": _phone.text,
        "aadharNumber": _aadhar.text,
        "address": _address.text,
        "state": _state.text,
        "country": _country.text,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _isLoading = false);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _input(_name, "Full Name", Icons.person),
                _input(_username, "Username", Icons.alternate_email,
                    onChange: (v) =>
                        _onFieldChanged("username", v, 4),
                    error: _usernameError),
                _phoneField(),
                _input(_aadhar, "Aadhar", Icons.badge,
                    keyboard: TextInputType.number,
                    onChange: (v) =>
                        _onFieldChanged("aadharNumber", v, 12),
                    error: _aadharError),
                _input(_address, "Address", Icons.home),
                _input(_state, "State", Icons.location_city),
                _input(_country, "Country", Icons.public),
                _input(_password, "Password", Icons.lock,
                    obscure: true),
                _input(_confirm, "Confirm Password", Icons.lock,
                    obscure: true),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _signup,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Create Account"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      onChanged: (v) => _onFieldChanged("phoneNumber", v, 10),
      decoration: InputDecoration(
        labelText: "Phone Number",
        errorText: _phoneError,
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i,
      {bool obscure = false,
      TextInputType keyboard = TextInputType.text,
      Function(String)? onChange,
      String? error}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        onChanged: onChange,
        decoration:
            InputDecoration(labelText: l, errorText: error),
      ),
    );
  }
}
