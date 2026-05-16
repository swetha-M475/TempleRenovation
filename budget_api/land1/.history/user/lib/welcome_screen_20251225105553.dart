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

  // --- ACCESSIBILITY COLORS FOR SUNLIGHT ---
  final Color bgIvory = const Color(0xFFFFFFFF); // Pure White for max sunlight reflection
  final Color textDeep = const Color(0xFF1A1A1A); // Near Black for readability
  final Color textSubtle = const Color(0xFF4A4A4A); 
  final Color templeSaffron = const Color(0xFFE65100); // Deep Saffron (High Visibility)
  final Color templeBronze = const Color(0xFF5D4037); // Dark Wood/Bronze
  final Color successGreen = const Color(0xFF1B5E20); // Deep Green
  final Color errorRed = const Color(0xFFB71C1C); // Deep Red

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
        if (_currentIndex < 0 || _currentIndex > 1) _currentIndex = 0;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgIvory,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.bold, color: textDeep)),
        content: Text('Are you sure you want to leave?', style: TextStyle(color: textDeep, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('NO', style: TextStyle(color: textSubtle, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: errorRed),
            child: const Text('YES, LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
    }
  }

  void _openProject(Map<String, dynamic> project) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectOverviewScreen(project: project)));
  }

  Future<void> _deleteProject() async {
    if (_project == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: const Text('This will remove your plan permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: errorRed),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _firestore.collection('projects').doc(_project!['id']).delete();
      setState(() => _project = null);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(backgroundColor: bgIvory, body: const Center(child: CircularProgressIndicator()));
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgIvory,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _welcomeCard(),
                      const SizedBox(height: 30),
                      Text('YOUR WORK', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textDeep, letterSpacing: 1.2)),
                      const SizedBox(height: 15),
                      _createProjectButton(),
                      const SizedBox(height: 20),
                      _projectSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(_userData?['photoUrl']),
      bottomNavigationBar: _bottomNavBar(),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
      color: templeBronze,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            const Icon(Icons.temple_hindu, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Text('ARANPANI', style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.menu, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: templeSaffron,
      unselectedItemColor: textSubtle,
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 1) _openProfile();
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home, size: 30), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person, size: 30), label: 'Profile'),
      ],
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // Light Grey for contrast
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: templeSaffron, child: const Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Namaste,', style: TextStyle(fontSize: 16, color: textSubtle)),
              Text(_userData?['name'] ?? 'User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDeep)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _createProjectButton() {
    final hasProject = _project != null;
    return SizedBox(
      width: double.infinity,
      height: 65, // Taller button for field usage
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle, size: 28),
        label: Text(hasProject ? "PLAN SUBMITTED" : "CREATE NEW PLAN", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasProject ? Colors.grey : templeSaffron,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: hasProject ? null : _navigateToCreateProject,
      ),
    );
  }

  Widget _projectSection() {
    if (_project == null) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No Plans Found", style: TextStyle(fontSize: 18))));
    
    final project = _project!;
    final progress = (project['progress'] ?? 0).toDouble();
    final isApproved = project['isSanctioned'] == true || project['status'] == 'approved';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: templeBronze, width: 2), // Bold border for visibility
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(project['place']?.toUpperCase() ?? 'TEMPLE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDeep)),
          Text(project['district'] ?? '', style: TextStyle(fontSize: 16, color: textSubtle)),
          const Divider(height: 25),
          Row(
            children: [
              Icon(isApproved ? Icons.check_circle : Icons.timer, color: isApproved ? successGreen : templeSaffron),
              const SizedBox(width: 8),
              Text(isApproved ? "APPROVED" : "PENDING", style: TextStyle(fontWeight: FontWeight.bold, color: isApproved ? successGreen : templeSaffron, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 15),
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 12,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(progress == 100 ? successGreen : templeSaffron),
          ),
          const SizedBox(height: 10),
          Text('Progress: ${progress.toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, color: textDeep, fontSize: 16)),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isApproved ? () => _openProject(project) : null,
              style: ElevatedButton.styleFrom(backgroundColor: templeBronze),
              child: const Text("VIEW DETAILS", style: TextStyle(color: Colors.white)),
            ),
          ),
          TextButton.icon(onPressed: _deleteProject, icon: const Icon(Icons.delete, color: Colors.red), label: const Text("Delete Plan", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: templeBronze),
            accountName: Text(_userData?['name'] ?? 'User'),
            accountEmail: Text(_userData?['email'] ?? ''),
            currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: templeBronze, size: 40)),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('PROFILE'),
            onTap: () { Navigator.pop(context); _openProfile(); },
          ),
          const Spacer(),
          ListTile(
            leading: Icon(Icons.logout, color: errorRed),
            title: Text('LOGOUT', style: TextStyle(color: errorRed, fontWeight: FontWeight.bold)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}