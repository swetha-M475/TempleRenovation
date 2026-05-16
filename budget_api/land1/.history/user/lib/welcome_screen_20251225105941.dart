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

  // --- THEME COLORS ---
  final Color primaryDark = const Color(0xFF1A237E); // Deep Navy
  final Color primaryLight = const Color(0xFF3949AB); // Royal Blue
  final Color accentColor = const Color(0xFF00BCD4); // Cyan Accent
  final Color bgColor = const Color(0xFFF5F7FA);

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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Confirm Logout',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to sign out?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openProject(Map<String, dynamic> project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectOverviewScreen(project: project),
      ),
    );
  }

  Future<void> _deleteProject() async {
    if (_project == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete plan'),
        content: const Text('Are you sure you want to delete this plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final id = _project!['id'] as String;
      await _firestore.collection('projects').doc(id).delete();

      setState(() {
        _project = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: primaryLight)));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text("Error: $_error")));
    }

    final photoUrl = _userData?['photoUrl'] as String?;

    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryDark, primaryLight, const Color(0xFF5C6BC0)],
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
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
                          ],
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [accentColor, const Color(0xFF0097A7)]),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.temple_hindu_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aranpani',
                    style: GoogleFonts.cinzelDecorative(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Welcome', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ]),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.menu, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomNavBar() {
    final safeIndex = (_currentIndex < 0 || _currentIndex > 1) ? 0 : _currentIndex;
    return Container(
      decoration: BoxDecoration(
        color: primaryDark,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: safeIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.white54,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(),
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor.withOpacity(0.2)),
            child: Icon(Icons.person, color: accentColor, size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
              Text(_userData?['name'] ?? 'User',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
        Text('Your Project',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
          child: Text(
            _project == null ? '0 Projects' : '1 Project',
            style: GoogleFonts.poppins(color: accentColor, fontWeight: FontWeight.w600),
          ),
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
        label: Text(
          hasProject ? "Plan already proposed" : "Propose a plan",
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: hasProject ? Colors.white24 : accentColor,
          foregroundColor: Colors.white,
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
    final isSanctioned = project['isSanctioned'] == true;
    final status = (project['status'] ?? 'pending') as String;

    return Column(
      children: [
        InkWell(
          onTap: () {
            if (!isSanctioned && status != 'approved') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Your plan is under review.')),
              );
              return;
            }
            _openProject(project);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        project['place'] ?? 'Unnamed place',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(project['district'] ?? '', style: GoogleFonts.poppins(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isSanctioned || status == 'approved' ? 'Status: Approved' : 'Status: Pending',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isSanctioned || status == 'approved' ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (progress / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 100 ? Colors.greenAccent : accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Progress: ${progress.toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _deleteProject,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: Text('Delete plan', style: GoogleFonts.poppins(color: Colors.redAccent)),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_late_outlined, size: 44, color: Colors.white38),
          const SizedBox(height: 14),
          Text('No projects yet',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: accentColor)),
          Text('Create your first project to get started',
              style: GoogleFonts.poppins(color: Colors.white70), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryDark, primaryLight])),
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.transparent),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                  child: (photoUrl == null || photoUrl.isEmpty) ? Icon(Icons.person, color: primaryDark) : null,
                ),
                accountName: Text(_userData?['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(_userData?['email'] ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white),
                title: const Text('Profile', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _openProfile(); },
              ),
              const Spacer(),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white70),
                title: const Text('Logout', style: TextStyle(color: Colors.white70)),
                onTap: () { Navigator.pop(context); _logout(); },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}