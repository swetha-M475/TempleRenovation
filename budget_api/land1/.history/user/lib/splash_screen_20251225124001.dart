// splash_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // EXACT COLORS FROM YOUR WELCOME SCREEN
  static const Color ivory = Color(0xFFFFFDF5);
  static const Color sandalwood = Color(0xFFF5E6CA);
  static const Color darkBrown = Color(0xFF5D4037);
  static const Color primaryGold = Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Check login status after animation
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // Using the exact gradient from your WelcomeScreen body
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ivory, sandalwood],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // CIRCULAR LOGO WITH GOLD BORDER
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [primaryGold, Color(0xFFB8962E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4), // Border thickness
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/shiva.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // APP TITLE IN DARK BROWN (Matches Aranpani text color)
                Text(
                  'Aranpani',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: darkBrown,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                // SUBTITLE
                Text(
                  'RENOVATING SHIVA IDOLS',
                  style: GoogleFonts.poppins(
                    color: darkBrown.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 80),
                // LOADING INDICATOR IN DARK BROWN (Matches your WelcomeScreen loader)
                const CircularProgressIndicator(
                  color: darkBrown,
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}