import 'package:flutter/material.dart';
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

enum OtpMode { phone, whatsapp }

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // SACRED COLOR PALETTE
  final Color _primaryBrand = const Color(0xFF6D1B1B);
  final Color _primaryAccent = const Color(0xFFD4AF37);
  final Color _secondaryAccent = const Color(0xFFB8962E);
  final Color _bgColor = const Color(0xFFFFF7E8);
  final Color _inputBg = const Color(0xFFFFFBF2);
  final Color _textOnLight = const Color(0xFF4A1010);
  final Color _textOnDark = const Color(0xFFFFF4D6);

  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _aadhar = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

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

  OtpMode _otpMode = OtpMode.phone;

  static const String apiKey =
      "0b23b35d-c516-11f0-a6b2-0200cd936042";

  @override
  void dispose() {
    for (var c in _otpControllers) c.dispose();
    for (var f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    _aadhar.dispose();
    _address.dispose();
    _state.dispose();
    _country.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = 30;
    _resendAvailable = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _resendAvailable = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _sendOTP() async {
    final phone = _phone.text.trim();
    if (phone.length != 10) return;

    setState(() => _otpSending = true);

    final endpoint = _otpMode == OtpMode.phone
        ? "https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN"
        : "https://2factor.in/API/V1/$apiKey/WHATSAPP/+91$phone/AUTOGEN";

    try {
      final res = await http.get(Uri.parse(endpoint));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["Status"] == "Success") {
          setState(() {
            _otpVisible = true;
            _sessionId = data["Details"];
          });
          _otpFocusNodes[0].requestFocus();
          _startTimer();
        }
      }
    } catch (_) {}

    setState(() => _otpSending = false);
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();

    final endpoint = _otpMode == OtpMode.phone
        ? "https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"
        : "https://2factor.in/API/V1/$apiKey/WHATSAPP/VERIFY/$_sessionId/$otp";

    final res = await http.get(Uri.parse(endpoint));
    if (res.statusCode == 200 &&
        jsonDecode(res.body)["Status"] == "Success") {
      setState(() {
        _otpVerified = true;
        _otpVisible = false;
      });
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text("Aranpani",
                  style: GoogleFonts.cinzelDecorative(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _primaryBrand)),
              const SizedBox(height: 24),
              _phoneSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _phoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _otpModeSelector(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: _fieldDecoration("Phone Number", Icons.phone),
        ),
        const SizedBox(height: 12),
        if (!_otpVerified)
          ElevatedButton(
            onPressed: _otpSending ? null : _sendOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBrand,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text("Send Code"),
          ),
        if (_otpVisible) _otpUI(),
      ],
    );
  }

  Widget _otpModeSelector() {
    return Row(
      children: [
        _otpChoice(OtpMode.phone, "Phone OTP"),
        const SizedBox(width: 12),
        _otpChoice(OtpMode.whatsapp, "WhatsApp Code"),
      ],
    );
  }

  Widget _otpChoice(OtpMode mode, String label) {
    final selected = _otpMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _otpMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _primaryAccent : _inputBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _secondaryAccent),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color:
                        selected ? _textOnDark : _textOnLight,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _otpUI() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
                List.generate(6, (i) => _otpBox(i))),
        TextButton(
            onPressed: _verifyOtp,
            child: Text("Verify Code",
                style: TextStyle(color: _primaryBrand)))
      ],
    );
  }

  Widget _otpBox(int i) {
    return Container(
      width: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _otpControllers[i],
        focusNode: _otpFocusNodes[i],
        maxLength: 1,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: _inputBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) {
            _otpFocusNodes[i + 1].requestFocus();
          }
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(String l, IconData i) {
    return InputDecoration(
      labelText: l,
      prefixIcon: Icon(i, color: _primaryBrand),
      filled: true,
      fillColor: _inputBg,
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
