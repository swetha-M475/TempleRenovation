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

  // Default selection set to SMS as requested to be added
  String _selectedMethod = 'SMS';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Confirm Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: templeMaroon,
        foregroundColor: creamyGoldText,
        elevation: 0,
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
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title("Review your details before verifying"),
                const SizedBox(height: 20),
                _info("Full Name", widget.fullName),
                _info("Username", widget.username),
                _info("Phone Number", "+91 ${widget.phoneNumber}"),
                _info("Email", widget.email),
                _info("Aadhaar Number", widget.aadhar),
                _info("Address", widget.address),
                _info("State", widget.state),
                _info("Country", widget.country),
                
                const SizedBox(height: 25),
                
                // --- OTP METHOD SELECTION (SMS vs PHONE) ---
                Text(
                  "Choose Verification Method:",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: creamyGoldText,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _methodTile("SMS", Icons.sms_rounded)),
                    const SizedBox(width: 15),
                    Expanded(child: _methodTile("Phone", Icons.phone_android_rounded)),
                  ],
                ),

                const SizedBox(height: 35),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14), // Smooth Organic
                            side: BorderSide(color: deepGold.withOpacity(0.5)),
                          ),
                        ),
                        child: Text("Back",
                            style: GoogleFonts.poppins(
                              color: creamyGoldText,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
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
                                otpMethod: _selectedMethod, // SMS or Phone
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deepGold,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14), // Smooth Organic
                          ),
                        ),
                        child: Text("Proceed",
                            style: GoogleFonts.poppins(
                              color: darkMaroonText,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                  ],
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
          border: Border.all(
            color: isSelected ? deepGold : creamyGoldText.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: deepGold.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Column(
          children: [
            Icon(
              icon, 
              size: 24, 
              color: isSelected ? darkMaroonText : creamyGoldText
            ),
            const SizedBox(height: 8),
            Text(
              method,
              style: GoogleFonts.poppins(
                color: isSelected ? darkMaroonText : creamyGoldText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: deepGold,
      ),
    );
  }

  Widget _info(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: deepGold.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(14), // Smooth Organic
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: creamyGoldText.withOpacity(0.7))),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    );
  }
}