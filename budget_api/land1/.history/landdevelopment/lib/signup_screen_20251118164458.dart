// lib/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_preview_screen.dart';

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

  bool _agree = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<bool> _usernameAvailable(String username) async {
    final q = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  Future<bool> _phoneAvailable(String phone) async {
    final q = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  Future<void> _goToPreview() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept terms & conditions'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uname = _username.text.trim();
      final phone = _phone.text.trim();

      if (!await _usernameAvailable(uname)) {
        throw ('Username already taken');
      }
      if (!await _phoneAvailable(phone)) {
        throw ('Phone number already registered');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignupPreviewScreen(
            fullName: _name.text.trim(),
            username: uname,
            phoneNumber: phone,
            email: _email.text.trim(),
            aadhar: _aadhar.text.trim(),
            address: _address.text.trim(),
            state: _state.text.trim(),
            country: _country.text.trim(),
            password: _password.text.trim(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    _email.dispose();
    _aadhar.dispose();
    _address.dispose();
    _state.dispose();
    _country.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
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
                            color: const Color(0xFFD4AF37),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _input(
                                    _name, 'Full Name', Icons.person_outline),
                                const SizedBox(height: 16),
                                _input(_username, 'Username',
                                    Icons.alternate_email),
                                const SizedBox(height: 16),
                                _input(_phone, 'Phone Number',
                                    Icons.phone_outlined,
                                    keyboardType: TextInputType.phone),
                                const SizedBox(height: 16),
                                _input(_email, 'Email', Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: 16),
                                _input(_aadhar, 'Aadhaar Number',
                                    Icons.badge_outlined,
                                    keyboardType: TextInputType.number),
                                const SizedBox(height: 16),
                                _input(_address, 'Residential Address',
                                    Icons.home_outlined),
                                const SizedBox(height: 16),
                                _input(_state, 'State',
                                    Icons.location_city_outlined),
                                const SizedBox(height: 16),
                                _input(
                                    _country, 'Country', Icons.public_outlined),
                                const SizedBox(height: 16),
                                _password(
                                    _password,
                                    'Password',
                                    _obscurePassword,
                                    (v) => v == null || v.length < 6
                                        ? 'Min 6 chars'
                                        : null,
                                    () => setState(() =>
                                        _obscurePassword = !_obscurePassword)),
                                const SizedBox(height: 16),
                                _password(
                                    _confirm,
                                    'Confirm Password',
                                    _obscureConfirm,
                                    (v) => v != _password.text
                                        ? 'Passwords do not match'
                                        : null,
                                    () => setState(() =>
                                        _obscureConfirm = !_obscureConfirm)),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Checkbox(
                                        value: _agree,
                                        onChanged: (v) =>
                                            setState(() => _agree = v ?? false),
                                        activeColor: Colors.amber.shade400),
                                    Expanded(
                                        child: Text(
                                            'I agree to the Terms & Conditions',
                                            style: GoogleFonts.poppins(
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                fontSize: 14))),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _isLoading
                                    ? _loadingBtn()
                                    : _mainBtn('Next', _goToPreview),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _loadingBtn() => Container(
      height: 56,
      decoration: BoxDecoration(
          color: Colors.amber.shade400.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14)),
      child:
          const Center(child: CircularProgressIndicator(color: Colors.white)));

  Widget _mainBtn(String text, Function() onTap) => SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: EdgeInsets.zero),
          child: Ink(
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.amber.shade600,
                    Colors.deepOrange.shade700
                  ]),
                  borderRadius: BorderRadius.circular(14)),
              child: Container(
                  alignment: Alignment.center,
                  child: Text(text,
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white))))));

  Widget _input(TextEditingController c, String lbl, IconData ic,
          {TextInputType keyboardType = TextInputType.text}) =>
      TextFormField(
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
                  borderSide: BorderSide(
                      color: Colors.amber.shade200.withOpacity(0.6),
                      width: 0.8)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.amber.shade400, width: 1.5))),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter $lbl' : null);

  Widget _password(TextEditingController c, String lbl, bool obs,
          FormFieldValidator<String> validator, VoidCallback toggle) =>
      TextFormField(
          controller: c,
          obscureText: obs,
          style: const TextStyle(color: Colors.white),
          validator: validator,
          decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              labelText: lbl,
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
              prefixIcon:
                  Icon(Icons.lock_outline, color: Colors.amber.shade200),
              suffixIcon: IconButton(
                  icon: Icon(obs ? Icons.visibility_off : Icons.visibility,
                      color: Colors.amber.shade200),
                  onPressed: toggle),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Colors.amber.shade200.withOpacity(0.6),
                      width: 0.8)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.amber.shade400, width: 1.5))));
}
