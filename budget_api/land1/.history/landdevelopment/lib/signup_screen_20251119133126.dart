// lib/screens/signup_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'verify_email_screen.dart'; // adjust path if your file is elsewhere

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // controllers
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

  // OTP controllers (6 boxes)
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  // state flags
  bool _agree = false;
  bool _isLoading = false; // for overall create account
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // phone / otp state
  String? _verificationId;
  bool _isSendingOtp = false;
  bool _resendAvailable = false;
  int _resendTimer = 30;
  Timer? _resendTimerTicker;
  bool _phoneVerified = false;
  bool _phoneLocked = false;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.removeListener(_onPhoneChanged);
    _phone.dispose();
    _email.dispose();
    _aadhar.dispose();
    _address.dispose();
    _state.dispose();
    _country.dispose();
    _password.dispose();
    _confirm.dispose();
    for (var c in _otpControllers) c.dispose();
    _resendTimerTicker?.cancel();
    super.dispose();
  }

  // ------------------------
  // Utility: availability checks
  // ------------------------
  Future<bool> _usernameAvailable(String username) async {
    final q = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim().toLowerCase())
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  Future<bool> _phoneAvailable(String phone) async {
    final q = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phone.trim())
        .limit(1)
        .get();
    return q.docs.isEmpty;
  }

  Future<bool> _emailAvailable(String email) async {
    final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
    return methods.isEmpty;
  }

  void _showSnackbar(String text, {Color bg = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ------------------------
  // Phone number listener: when reaches 10 digits -> send OTP
  // ------------------------
  void _onPhoneChanged() {
    final phone = _phone.text.trim();
    if (!_phoneVerified &&
        phone.length == 10 &&
        RegExp(r'^\d{10}$').hasMatch(phone) &&
        !_isSendingOtp) {
      // auto-send OTP
      _startSendOtp();
    }
    // if user clears phone after verified, optionally unlock - but per requirement we lock after verified
  }

  // ------------------------
  // Send OTP
  // ------------------------
  Future<void> _startSendOtp() async {
    final phone = _phone.text.trim();
    if (!_isValidIndianPhone(phone)) return;
    setState(() {
      _isSendingOtp = true;
      _resendAvailable = false;
      _resendTimer = 30;
    });

    // start resend countdown
    _resendTimerTicker?.cancel();
    _resendTimerTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _resendAvailable = true;
          t.cancel();
        }
      });
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (rare). We sign in user with credential and treat as verified.
          try {
            await _auth.signInWithCredential(credential);
            // phone is verified & signed in
            if (!mounted) return;
            setState(() {
              _phoneVerified = true;
              _phoneLocked = true;
            });
            _clearOtpBoxes();
            _showSnackbar('Phone auto-verified', bg: Colors.green);
          } catch (e) {
            // ignore; user can enter OTP manually
          } finally {
            setState(() => _isSendingOtp = false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isSendingOtp = false);
          _showSnackbar('OTP send failed: ${e.message}');
        },
        codeSent: (verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isSendingOtp = false;
            // OTP boxes visible now
          });
          _showSnackbar('OTP sent', bg: Colors.green);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
          setState(() => _isSendingOtp = false);
        },
      );
    } catch (e) {
      setState(() => _isSendingOtp = false);
      _showSnackbar('Failed to send OTP: $e');
    }
  }

  bool _isValidIndianPhone(String p) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(p.trim());

  // ------------------------
  // Resend OTP handler
  // ------------------------
  void _resendOtp() {
    if (!_resendAvailable) return;
    _startSendOtp();
  }

  // ------------------------
  // OTP verification
  // ------------------------
  Future<void> _verifyOtpInline() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showSnackbar('Enter valid 6-digit OTP!');
      return;
    }
    if (_verificationId == null) {
      _showSnackbar('Verification not started. Try again.');
      return;
    }

    setState(() => _isSendingOtp = true);
    final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!, smsCode: otp);

    try {
      // Sign in with phone credential — this will create/sign-in the phone user
      final userCred = await _auth.signInWithCredential(cred);
      final user = userCred.user;
      if (user == null) throw 'Phone verification failed';

      // mark verified and lock phone input
      setState(() {
        _phoneVerified = true;
        _phoneLocked = true;
      });

      _clearOtpBoxes();
      _showSnackbar('Phone verified', bg: Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnackbar('OTP verification failed: ${e.message}');
    } catch (e) {
      _showSnackbar('OTP verification failed: $e');
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  void _clearOtpBoxes() {
    for (var c in _otpControllers) c.clear();
  }

  // ------------------------
  // Create account — called on pressing "Create Account"
  // This will:
  // 1) validate form
  // 2) check username availability (Firestore)
  // 3) check phone availability (Firestore)
  // 4) check email availability (Auth)
  // 5) link email/password to current phone signed-in user
  // 6) write user doc in Firestore
  // 7) send email verification and navigate
  // ------------------------
  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agree) {
      _showSnackbar('Please accept the Terms & Conditions', bg: Colors.orange);
      return;
    }
    if (!_phoneVerified) {
      _showSnackbar('Please verify your phone number first.');
      return;
    }

    setState(() => _isLoading = true);

    final uname = _username.text.trim().toLowerCase();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final pwd = _password.text.trim();

    try {
      // username check
      if (!await _usernameAvailable(uname)) throw 'Username already taken';

      // phone check (maybe there's existing user in users collection)
      final phoneFree = await _phoneAvailable(phone);
      if (!phoneFree) throw 'Phone number already registered';

      // email check using Firebase Auth
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) throw 'Email already in use';

      // must have a current user after phone sign-in
      final current = _auth.currentUser;
      if (current == null) {
        throw 'Phone not signed in - please verify again';
      }

      // link email/password to the current phone user
      final emailCred =
          EmailAuthProvider.credential(email: email, password: pwd);
      try {
        await current.linkWithCredential(emailCred);
      } on FirebaseAuthException catch (e) {
        // linking failed
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          throw 'Email already associated with another account';
        }
        rethrow;
      }

      // send email verification
      await current.sendEmailVerification();

      // write Firestore user document
      final doc = {
        'name': _name.text.trim(),
        'username': uname,
        'phoneNumber': phone,
        'email': email,
        'aadharNumber': _aadhar.text.trim(),
        'address': _address.text.trim(),
        'state': _state.text.trim(),
        'country': _country.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'phoneVerified': true,
      };

      await _firestore.collection('users').doc(current.uid).set(doc);

      // Done — navigate to VerifyEmailScreen (so user can verify email)
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(user: current)),
      );
    } catch (e) {
      _showSnackbar('Signup failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------
  // Build UI
  // ------------------------
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
          child: LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _logoBlock(),
                      const SizedBox(height: 32),
                      _formContainer(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _logoBlock() {
    return Column(
      children: [
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
                  size: 60, color: Colors.white)),
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
      ],
    );
  }

  Widget _formContainer() {
    return Container(
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
            _input(_name, 'Full Name', Icons.person_outline),
            const SizedBox(height: 16),
            _input(_username, 'Username', Icons.alternate_email),
            const SizedBox(height: 16),
            _phoneField(), // phone + inline OTP + verified tick
            const SizedBox(height: 16),
            _input(_email, 'Email', Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _input(_aadhar, 'Aadhaar Number', Icons.badge_outlined,
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            _input(_address, 'Residential Address', Icons.home_outlined),
            const SizedBox(height: 16),
            _input(_state, 'State', Icons.location_city_outlined),
            const SizedBox(height: 16),
            _input(_country, 'Country', Icons.public_outlined),
            const SizedBox(height: 16),
            _passwordInput(
                _password,
                'Password',
                _obscurePassword,
                (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                () => setState(() => _obscurePassword = !_obscurePassword)),
            const SizedBox(height: 16),
            _passwordInput(
                _confirm,
                'Confirm Password',
                _obscureConfirm,
                (v) => v != _password.text ? 'Passwords do not match' : null,
                () => setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 24),
            Row(
              children: [
                Checkbox(
                    value: _agree,
                    onChanged: (v) => setState(() => _agree = v ?? false),
                    activeColor: Colors.amber.shade400),
                Expanded(
                    child: Text('I agree to the Terms & Conditions',
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14))),
              ],
            ),
            const SizedBox(height: 24),
            _isLoading
                ? _loadingBtn()
                : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _phoneVerified
                          ? _createAccount
                          : () => _showSnackbar('Please verify phone first'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
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
                        child: Container(
                          alignment: Alignment.center,
                          child: Text('Create Account',
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ------------------------
  // Phone field + OTP UI
  // ------------------------
  Widget _phoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone TextField with tick suffix
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          enabled: !_phoneLocked,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            labelText: 'Phone Number',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
            prefixIcon:
                Icon(Icons.phone_outlined, color: Colors.amber.shade200),
            suffixIcon: _phoneVerified
                ? Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: const Icon(Icons.check_circle, color: Colors.green))
                : _isSendingOtp
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)))
                    : null,
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
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter Phone Number';
            if (!_isValidIndianPhone(v.trim()))
              return 'Enter valid 10-digit phone';
            return null;
          },
        ),

        const SizedBox(height: 12),

        // Show OTP row only if we have a verificationId and phone is not yet verified
        if (_verificationId != null && !_phoneVerified) _buildOtpArea(),
      ],
    );
  }

  Widget _buildOtpArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Enter OTP', style: GoogleFonts.poppins(color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) => _otpBox(i)),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _resendAvailable
                ? TextButton(
                    onPressed: _resendOtp,
                    child: Text('Resend OTP',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFFD4AF37))))
                : Text('Resend in $_resendTimer sec',
                    style: GoogleFonts.poppins(color: Colors.white70)),
            const SizedBox(width: 18),
            ElevatedButton(
              onPressed: _isSendingOtp ? null : _verifyOtpInline,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Verify OTP',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: _otpControllers[index],
          autofocus: index == 0,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(fontSize: 20, color: Colors.white),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
          ),
          onChanged: (v) {
            if (v.isNotEmpty && index < 5) {
              FocusScope.of(context).nextFocus();
            }
            if (v.isEmpty && index > 0) {
              FocusScope.of(context).previousFocus();
            }
          },
        ),
      ),
    );
  }

  // ------------------------
  // small helper widgets
  // ------------------------
  Widget _loadingBtn() => Container(
        height: 56,
        decoration: BoxDecoration(
            color: Colors.amber.shade400.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14)),
        child:
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

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
            borderSide: BorderSide(
                color: Colors.amber.shade200.withOpacity(0.6), width: 0.8)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade400, width: 1.5)),
      ),
      validator: (v) => v == null || v.trim().isEmpty ? 'Enter $lbl' : null,
    );
  }

  Widget _passwordInput(TextEditingController c, String lbl, bool obs,
      FormFieldValidator<String> validator, VoidCallback toggle) {
    return TextFormField(
      controller: c,
      obscureText: obs,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        labelText: lbl,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
        prefixIcon: Icon(Icons.lock_outline, color: Colors.amber.shade200),
        suffixIcon: IconButton(
            icon: Icon(obs ? Icons.visibility_off : Icons.visibility,
                color: Colors.amber.shade200),
            onPressed: toggle),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Colors.amber.shade200.withOpacity(0.6), width: 0.8)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.amber.shade400, width: 1.5)),
      ),
    );
  }
}
