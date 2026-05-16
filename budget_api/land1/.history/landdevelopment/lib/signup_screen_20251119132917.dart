// lib/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/otp_service.dart';
import './screens/signup_preview_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
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

  bool _agree = false;
  bool _otpVisible = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;

  String _sessionId = "";
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  @override
  void dispose() {
    for (var c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------- SEND OTP -----------------
  Future<void> _sendOtp() async {
    final phone = _phone.text.trim();

    if (phone.length != 10) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter valid phone number")));
      return;
    }

    setState(() => _sendingOtp = true);

    final result = await OTPService.sendOTP(phone);

    setState(() => _sendingOtp = false);

    if (result["status"] == "Success") {
      setState(() {
        _otpVisible = true;
        _sessionId = result["sessionId"];
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("OTP sending failed")));
    }
  }

  // ---------------- VERIFY OTP -----------------
  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter 6 digit OTP")));
      return;
    }

    bool success = await OTPService.verifyOTP(_sessionId, otp);

    if (success) {
      setState(() => _otpVerified = true);

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Phone Verified")));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Incorrect OTP")));
    }
  }

  // ---------------- GO TO PREVIEW -----------------
  Future<void> _goToPreview() async {
    if (!_otpVerified) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Verify phone first")));
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (!_agree) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Accept terms")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignupPreviewScreen(
          fullName: _name.text.trim(),
          username: _username.text.trim(),
          phoneNumber: _phone.text.trim(),
          email: _email.text.trim(),
          aadhar: _aadhar.text.trim(),
          address: _address.text.trim(),
          state: _state.text.trim(),
          country: _country.text.trim(),
          password: _password.text.trim(),
        ),
      ),
    );
  }

  // ---------------- OTP BOX -----------------
  Widget _otpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _otpControllers[index],
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade200),
          ),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }

  // ----------------------------------------------------
  // ---------------------- UI --------------------------
  // ----------------------------------------------------

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
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // -----------------------------------------
                  // PHONE NUMBER + SEND OTP BUTTON INSIDE
                  // -----------------------------------------
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          counterText: "",
                          labelText: "Phone Number",
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
                          prefixIcon: Icon(Icons.phone_outlined,
                              color: Colors.amber.shade200),
                          suffixIcon: _otpVerified
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green, size: 28)
                              : null,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Colors.amber.shade200.withOpacity(0.6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.amber.shade400, width: 1.5),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.length != 10 ? "Enter valid phone" : null,
                      ),

                      // ---- GOLD BORDER SEND OTP BUTTON ----
                      if (!_otpVerified)
                        Positioned(
                          right: 8,
                          child: GestureDetector(
                            onTap: _sendingOtp ? null : _sendOtp,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.amber.shade400),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.black.withOpacity(0.2),
                              ),
                              child: Text(
                                _sendingOtp ? "..." : "Send OTP",
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ---------------- OTP BOXES -----------------
                  if (_otpVisible && !_otpVerified)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (i) => _otpBox(i)),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade600,
                          ),
                          child: const Text("Verify OTP",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // ----------- OTHER INPUT FIELDS --------------

                  _input(_name, "Full Name", Icons.person),
                  const SizedBox(height: 16),
                  _input(_username, "Username", Icons.alternate_email),
                  const SizedBox(height: 16),
                  _input(_email, "Email", Icons.email),
                  const SizedBox(height: 16),
                  _input(_aadhar, "Aadhaar", Icons.badge),
                  const SizedBox(height: 16),
                  _input(_address, "Address", Icons.home),
                  const SizedBox(height: 16),
                  _input(_state, "State", Icons.location_city),
                  const SizedBox(height: 16),
                  _input(_country, "Country", Icons.public),
                  const SizedBox(height: 16),

                  _passwordInput(_password, "Password"),
                  const SizedBox(height: 16),
                  _passwordInput(_confirm, "Confirm Password"),

                  const SizedBox(height: 20),

                  CheckboxListTile(
                    title: const Text("I agree to Terms & Conditions",
                        style: TextStyle(color: Colors.white)),
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                    activeColor: Colors.amber.shade400,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  ElevatedButton(
                    onPressed: _otpVerified ? _goToPreview : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 80),
                    ),
                    child: const Text("Next",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // INPUT FIELD REUSE
  Widget _input(TextEditingController c, String lbl, IconData ic) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: lbl,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
        prefixIcon: Icon(ic, color: Colors.amber.shade200),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.amber.shade200.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.amber.shade400, width: 1.5),
        ),
      ),
      validator: (v) =>
          v == null || v.isEmpty ? "Enter $lbl" : null,
    );
  }

  Widget _passwordInput(TextEditingController c, String lbl) {
    return TextFormField(
      controller: c,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: lbl,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
        prefixIcon: Icon(Icons.lock, color: Colors.amber.shade200),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.amber.shade200.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.amber.shade400, width: 1.5),
        ),
      ),
      validator: (v) =>
          v == null || v.isEmpty ? "Enter $lbl" : null,
    );
  }
}
