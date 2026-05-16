// lib/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/otp_service.dart';
import 'verify_email_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
  bool _otpVisible = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;
  String _sessionId = "";
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  void _showSnackbar(String text, {Color bg = Colors.red}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // SEND OTP BUTTON
  Future<void> _sendOtp() async {
    if (_phone.text.length != 10) {
      _showSnackbar("Enter valid 10-digit phone number");
      return;
    }

    setState(() => _sendingOtp = true);

    final result = await OTPService.sendOTP(_phone.text);

    setState(() => _sendingOtp = false);

    if (result["status"] == "Success") {
      setState(() {
        _otpVisible = true;
        _sessionId = result["sessionId"];
      });

      _showSnackbar("OTP sent successfully", bg: Colors.green);
    } else {
      _showSnackbar("OTP sending failed");
    }
  }

  // VERIFY OTP
  Future<void> _verifyOtp() async {
    String otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      _showSnackbar("Enter 6-digit OTP");
      return;
    }

    final success = await OTPService.verifyOTP(_sessionId, otp);

    if (success) {
      setState(() => _otpVerified = true);
      _showSnackbar("Phone Verified ✔", bg: Colors.green);
    } else {
      _showSnackbar("Invalid OTP");
    }
  }

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    super.dispose();
  }

  // GOLD BUTTON STYLING (SEND OTP)
  Widget _sendOtpButton() {
    return GestureDetector(
      onTap: _sendingOtp ? null : _sendOtp,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.4),
        ),
        child: _sendingOtp
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(
                "Send OTP",
                style: GoogleFonts.poppins(
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  // OTP INPUT BOX
  Widget _otpBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _otpControllers[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && index < 5) FocusScope.of(context).nextFocus();
          if (v.isEmpty && index > 0) FocusScope.of(context).previousFocus();
        },
      ),
    );
  }

  // PHONE FIELD WITH SEND OTP BUTTON + TICK
  Widget _phoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            counterText: "",
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            labelText: "Phone Number",
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
            prefixIcon:
                Icon(Icons.phone_outlined, color: Colors.amber.shade200),
            suffixIcon: _otpVerified
                ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                : _sendOtpButton(),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.amber, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // OTP BOXES
        if (_otpVisible && !_otpVerified)
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                ),
                child: Text("Verify OTP",
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
      ],
    );
  }

  // GENERAL INPUT
  Widget _input(TextEditingController c, String lbl, IconData ic,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        labelText: lbl,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
        prefixIcon: Icon(ic, color: Colors.amber.shade200),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.4), width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.amber, width: 1.5)),
      ),
      validator: (v) => v == null || v.trim().isEmpty ? "Enter $lbl" : null,
    );
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
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text("Aranpani",
                      style: GoogleFonts.cinzelDecorative(
                          fontSize: 34,
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),

                  _input(_name, "Full Name", Icons.person),
                  const SizedBox(height: 16),
                  _input(_username, "Username", Icons.alternate_email),
                  const SizedBox(height: 16),
                  _phoneField(),
                  const SizedBox(height: 16),
                  _input(_email, "Email", Icons.email,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _input(_aadhar, "Aadhaar Number", Icons.badge,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  _input(_address, "Address", Icons.home),
                  const SizedBox(height: 16),
                  _input(_state, "State", Icons.location_city),
                  const SizedBox(height: 16),
                  _input(_country, "Country", Icons.public),
                  const SizedBox(height: 20),

                  // NEXT button
                  ElevatedButton(
                    onPressed: _otpVerified ? () {} : null, // later complete
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      disabledBackgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 80, vertical: 14),
                    ),
                    child: const Text("Next",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
