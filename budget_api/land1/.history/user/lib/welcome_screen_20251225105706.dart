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

  // --- FIELD-READY HIGH CONTRAST COLORS ---
  final Color fieldBg = Colors.white; 
  final Color fieldText = const Color(0xFF000000); // Pure black for text
  final Color fieldSubText = const Color(0xFF444444); 
  final Color actionColor = const Color(0xFFFF5722); // Deep Orange (High Visibility)
  final Color headerColor = const Color(0xFF3E2723); // Dark Brown
  final Color borderColor = const Color(0xFFCCCCCC);

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
      final projectDocs = await _firestore.collection('projects').where('userId', isEqualTo: user.uid).orderBy('dateCreated', descending: true).limit(1).get(); 

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
    if (_loading) return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Colors.black)));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: fieldBg,
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        title: Text('ARANPANI', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 30),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info - Simple & Bold
              Text("NAME: ${_userData?['name']?.toUpperCase() ?? 'USER'}", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fieldText)),
              const Divider(thickness: 2, color: Colors.black),
              const SizedBox(height: 20),
              
              _createProjectButton(),
              
              const SizedBox(height: 30),
              Text("CURRENT PROJECT STATUS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: fieldSubText, letterSpacing: 1)),
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

  Widget _createProjectButton() {
    final hasProject = _project != null;
    return SizedBox(
      width: double.infinity,
      height: 70, // Extra large for easy clicking
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasProject ? Colors.grey[300] : actionColor,
          foregroundColor: hasProject ? Colors.black54 : Colors.white,
          side: const BorderSide(color: Colors.black, width: 2), // Bold outline
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: hasProject ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateProjectScreen())).then((_) => _loadUserAndProjects()),
        child: Text(hasProject ? "PLAN ALREADY SUBMITTED" : "CREATE NEW PLAN +", 
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.black)),
      ),
    );
  }

  Widget _projectSection() {
    if (_project == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(border: Border.all(color: borderColor, width: 2)),
        child: const Text("NO PROJECTS FOUND", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }

    final project = _project!;
    final progress = (project['progress'] ?? 0).toDouble();
    final isApproved = project['isSanctioned'] == true || project['status'] == 'approved';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 3), // Very thick border for sunlight
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("LOCATION: ${project['place']?.toUpperCase() ?? 'N/A'}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.black)),
          Text("DISTRICT: ${project['district']?.toUpperCase() ?? 'N/A'}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          Container(
            color: isApproved ? Colors.green : Colors.orange[100],
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(isApproved ? Icons.verified : Icons.pending, color: isApproved ? Colors.white : Colors.black),
                const SizedBox(width: 10),
                Text(isApproved ? "STATUS: APPROVED" : "STATUS: PENDING", 
                  style: TextStyle(fontWeight: FontWeight.black, color: isApproved ? Colors.white : Colors.black, fontSize: 18)),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Text("WORK PROGRESS:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 20,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(isApproved ? Colors.green : actionColor),
          ),
          Text("${progress.toInt()}% COMPLETE", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.black)),
          
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: isApproved ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectOverviewScreen(project: project))) : null,
              child: const Text("OPEN DETAILS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: actionColor,
      unselectedItemColor: Colors.black,
      currentIndex: _currentIndex,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadUserAndProjects());
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home, size: 35), label: 'HOME'),
        BottomNavigationBarItem(icon: Icon(Icons.person, size: 35), label: 'PROFILE'),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            color: headerColor,
            width: double.infinity,
            child: const Icon(Icons.account_circle, size: 80, color: Colors.white),
          ),
          ListTile(
            title: const Text("LOGOUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
            },
          )
        ],
      ),
    );
  }
}