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

  // --- STARK CONTRAST COLORS FOR OUTDOOR USE ---
  final Color sunWhite = const Color(0xFFFFFFFF);
  final Color darkText = const Color(0xFF000000); // Pure Black
  final Color actionSaffron = const Color(0xFFFF6D00); // Deep High-Vis Orange
  final Color templeMaroon = const Color(0xFF800000); // Dark Maroon for headers
  final Color successGreen = const Color(0xFF1B5E20); // Very Dark Green

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
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final projectDocs = await _firestore.collection('projects')
          .where('userId', isEqualTo: user.uid)
          .orderBy('dateCreated', descending: true)
          .limit(1).get(); 

      Map<String, dynamic>? project;
      if (projectDocs.docs.isNotEmpty) {
        final d = projectDocs.docs.first;
        project = {'id': d.id, ...d.data()};
      }

      setState(() {
        _userData = userDoc.data() ?? {'name': 'User', 'email': user.email};
        _project = project;
        _loading = false;
        if (_currentIndex < 0 || _currentIndex > 1) _currentIndex = 0;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: sunWhite, body: const Center(child: CircularProgressIndicator(color: Colors.black)));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: sunWhite, // Best for sunlight
      appBar: AppBar(
        backgroundColor: templeMaroon,
        elevation: 0,
        centerTitle: false,
        title: Text('ARANPANI', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 32),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _welcomeHeader(),
              const SizedBox(height: 30),
              _createProjectButton(),
              const SizedBox(height: 30),
              Text('CURRENT STATUS', style: TextStyle(fontWeight: FontWeight.w900, color: darkText, letterSpacing: 1.5, fontSize: 14)),
              const SizedBox(height: 10),
              _projectSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomNavBar(),
      drawer: _buildDrawer(),
    );
  }

  Widget _welcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("NAMASTE,", style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.bold)),
        Text(_userData?['name']?.toString().toUpperCase() ?? 'USER', 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.black, color: darkText)),
        Container(height: 4, width: 60, color: actionSaffron), // Visual anchor
      ],
    );
  }

  Widget _createProjectButton() {
    final hasProject = _project != null;
    return SizedBox(
      width: double.infinity,
      height: 75, // Massive button for easy tapping
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasProject ? Colors.grey[300] : actionSaffron,
          foregroundColor: hasProject ? Colors.black45 : Colors.white,
          elevation: 0,
          side: BorderSide(color: darkText, width: 2), // Clear edge
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: hasProject ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateProjectScreen())).then((_) => _loadUserAndProjects()),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasProject ? Icons.check_circle : Icons.add_circle, size: 30),
            const SizedBox(width: 15),
            Text(hasProject ? "PLAN SUBMITTED" : "CREATE NEW PLAN", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _projectSection() {
    if (_project == null) {
      return Container(
        padding: const EdgeInsets.all(40),
        width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!, width: 2), borderRadius: BorderRadius.circular(8)),
        child: const Text("NO WORK FOUND\nSTART BY CREATING A PLAN", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, height: 1.5)),
      );
    }

    final project = _project!;
    final progress = (project['progress'] ?? 0).toDouble();
    final isApproved = project['isSanctioned'] == true || project['status'] == 'approved';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sunWhite,
        border: Border.all(color: darkText, width: 3), // Strong frame
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(project['place']?.toString().toUpperCase() ?? 'TEMPLE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.black, color: templeMaroon)),
          Text(project['district']?.toString().toUpperCase() ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const Divider(color: Colors.black, thickness: 1.5, height: 30),
          
          // STATUS BOX
          Container(
            padding: const EdgeInsets.all(12),
            color: isApproved ? successGreen : Colors.yellow[700],
            child: Row(
              children: [
                Icon(isApproved ? Icons.verified : Icons.hourglass_top, color: isApproved ? Colors.white : Colors.black),
                const SizedBox(width: 10),
                Text(isApproved ? "APPROVED" : "WAITING FOR APPROVAL", 
                  style: TextStyle(fontWeight: FontWeight.black, color: isApproved ? Colors.white : Colors.black, fontSize: 16)),
              ],
            ),
          ),
          
          const SizedBox(height: 25),
          Text("WORK PROGRESS: ${progress.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 18,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(isApproved ? successGreen : actionSaffron),
          ),
          
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: darkText, foregroundColor: Colors.white),
              onPressed: isApproved ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectOverviewScreen(project: project))) : null,
              child: const Text("VIEW DETAILS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _deleteProject,
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text("DELETE PLAN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _bottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: actionSaffron,
      unselectedItemColor: darkText,
      currentIndex: _currentIndex,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.black, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadUserAndProjects());
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled, size: 35), label: 'HOME'),
        BottomNavigationBarItem(icon: Icon(Icons.person, size: 35), label: 'PROFILE'),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 150, width: double.infinity, color: templeMaroon,
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(20),
            child: const Text("MENU", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red, size: 30),
            title: const Text("LOGOUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
            onTap: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
            },
          ),
        ],
      ),
    );
  }
  
  // Placeholder for the delete dialog logic - similar to your original code
  Future<void> _deleteProject() async {
    // ... logic for your AlertDialog here ...
  }
}