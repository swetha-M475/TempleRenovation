// lib/screens/welcome_screen.dart
// THEME APPLIED SMARTLY BASED ON EXISTING DESIGN + LOCKED LOGIN DESIGN
// LOGIC / FLOW / DATA — UNCHANGED
// ONLY COLORS, BACKGROUND, CONTRAST ADJUSTED (BOXES FIXED & VISIBLE)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/create_project_screen.dart';
import '../screens/profile_screen.dart';
import 'splash_screen.dart';
import '../screens/project_overview_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _project;
  bool _loading = true;
  String? _error;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndProjects();
  }

  Future<void> _loadUserAndProjects() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
        return;
      }

      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      final projectDocs = await _firestore
          .collection('projects')
          .where('userId', isEqualTo: user.uid)
          .orderBy('dateCreated', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic>? project;
      if (projectDocs.docs.isNotEmpty) {
        final d = projectDocs.docs.first;
        project = {'id': d.id, ...d.data()};
      }

      setState(() {
        _userData = userDoc.data() ?? {'name': 'User', 'email': user.email};
        _project = project;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text("Error: $_error")));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFF7E8), // LOCKED LIGHT BACKGROUND
      drawer: _buildDrawer(),
      bottomNavigationBar: _bottomNavBar(),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _welcomeCard(),
                    const SizedBox(height: 26),
                    _projectHeader(),
                    const SizedBox(height: 14),
                    _createProjectButton(),
                    const SizedBox(height: 18),
                    _projectSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HEADER
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFB8962E)],
                  ),
                ),
                child: const Icon(Icons.temple_hindu_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aranpani',
                    style: GoogleFonts.cinzelDecorative(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6D1B1B),
                    ),
                  ),
                  Text(
                    'Welcome',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu, color: Color(0xFF6D1B1B)),
          ),
        ],
      ),
    );
  }

  // BOTTOM NAV
  Widget _bottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF6D1B1B),
      unselectedItemColor: Colors.black54,
      selectedLabelStyle:
          GoogleFonts.poppins(fontWeight: FontWeight.w600),
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }

  // WELCOME CARD (BOX FIXED – SOLID BACKGROUND)
  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // IMPORTANT: solid, not transparent
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFD4AF37),
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back',
                  style: GoogleFonts.poppins(fontSize: 14)),
              Text(
                _userData?['name'] ?? 'User',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6D1B1B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projectHeader() {
    return Text(
      'Your Project',
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF6D1B1B),
      ),
    );
  }

  // CREATE BUTTON (LOCKED THEME COLOR)
  Widget _createProjectButton() {
    final hasProject = _project != null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: hasProject
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateProjectScreen()),
                ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasProject ? Colors.grey : const Color(0xFF7A1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          hasProject ? 'Plan already proposed' : 'Propose a plan',
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // PROJECT CARD (BOX FIXED)
  Widget _projectSection() {
    if (_project == null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37)),
        ),
        child: Center(
          child: Text(
            'No projects yet',
            style: GoogleFonts.poppins(
                fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Text(
        _project!['place'] ?? 'Unnamed place',
        style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  // DRAWER (LIGHT & CLEAR)
  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFD4AF37),
              child: Icon(Icons.person, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            Text(_userData?['name'] ?? 'User',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _auth.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
