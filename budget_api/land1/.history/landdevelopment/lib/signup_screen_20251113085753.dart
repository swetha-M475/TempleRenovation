import 'package:flutter/material.dart';
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

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept terms & conditions'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final uname = _username.text.trim();

    try {
      final available = await _usernameAvailable(uname);
      if (!available) throw ('Username already taken');

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
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: user)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signup error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // 🌟 Logo
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

                        // 🌟 Signup Form Container
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.25)),
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
                                _inputField(_name, 'Full Name', Icons.person_outline),
                                const SizedBox(height: 16),
                                _inputField(_username, 'Username',
                                    Icons.alternate_email),
                                const SizedBox(height: 16),
                                _inputField(_phone, 'Phone Number',
                                    Icons.phone_outlined,
                                    keyboardType: TextInputType.phone),
                                const SizedBox(height: 16),
                                _inputField(_email, 'Email', Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: 16),
                                _inputField(_aadhar, 'Aadhaar Number',
                                    Icons.badge_outlined,
                                    keyboardType: TextInputType.number),
                                const SizedBox(height: 16),
                                _inputField(_address, 'Residential Address',
                                    Icons.home_outlined),
                                const SizedBox(height: 16),
                                _inputField(_state, 'State',
                                    Icons.location_city_outlined),
                                const SizedBox(height: 16),
                                _inputField(
                                    _country, 'Country', Icons.public_outlined),
                                const SizedBox(height: 16),

                                _passwordField(
                                    _password,
                                    'Password',
                                    _obscurePassword,
                                    (v) {
                                      if (v == null || v.length < 6) {
                                        return 'Min 6 chars';
                                      }
                                      return null;
                                    },
                                    () => setState(() =>
                                        _obscurePassword = !_obscurePassword)),
                                const SizedBox(height: 16),

                                _passwordField(
                                    _confirm,
                                    'Confirm Password',
                                    _obscureConfirm,
                                    (v) {
                                      if (v == null || v != _password.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                    () => setState(() =>
                                        _obscureConfirm = !_obscureConfirm)),
                                const SizedBox(height: 24),

                                // Terms
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _agree,
                                      onChanged: (v) =>
                                          setState(() => _agree = v ?? false),
                                      activeColor: Colors.amber.shade400,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'I agree to the Terms & Conditions',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Signup Button
                                _isLoading
                                    ? Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade400
                                              .withOpacity(0.6),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              color: Colors.white),
                                        ),
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed: _signup,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14)),
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
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Container(
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Create Account',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
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

  Widget _inputField(TextEditingController controller, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
        prefixIcon: Icon(icon, color: Colors.amber.shade200),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.amber.shade200.withOpacity(0.6), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.amber.shade400, width: 1.5),
        ),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter $label' : null,
    );
  }

  Widget _passwordField(TextEditingController controller, String label, bool obscure,
      FormFieldValidator<String> validator, VoidCallback toggle) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.amber.shade200),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.amber.shade200,
          ),
          onPressed: toggle,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Colors.amber.shade200.withOpacity(0.6), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.amber.shade400, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
