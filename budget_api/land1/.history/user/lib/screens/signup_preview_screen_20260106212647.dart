// lib/screens/signup_preview_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'otp_verification_screen.dart';

class SignupPreviewScreen extends StatefulWidget {
  final String fullName;
  final String username;
  final String phoneNumber;
  final String email;
  final String aadhar;
  final String address;
  final String state;
  final String country;
  final String password;

  const SignupPreviewScreen({
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
  State<SignupPreviewScreen> createState() => _SignupPreviewScreenState();
}

class _SignupPreviewScreenState extends State<SignupPreviewScreen> {
  // Color Palette from Template
  final Color templeMaroon = const Color(0xFF6D1B1B);
  final Color deepGold = const Color(0xFFD4AF37);
  final Color sacredCream = const Color(0xFFFFF7E8);
  final Color darkMaroonText = const Color(0xFF4A1010);
  final Color creamyGoldText = const Color(0xFFFFF4D6);

  String _selectedMethod = 'SMS'; // Default selection

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Confirm Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: templeMaroon,
        foregroundColor: creamyGoldText,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF4A0404), templeMaroon, sacredCream],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title("Review your details"),
                const SizedBox(height: 20),
                _info("Full Name", widget.fullName),
                _info("Phone Number", "+91 ${widget.phoneNumber}"),
                _info("Email", widget.email),
                const SizedBox(height: 25),
                
                Text("Receive OTP via:", style: GoogleFonts.poppins(color: creamyGoldText, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _methodTile("SMS", Icons.sms_rounded)),
                    const SizedBox(width: 15),
                    Expanded(child: _methodTile("Phone", Icons.phone_android_rounded)),
                  ],
                ),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OTPVerificationScreen(
                            fullName: widget.fullName,
                            username: widget.username,
                            phoneNumber: widget.phoneNumber,
                            email: widget.email,
                            aadhar: widget.aadhar,
                            address: widget.address,
                            state: widget.state,
                            country: widget.country,
                            password: widget.password,
                            otpMethod: _selectedMethod, // PASSING THE CHOICE
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text("PROCEED", style: GoogleFonts.poppins(color: darkMaroonText, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _methodTile(String method, IconData icon) {
    bool isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? deepGold : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? deepGold : creamyGoldText.withOpacity(0.3), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? darkMaroonText : creamyGoldText),
            Text(method, style: GoogleFonts.poppins(color: isSelected ? darkMaroonText : creamyGoldText, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) => Text(text, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: deepGold));

  Widget _info(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: deepGold.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 12, color: creamyGoldText.withOpacity(0.7))),
          Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}