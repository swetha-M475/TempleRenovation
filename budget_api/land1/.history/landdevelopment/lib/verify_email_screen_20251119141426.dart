import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

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

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // TIMER
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

  // SEND OTP
  Future<void> _sendOTP() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10-digit number")),
      );
      return;
    }

    setState(() => _otpSending = true);

    final url =
        Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN");

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
                content: Text("OTP Sent"), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      setState(() => _otpSending = false);
    }
  }

  // VERIFY OTP
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

          FocusScope.of(context).unfocus();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Phone Verified"), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid OTP")),
          );
        }
      }
    } catch (e) {}
  }

  // OTP BOX
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
            if (index < 5) _otpFocusNodes[index + 1].requestFocus();
          } else {
            if (index > 0) _otpFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  // OTP UI
  Widget _otpUI() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _otpBox(_otpControllers[i], i)),
        ),
        const SizedBox(height: 12),
        if (!_resendAvailable)
          Text("Resend OTP in $_secondsLeft sec",
              style: const TextStyle(color: Colors.white70)),
        if (_resendAvailable)
          TextButton(
            onPressed: _sendOTP,
            child: const Text(
              "Resend OTP",
              style:
                  TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
          ),
          child:
              const Text("Verify OTP", style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }

  // INPUT FIELD
  Widget _input(TextEditingController c, String lbl, IconData ic,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: lbl,
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: Icon(ic, color: Colors.amber),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: (v) => v!.isEmpty ? "Enter $lbl" : null,
    );
  }

  // PASSWORD FIELD
  Widget _passwordField(TextEditingController c, String lbl) {
    return TextFormField(
      controller: c,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: lbl,
        prefixIcon: Icon(Icons.lock, color: Colors.amber),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: (v) => v!.isEmpty ? "Enter $lbl" : null,
    );
  }

  // SIGNUP
  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_otpVerified) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Verify phone first")));
      return;
    }

    if (!_agree) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Accept Terms")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uname = _username.text.trim();

      final q = await _firestore
          .collection('users')
          .where('username', isEqualTo: uname)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) throw "Username already taken";

      final userCred = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      final user = userCred.user!;
      await user.sendEmailVerification();

      await _firestore.collection("users").doc(user.uid).set({
        "name": _name.text.trim(),
        "username": uname,
        "phoneNumber": _phone.text.trim(),
        "email": _email.text.trim(),
        "aadharNumber": _aadhar.text.trim(),
        "address": _address.text.trim(),
        "state": _state.text.trim(),
        "country": _country.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
        "emailVerified": false,
        "phoneVerified": true,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(user: user),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Signup failed: $e")));
    }

    setState(() => _isLoading = false);
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A0404), Color(0xFF7A1E1E), Color(0xFFF5DEB3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // LOGO
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFD4AF37),
                        Color(0xFFB8860B),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.temple_hindu_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Aranpani",
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37),
                  ),
                ),

                const SizedBox(height: 32),

                // FORM CONTAINER
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _input(_name, "Full Name", Icons.person_outline),
                        const SizedBox(height: 16),

                        _input(_username, "Username", Icons.alternate_email),
                        const SizedBox(height: 16),

                        // PHONE + SEND OTP
                        if (!_otpVerified)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _phone,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    labelText: "Phone Number",
                                    labelStyle:
                                        const TextStyle(color: Colors.white),
                                    prefixIcon: const Icon(
                                      Icons.phone_outlined,
                                      color: Colors.amber,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                  ),
                                  onChanged: (v) => setState(() {}),
                                  validator: (v) => v!.length != 10
                                      ? "Enter valid number"
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (_phone.text.length == 10 && !_otpVisible)
                                Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade600,
                                        Colors.deepOrange.shade700
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _otpSending ? null : _sendOTP,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: _otpSending
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            "Send OTP",
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                  ),
                                ),
                            ],
                          ),

                        if (_otpVisible && !_otpVerified) _otpUI(),

                        if (_otpVerified)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Phone Number ${_phone.text} ✔ Verified",
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),

                        _input(
                          _email,
                          "Email",
                          Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        _input(
                          _aadhar,
                          "Aadhar Number",
                          Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        _input(_address, "Address", Icons.home_outlined),
                        const SizedBox(height: 16),

                        _input(
                          _state,
                          "State",
                          Icons.location_city_outlined,
                        ),
                        const SizedBox(height: 16),

                        _input(
                          _country,
                          "Country",
                          Icons.public_outlined,
                        ),
                        const SizedBox(height: 16),

                        _passwordField(_password, "Password"),
                        const SizedBox(height: 16),

                        _passwordField(_confirm, "Confirm Password"),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Checkbox(
                              value: _agree,
                              onChanged: (v) =>
                                  setState(() => _agree = v ?? false),
                            ),
                            Expanded(
                              child: Text(
                                "I agree to Terms & Conditions",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _signup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.amber.shade600,
                                          Colors.deepOrange.shade700
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Create Account",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
