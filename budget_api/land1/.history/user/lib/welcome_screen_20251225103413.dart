// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/create_project_screen.dart';
import '../screens/profile_screen.dart';
import 'splash_screen.dart';
import '../utils/colors.dart';
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

    final photoUrl = _userData?['photoUrl'] as String?;

    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF7E8), // ivory
              Color(0xFFF5E6C8), // sandalwood
              Color(0xFFEAD7B0), // light temple gold
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 12),
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
              ),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(photoUrl),
      bottomNavigationBar: _bottomNavBar(),
    );
  }

  // HEADER
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8962E)],
                ),
              ),
              child: const Icon(Icons.temple_hindu_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aranpani',
                    style: GoogleFonts.cinzelDecorative(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6D1B1B))),
                Text('Welcome',
                    style: GoogleFonts.poppins(
                        color: Colors.black54, fontSize: 12)),
              ],
            ),
          ]),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.menu, color: Color(0xFF6D1B1B)),
            ),
          ),
        ],
      ),
    );
  }

  // BOTTOM NAV
  Widget _bottomNavBar() {
    final safeIndex =
        (_currentIndex < 0 || _currentIndex > 1) ? 0 : _currentIndex;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7E8),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: safeIndex,
        selectedItemColor: const Color(0xFF6D1B1B),
        unselectedItemColor: Colors.black54,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(),
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) _openProfile();
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  // WELCOME CARD
  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4AF37)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8962E)]),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,',
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: Colors.black54)),
              Text(_userData?['name'] ?? 'User',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6D1B1B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projectHeader() {
    return Text('Your Project',
        style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6D1B1B)));
  }

  Widget _createProjectButton() {
    final hasProject = _project != null;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: Text(
          hasProject ? "Plan already proposed" : "Propose a plan",
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasProject ? Colors.grey : const Color(0xFF7A1E1E),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: hasProject ? null : _navigateToCreateProject,
      ),
    );
  }

  // PROJECT SECTION
  Widget _projectSection() {
    if (_project == null) {
      return _noProjectsView();
    }

    final project = _project!;
    final progress = (project['progress'] ?? 0).toDouble();
    final isSanctioned = project['isSanctioned'] == true;
    final status = (project['status'] ?? 'pending') as String;

    return Column(
      children: [
        InkWell(
          onTap: () {
            if (!isSanctioned && status != 'approved') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Your plan is under review. You can open it after admin approves.'),
                ),
              );
              return;
            }
            _openProject(project);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD4AF37)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project['place'] ?? 'Unnamed place',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black)),
                const SizedBox(height: 8),
                Text(
                  isSanctioned || status == 'approved'
                      ? 'Status: Approved'
                      : 'Status: Pending admin approval',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isSanctioned
                          ? Colors.green
                          : Colors.orange),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (progress / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.black12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 100
                        ? Colors.green
                        : const Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Progress: ${progress.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _noProjectsView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37)),
      ),
      child: Column(
        children: [
          Icon(Icons.agriculture,
              size: 44, color: const Color(0xFF6D1B1B)),
          const SizedBox(height: 14),
          Text('No projects yet',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6D1B1B))),
          const SizedBox(height: 8),
          Text('Create your first project to get started',
              style: GoogleFonts.poppins(color: Colors.black54),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      child: Container(
        color: const Color(0xFFFFF7E8),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFD4AF37),
                backgroundImage:
                    (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person,
                        color: Colors.white, size: 30)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(_userData?['name'] ?? 'User',
                  style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              ListTile(
                leading:
                    const Icon(Icons.logout, color: Color(0xFF6D1B1B)),
                title: Text('Logout',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF6D1B1B))),
                onTap: _logout,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
