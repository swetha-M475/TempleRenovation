import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
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

  // Controllers
  final TextEditingController _name = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _aadhar = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _state = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());

  // UI State
  bool _isLoading = false;
  bool _isOtpSent = false;
  String _selectedMethod = 'SMS'; // SMS (via 2Factor) or WhatsApp (Manual)
  String _sessionId = "";
  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  // COLORS
  final Color _accentColor = const Color(0xFF5D4037);

  // --- STEP 1: SEND OTP ---
  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    if (_selectedMethod == 'SMS') {
      // USE 2FACTOR FOR SMS
      try {
        final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/+91${_phone.text.trim()}/AUTOGEN/OTPSMS"));
        final data = jsonDecode(res.body);
        if (data["Status"] == "Success") {
          _sessionId = data["Details"];
          setState(() => _isOtpSent = true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Sent via SMS")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SMS Error: $e")));
      }
    } else {
      // MANUAL WHATSAPP REDIRECT
      final String whatsappUrl = "https://wa.me/91XXXXXXXXXX?text=Hi, I am ${_name.text}. Send me OTP for phone ${_phone.text}";
      if (await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication)) {
        setState(() => _isOtpSent = true); // Allow them to enter the code you give them on WA
      }
    }
    setState(() => _isLoading = false);
  }

  // --- STEP 2: VERIFY AND SAVE ---
  Future<void> _verifyAndSignup() async {
    String otp = _otpControllers.map((e) => e.text).join();
    if (otp.length < 6) return;

    setState(() => _isLoading = true);
    try {
      bool isVerified = false;

      if (_selectedMethod == 'SMS') {
        final res = await http.get(Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$_sessionId/$otp"));
        if (jsonDecode(res.body)["Status"] == "Success") isVerified = true;
      } else {
        // For WhatsApp Manual, you can implement a logic or just verify a static code for testing
        if (otp == "123456") isVerified = true; 
      }

      if (isVerified) {
        UserCredential user = await _auth.createUserWithEmailAndPassword(
          email: "${_username.text.trim()}@aranpani.com", 
          password: _password.text.trim()
        );
        
        await _firestore.collection('users').doc(user.user!.uid).set({
          'name': _name.text, 'phone': _phone.text, 'aadhar': _aadhar.text,
          'address': _address.text, 'username': _username.text, 'verified': true
        });

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("Aranpani Signup", style: GoogleFonts.cinzelDecorative(fontSize: 28, fontWeight: FontWeight.bold, color: _accentColor)),
              const SizedBox(height: 30),
              
              // Standard Fields (Only editable if OTP not sent yet)
              _input(_name, "Full Name", Icons.person, enabled: !_isOtpSent),
              _input(_username, "Username", Icons.alternate_email, enabled: !_isOtpSent),
              _input(_phone, "Phone Number", Icons.phone, type: TextInputType.phone, enabled: !_isOtpSent),
              _input(_aadhar, "Aadhar Number", Icons.badge, type: TextInputType.number, enabled: !_isOtpSent),
              _input(_password, "Password", Icons.lock, obscure: true, enabled: !_isOtpSent),

              const SizedBox(height: 20),
              if (!_isOtpSent) ...[
                const Text("Select OTP Method:"),
                Row(
                  children: [
                    Expanded(child: RadioListTile(title: const Text("SMS"), value: "SMS", groupValue: _selectedMethod, onChanged: (v) => setState(() => _selectedMethod = v.toString()))),
                    Expanded(child: RadioListTile(title: const Text("WhatsApp"), value: "WA", groupValue: _selectedMethod, onChanged: (v) => setState(() => _selectedMethod = v.toString()))),
                  ],
                ),
                const SizedBox(height: 20),
                _isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleSendOtp,
                      style: ElevatedButton.styleFrom(backgroundColor: _accentColor, minimumSize: const Size(double.infinity, 50)),
                      child: Text(_selectedMethod == 'SMS' ? "GET OTP VIA SMS" : "VERIFY VIA WHATSAPP"),
                    ),
              ],

              // OTP Section (Appears below the form once "Get OTP" is clicked)
              if (_isOtpSent) ...[
                const Divider(height: 50),
                Text("Enter 6-digit code received via $_selectedMethod", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (i) => _otpBox(i))),
                const SizedBox(height: 30),
                _isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verifyAndSignup,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, minimumSize: const Size(double.infinity, 55)),
                      child: const Text("VERIFY & COMPLETE REGISTRATION", style: TextStyle(color: Colors.white)),
                    ),
                TextButton(onPressed: () => setState(() => _isOtpSent = false), child: const Text("Edit Details / Resend"))
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {bool obscure = false, TextInputType type = TextInputType.text, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: c, obscureText: obscure, keyboardType: type, enabled: enabled,
        decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, color: _accentColor), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 40,
      child: TextField(
        controller: _otpControllers[i], keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 1,
        decoration: const InputDecoration(counterText: "", border: OutlineInputBorder()),
        onChanged: (v) { if (v.length == 1 && i < 5) FocusScope.of(context).nextFocus(); },
      ),
    );
  }
}