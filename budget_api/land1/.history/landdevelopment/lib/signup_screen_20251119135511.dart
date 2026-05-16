import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'verify_email_screen.dart';

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

  // OTP
  List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  bool _otpVisible = false;
  bool _otpVerified = false;
  bool _otpSending = false;
  String _sessionId = "";

  bool _agree = false;
  bool _isLoading = false;

  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  @override
  void initState() {
    super.initState();
  }

  // ❌ Removed auto-send listener
  // ----------------------------------------------------

  Future<void> _sendOTP() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 10-digit phone")),
      );
      return;
    }

    setState(() => _otpSending = true);

    final url =
        Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN");

    final res = await http.get(url);
    setState(() => _otpSending = false);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data["Status"] == "Success") {
        setState(() {
          _otpVisible = true;
          _sessionId = data["Details"];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("OTP Sent"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP Failed")),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid OTP")),
      );
      return;
    }

    final url = Uri.parse(
        "https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp");

    final res = await http.get(url);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data["Status"] == "Success") {
        setState(() => _otpVerified = true);

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
  }

  Future<bool> _usernameAvailable(String username) async {
    final q = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_otpVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verify Phone First")),
      );
      return;
    }

    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Accept Terms")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uname = _username.text.trim();
      if (!await _usernameAvailable(uname)) {
        throw "Username already taken";
      }

      final userCred = await _auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      final user = userCred.user!;
      await user.sendEmailVerification();

      await _firestore.collection('users').doc(user.uid).set({
        'name': _name.text.trim(),
        'username': uname,
        'phoneNumber': _phone.text.trim(),
        'email': _email.text.trim(),
        'aadharNumber': _aadhar.text.trim(),
        'address': _address.text.trim(),
        'state': _state.text.trim(),
        'country': _country.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'phoneVerified': true,
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup failed: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
                const SizedBox(height: 16),

                // LOGO
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.temple_hindu_rounded,
                        size: 60, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Aranpani',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(height: 32),

                // FORM BOX
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

                        _input(_phone, "Phone Number", Icons.phone_outlined,
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 10),

                        // **SEND OTP BUTTON ADDED HERE**
                        if (!_otpVisible)
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: _otpSending ? null : _sendOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                              ),
                              child: _otpSending
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text("Send OTP",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16)),
                            ),
                          ),

                        // OTP AREA
                        if (_otpVisible && !_otpVerified) _otpUI(),
                        if (_otpVerified)
                          const Text("✔ Phone Verified",
                              style: TextStyle(color: Colors.green)),

                        const SizedBox(height: 16),

                        _input(_email, "Email", Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),

                        _input(_aadhar, "Aadhar Number", Icons.badge_outlined,
                            keyboardType: TextInputType.number),
                        const SizedBox(height: 16),

                        _input(_address, "Address", Icons.home_outlined),
                        const SizedBox(height: 16),

                        _input(_state, "State", Icons.location_city_outlined),
                        const SizedBox(height: 16),

                        _input(_country, "Country", Icons.public_outlined),
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
                              child: Text("I agree to Terms & Conditions",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _signup,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [
                                        Colors.amber.shade600,
                                        Colors.deepOrange.shade700
                                      ]),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Create Account",
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 18),
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

  Widget _otpUI() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _otpBox(_otpControllers[i])),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade600,
          ),
          child:
              const Text("Verify OTP", style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }

  Widget _otpBox(TextEditingController c) {
    return Container(
      width: 45,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: c,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String lbl, IconData ic,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: lbl,
        labelStyle: TextStyle(color: Colors.white),
        prefixIcon: Icon(ic, color: Colors.amber),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: (v) => v!.isEmpty ? "Enter $lbl" : null,
    );
  }

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
}
