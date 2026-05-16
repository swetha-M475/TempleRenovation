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
// IMPORT FOR NOTIFICATION PART
import '../screens/notifications_screen.dart'; 

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
      try {
        await _auth.signOut();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e'), backgroundColor: const Color(0xFFB71C1C)),
        );
      }
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
        content: Text('Are you sure you want to delete this plan? This action cannot be undone.',
            style: GoogleFonts.poppins(color: const Color(0xFF3E2723))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await _firestore.collection('projects').doc(_project!['id']).delete();
      setState(() => _project = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Color(0xFFFFFDF5), body: Center(child: CircularProgressIndicator(color: Color(0xFF5D4037))));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text("Error: $_error")));
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
              _header(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
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
                    );
                  },
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

  // HEADER WITH NOTIFICATION ICON
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF5D4037)),
              child: const Icon(Icons.temple_hindu_rounded, color: Color(0xFFFFFDF5), size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aranpani', style: GoogleFonts.cinzelDecorative(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
                Text('Welcome', style: GoogleFonts.poppins(color: const Color(0xFF8D6E63), fontSize: 12)),
              ],
            ),
          ]),
          Row(
            children: [
              _notificationIcon(), // THE NOTIFICATION BELL
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF5D4037).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.menu, color: Color(0xFF5D4037)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NOTIFICATION ICON LOGIC
  Widget _notificationIcon() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF5D4037), size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            if (count > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: const Color(0xFFB71C1C), borderRadius: BorderRadius.circular(10)),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bottomNavBar() {
    final safeIndex = (_currentIndex < 0 || _currentIndex > 1) ? 0 : _currentIndex;
    return Container(
      decoration: const BoxDecoration(color: Color(0xFFFFFDF5), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFFFFFDF5),
        elevation: 0,
        currentIndex: safeIndex,
        selectedItemColor: const Color(0xFF5D4037),
        unselectedItemColor: const Color(0xFFBCAA9B),
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) _openProfile();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFEFE6D5), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF5D4037)),
            child: const Icon(Icons.person, color: Color(0xFFFFFDF5), size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF8D6E63))),
              Text(_userData?['name'] ?? 'User', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _projectHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Your Project', style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF5D4037).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(_project == null ? '0 Projects' : '1 Project', style: GoogleFonts.poppins(color: const Color(0xFF5D4037), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _createProjectButton() {
    final hasProject = _project != null;
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: Text(hasProject ? "Plan already proposed" : "Propose a plan", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasProject ? const Color(0xFFBCAA9B) : const Color(0xFF5D4037),
          foregroundColor: const Color(0xFFFFFDF5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: hasProject ? null : _navigateToCreateProject,
      ),
    );
  }

  Widget _projectSection() {
    if (_project == null) return _noProjectsView();
    final project = _project!;
    final progress = (project['progress'] ?? 0).toDouble();
    final isApproved = project['isSanctioned'] == true || project['status'] == 'approved';

    return Column(
      children: [
        InkWell(
          onTap: () => isApproved ? _openProject(project) : ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your plan is under review.'))),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEFE6D5))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project['place'] ?? 'Unnamed', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(isApproved ? 'Status: Approved' : 'Status: Pending Approval', style: TextStyle(color: isApproved ? Colors.green : Colors.orange)),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress / 100, backgroundColor: const Color(0xFFF5E6CA), color: const Color(0xFF5D4037)),
                const SizedBox(height: 8),
                Text('Progress: ${progress.toStringAsFixed(0)}%'),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: _deleteProject, icon: const Icon(Icons.delete_outline, color: Color(0xFFB71C1C)), label: Text('Delete plan', style: TextStyle(color: Color(0xFFB71C1C)))),
        ),
      ],
    );
  }

  Widget _noProjectsView() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: const Color(0xFFEFE6D5).withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome_mosaic_rounded, size: 44, color: Color(0xFFBCAA9B)),
          const SizedBox(height: 14),
          Text('No projects yet', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      child: Container(
        color: const Color(0xFFFFFDF5),
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFFF5E6CA)),
                accountName: Text(_userData?['name'] ?? 'User', style: const TextStyle(color: Colors.black)),
                accountEmail: Text(_userData?['email'] ?? '', style: const TextStyle(color: Colors.black54)),
                currentAccountPicture: CircleAvatar(backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null),
              ),
              ListTile(leading: const Icon(Icons.logout), title: const Text("Logout"), onTap: _logout),
            ],
          ),
        ),
      ),
    );
  }
}