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
        content: Text('Are you sure you want to delete this plan?', style: GoogleFonts.poppins(color: const Color(0xFF3E2723))),
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
              ),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(photoUrl),
      bottomNavigationBar: _bottomNavBar(),
    );
  }

  // --- UI COMPONENTS ---

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
              _notificationIcon(), // Notification Bell
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
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF5D4037), size: 28),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen())),
            ),
            if (count > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
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
      decoration: BoxDecoration(color: const Color(0xFFEFE6D5), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Color(0xFF5D4037), child: Icon(Icons.person, color: Color(0xFFFFFDF5))),
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
        Text(_project == null ? '0 Projects' : '1 Project', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF5D4037))),
      ],
    );
  }

  Widget _createProjectButton() {
    bool hasProject = _project != null;
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_circle_outline),
        label: Text(hasProject ? "Plan already proposed" : "Propose a plan"),
        style: ElevatedButton.styleFrom(backgroundColor: hasProject ? const Color(0xFFBCAA9B) : const Color(0xFF5D4037), foregroundColor: Colors.white),
        onPressed: hasProject ? null : _navigateToCreateProject,
      ),
    );
  }

  Widget _projectSection() {
    if (_project == null) return _noProjectsView();
    final project = _project!;
    final isSanctioned = project['isSanctioned'] == true;
    final status = (project['status'] ?? 'pending') as String;

    return Column(
      children: [
        InkWell(
          onTap: () => (isSanctioned || status == 'approved') ? _openProject(project) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEFE6D5))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project['place'] ?? 'Unnamed place', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(isSanctioned || status == 'approved' ? 'Status: Approved' : 'Status: Pending Approval',
                    style: TextStyle(color: isSanctioned || status == 'approved' ? Colors.green : Colors.orange)),
              ],
            ),
          ),
        ),
        TextButton.icon(onPressed: _deleteProject, icon: const Icon(Icons.delete, color: Colors.red), label: const Text("Delete Plan", style: TextStyle(color: Colors.red)))
      ],
    );
  }

  Widget _noProjectsView() {
    return Center(child: Text("No projects yet", style: GoogleFonts.cinzel(color: const Color(0xFF5D4037))));
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            backgroundColor: const Color(0xFFF5E6CA),
            accountName: Text(_userData?['name'] ?? 'User', style: TextStyle(color: Colors.black)),
            accountEmail: Text(_userData?['email'] ?? '', style: TextStyle(color: Colors.black54)),
            currentAccountPicture: CircleAvatar(backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null),
          ),
          ListTile(leading: const Icon(Icons.logout), title: const Text("Logout"), onTap: _logout),
        ],
      ),
    );
  }
}

// --- NOTIFICATION SCREEN ---

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFDF5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5D4037)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('NOTIFICATIONS', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("No notifications"));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              bool isRead = data['isRead'] ?? false;
              return Card(
                color: isRead ? Colors.white : const Color(0xFFF5E6CA).withOpacity(0.5),
                child: ListTile(
                  title: Text(data['title'] ?? 'Admin Message', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(data['message'] ?? ''),
                  onTap: () => FirebaseFirestore.instance.collection('notifications').doc(docs[index].id).update({'isRead': true}),
                ),
              );
            },
          );
        },
      ),
    );
  }
}