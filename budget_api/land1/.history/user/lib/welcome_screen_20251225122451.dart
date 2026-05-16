// lib/screens/welcome_screen.dart
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

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
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
      setState(() => _loading = false);
    }
  }

  void _navigateToCreateProject() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateProjectScreen()),
    );
    if (result == true) _loadUserAndProjects();
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
    _loadUserAndProjects();
    setState(() => _currentIndex = 0);
  }

  // LOGOUT LOGIC
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Logout',
            style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.poppins(color: const Color(0xFF3E2723))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF8D6E63))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    }
  }

  void _openProject(Map<String, dynamic> project) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectOverviewScreen(project: project)),
    );
  }

  Future<void> _deleteProject() async {
    if (_project == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF5),
        title: Text('Delete plan', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('projects').doc(_project!['id']).delete();
      _loadUserAndProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Color(0xFFFFFDF5),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF5D4037))));
    }

    final photoUrl = _userData?['photoUrl'] as String?;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFDF5),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF5), Color(0xFFF5E6CA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(), // TOP NAVIGATION BAR
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
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
      ),
      bottomNavigationBar: _bottomNavBar(),
    );
  }

  // UPDATED HEADER WITH LOGO ON LEFT AND LOGOUT ON RIGHT
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            // BRAND LOGO
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8962E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(child: Image.asset('assets/images/shiva.png', fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aranpani',
                    style: GoogleFonts.cinzelDecorative(
                        fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
                Text('Home',
                    style: GoogleFonts.poppins(color: const Color(0xFF8D6E63), fontSize: 11)),
              ],
            ),
          ]),
          // LOGOUT BUTTON IN TOP RIGHT
          IconButton(
            onPressed: _logout,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFB71C1C), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFFFFFDF5),
      currentIndex: _currentIndex,
      selectedItemColor: const Color(0xFF5D4037),
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) _openProfile();
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE6D5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF5D4037),
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Welcome back, ${_userData?['name'] ?? 'User'}',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))),
          ),
        ],
      ),
    );
  }

  Widget _projectHeader() {
    return Text('Your Project',
        style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723)));
  }

  Widget _createProjectButton() {
    final hasProject = _project != null;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: Text(hasProject ? "Plan already proposed" : "Propose a plan"),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasProject ? const Color(0xFFBCAA9B) : const Color(0xFF5D4037),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: hasProject ? null : _navigateToCreateProject,
      ),
    );
  }

  Widget _projectSection() {
    if (_project == null) return const Center(child: Padding(
      padding: EdgeInsets.only(top: 20),
      child: Text("No plans yet."),
    ));
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        title: Text(_project!['place'] ?? 'Unnamed Plan', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        subtitle: Text('Status: ${_project!['status'] ?? 'Pending'}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: _deleteProject,
        ),
        onTap: () => _openProject(_project!),
      ),
    );
  }
}