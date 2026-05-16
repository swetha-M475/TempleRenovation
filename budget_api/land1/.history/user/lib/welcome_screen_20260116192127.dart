import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/create_project_screen.dart';
import '../screens/profile_screen.dart';
import 'splash_screen.dart';
import '../screens/project_overview_screen.dart';
import '../screens/user_completed_project_screen.dart';
import '../screens/all_completed_works_screen.dart'; 

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
  bool _loadingUser = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _redirectToSplash();
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _userData = userDoc.data() ?? <String, dynamic>{'name': 'User', 'email': user.email};
          _loadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  void _redirectToSplash() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  void _navigateToCreateProject() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateProjectScreen()),
    );
  }

  // Navigation to the separate Completed Projects part
  void _navigateToCompletedWorks() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllCompletedWorksScreen()),
    );
  }

  void _handleProjectTap(Map<String, dynamic> project) {
    final status = (project['status'] ?? 'pending').toString().toLowerCase();

    if (status == 'approved' || status == 'ongoing') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectOverviewScreen(project: project),
        ),
      );
    } else if (status == 'completed') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserCompletedProjectScreen(project: project),
        ),
      );
    } else if (status == 'rejected') {
      _showRejectedDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your plan is currently under review.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: const Color(0xFF5D4037),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Project Rejected',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: Colors.red[900])),
        content: Text('Your proposal was not accepted. You can delete and retry.',
          style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _deleteProject(String projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF5),
        title: Text('Delete plan', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037))),
        content: const Text('This action cannot be undone.'),
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
      await _firestore.collection('projects').doc(projectId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFDF5),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF5D4037))),
      );
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
                      _buildActiveProjectLogicSection(), // Only shows Non-Completed projects
                      const SizedBox(height: 80),
                    ],
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8962E)]),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: ClipOval(child: Image.asset('assets/images/shiva.png', fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aranpani',
                    style: GoogleFonts.cinzelDecorative(
                        fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
                Text('Welcome', style: GoogleFonts.poppins(color: const Color(0xFF8D6E63), fontSize: 12)),
              ],
            ),
          ]),
          // TOP RIGHT ICONS
          Row(
            children: [
              // 1. Separate Icon for Completed Works
              IconButton(
                onPressed: _navigateToCompletedWorks,
                icon: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF5D4037), size: 28),
                tooltip: 'View Completed Projects',
              ),
              // 2. Menu Icon
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu, color: Color(0xFF5D4037)),
              ),
            ],
          ),
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
          const CircleAvatar(backgroundColor: Color(0xFF5D4037), child: Icon(Icons.person, color: Colors.white)),
          const SizedBox(width: 14),
          Text(
            'Welcome back, ${_userData?['name'] ?? 'User'}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF3E2723)),
          ),
        ],
      ),
    );
  }

  Widget _projectHeader() {
    return Text('Active Proposal',
        style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723)));
  }

  Widget _buildActiveProjectLogicSection() {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('projects')
          .where('userId', isEqualTo: user.uid)
          .orderBy('dateCreated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Logic: Move "completed" projects out of this list
        final allDocs = snapshot.data?.docs ?? [];
        final activeDocs = allDocs.where((doc) {
          final status = (doc['status'] ?? '').toString().toLowerCase();
          return status != 'completed'; // Filter out completed ones
        }).toList();

        final bool hasActive = activeDocs.isNotEmpty;
        Map<String, dynamic>? projectData;

        if (hasActive) {
          final doc = activeDocs.first;
          projectData = {
            'id': doc.id,
            'projectId': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }

        // User can propose if no projects exist OR if the existing project is rejected
        // Note: Completed projects are no longer "Active", so they don't block new proposals
        return Column(
          children: [
            _createProjectButton(!hasActive),
            const SizedBox(height: 18),
            if (hasActive)
              _projectSection(projectData!)
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("No active projects found.", style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _createProjectButton(bool canPropose) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: Text(canPropose ? "Propose a plan" : "Plan Under Process"),
        style: ElevatedButton.styleFrom(
          backgroundColor: canPropose ? const Color(0xFF5D4037) : Colors.grey[400],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: canPropose ? _navigateToCreateProject : null,
      ),
    );
  }

  Widget _projectSection(Map<String, dynamic> project) {
    final String status = (project['status'] ?? 'pending').toString().toLowerCase();

    Color statusColor = Colors.orange.shade800;
    Color bgColor = Colors.orange.shade50;

    if (status == 'rejected') {
      statusColor = Colors.red.shade800;
      bgColor = Colors.red.shade50;
    } else if (status == 'approved' || status == 'ongoing') {
      statusColor = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    }

    return InkWell(
      onTap: () => _handleProjectTap(project),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                  child: Text(status.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                ),
                Text(project['projectId'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            Text(project['place'] ?? 'Unnamed Temple',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))),
            const Divider(height: 30),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF5D4037)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFFFFFDF5),
      currentIndex: _currentIndex,
      selectedItemColor: const Color(0xFF5D4037),
      onTap: (index) {
        if (index == 1) _openProfile();
        setState(() => _currentIndex = index);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }

  Future<void> _openProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    _loadUserData();
    setState(() => _currentIndex = 0);
  }

  Future<void> _logout() async {
    await _auth.signOut();
    _redirectToSplash();
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFF5E6CA)),
            accountName: Text(_userData?['name'] ?? 'User', style: const TextStyle(color: Color(0xFF3E2723))),
            accountEmail: Text(_userData?['email'] ?? '', style: const TextStyle(color: Color(0xFF3E2723))),
            currentAccountPicture: CircleAvatar(
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person) : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in_rounded),
            title: const Text('Completed Projects'),
            onTap: () {
              Navigator.pop(context);
              _navigateToCompletedWorks();
            },
          ),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _logout),
        ],
      ),
    );
  }
}