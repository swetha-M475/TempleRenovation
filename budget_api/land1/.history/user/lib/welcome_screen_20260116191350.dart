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

  // Theme Colors
  final Color primaryBrown = const Color(0xFF5D4037);
  final Color darkBrown = const Color(0xFF3E2723);
  final Color accentGold = const Color(0xFFD4AF37);
  final Color bgCream = const Color(0xFFFFFDF5);

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

  void _handleProjectTap(Map<String, dynamic> project) {
    final status = (project['status'] ?? 'pending').toString().toLowerCase();

    if (status == 'approved' || status == 'ongoing') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProjectOverviewScreen(project: project)),
      );
    } else if (status == 'completed') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserCompletedProjectScreen(project: project)),
      );
    } else if (status == 'rejected') {
      _showRejectedDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plan is under review. Access dashboard once sanctioned.', style: GoogleFonts.poppins()),
          backgroundColor: primaryBrown,
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
        title: Text('Project Rejected', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFFB71C1C))),
        content: Text('Proposal not accepted. You can delete and submit a new one.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close', style: TextStyle(color: primaryBrown))),
        ],
      ),
    );
  }

  Future<void> _deleteProject(String projectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgCream,
        title: Text('Delete plan', style: GoogleFonts.cinzel(color: primaryBrown)),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: primaryBrown))),
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
      return Scaffold(
        backgroundColor: bgCream,
        body: Center(child: CircularProgressIndicator(color: primaryBrown)),
      );
    }

    final photoUrl = _userData?['photoUrl'] as String?;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgCream,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgCream, const Color(0xFFF5E6CA)],
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
                      _buildProjectLogicSection(),
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

  Widget _buildProjectLogicSection() {
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
          return Center(child: CircularProgressIndicator(color: primaryBrown));
        }

        final allDocs = snapshot.data?.docs ?? [];
        
        final bool hasActiveProject = allDocs.any((doc) {
          String s = (doc['status'] ?? '').toString().toLowerCase();
          return s != 'completed' && s != 'rejected';
        });

        final currentWorkDoc = allDocs.where((doc) {
          return (doc['status'] ?? '').toString().toLowerCase() != 'completed';
        }).toList();

        return Column(
          children: [
            _createProjectButton(!hasActiveProject),
            const SizedBox(height: 18),
            if (currentWorkDoc.isNotEmpty)
              _projectSection({
                'id': currentWorkDoc.first.id,
                ...currentWorkDoc.first.data() as Map<String, dynamic>,
              })
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("No active plans.", style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        );
      },
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
              width: 54, height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [accentGold, const Color(0xFFB8962E)]),
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
                Text('Aranpani', style: GoogleFonts.cinzelDecorative(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBrown)),
                Text('Welcome', style: GoogleFonts.poppins(color: const Color(0xFF8D6E63), fontSize: 12)),
              ],
            ),
          ]),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Icon(Icons.menu_open_rounded, color: primaryBrown, size: 28),
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
          CircleAvatar(backgroundColor: primaryBrown, child: const Icon(Icons.person_outline, color: Colors.white)),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Namaste, ${_userData?['name'] ?? 'User'}', 
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: darkBrown)),
          ),
        ],
      ),
    );
  }

  Widget _projectHeader() => Text('My Active Proposal', style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: darkBrown));

  Widget _createProjectButton(bool canPropose) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(canPropose ? Icons.add_to_photos_outlined : Icons.lock_clock_outlined, size: 20),
        label: Text(canPropose ? "Propose a plan" : "Work in Progress"),
        style: ElevatedButton.styleFrom(
          backgroundColor: canPropose ? primaryBrown : Colors.grey[400],
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: canPropose ? _navigateToCreateProject : () {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete your ongoing work first.")));
        },
      ),
    );
  }

  Widget _projectSection(Map<String, dynamic> project) {
    final String status = (project['status'] ?? 'pending').toString().toLowerCase();
    Color statusColor = status == 'rejected' ? const Color(0xFFB71C1C) : (status == 'approved' || status == 'ongoing' ? Colors.green[700]! : Colors.orange[800]!);
    
    return InkWell(
      onTap: () => _handleProjectTap(project),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(project['place'] ?? 'Unnamed Temple', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: darkBrown))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("View Project Dashboard", style: GoogleFonts.poppins(fontSize: 13, color: primaryBrown, fontWeight: FontWeight.w500)),
                if (status == 'pending' || status == 'rejected')
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFB71C1C)), 
                    onPressed: () => _deleteProject(project['id'])
                  )
                else
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primaryBrown),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _bottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: bgCream,
      elevation: 10,
      currentIndex: _currentIndex,
      selectedItemColor: primaryBrown,
      unselectedItemColor: Colors.grey[600],
      selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
      onTap: (index) {
        if (index == 1) _openProfile();
        setState(() => _currentIndex = index);
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.temple_hindu_outlined), activeIcon: Icon(Icons.temple_hindu), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), activeIcon: Icon(Icons.account_circle), label: 'Profile'),
      ],
    );
  }

  Future<void> _openProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    _loadUserData();
    setState(() => _currentIndex = 0);
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      backgroundColor: bgCream,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFF5E6CA)),
            accountName: Text(_userData?['name'] ?? 'User', style: TextStyle(color: darkBrown, fontWeight: FontWeight.bold)),
            accountEmail: Text(_userData?['email'] ?? '', style: TextStyle(color: primaryBrown)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: primaryBrown,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
            ),
          ),
          ListTile(
            leading: Icon(Icons.assignment_turned_in_outlined, color: primaryBrown),
            title: Text('Completed Projects', style: GoogleFonts.poppins(color: darkBrown)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCompletedWorksScreen()));
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFB71C1C)), 
            title: Text('Logout', style: GoogleFonts.poppins(color: const Color(0xFFB71C1C), fontWeight: FontWeight.w500)), 
            onTap: _logout
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    _redirectToSplash();
  }
}