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
  Map<String, dynamic>? _project; // single latest project
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
        backgroundColor: const Color(0xFFFFFDF5), // Ivory background
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
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)), // Muted Sacred Red
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
            backgroundColor: const Color(0xFFB71C1C),
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
        backgroundColor: const Color(0xFFFFFDF5),
        title: Text('Delete plan', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037))),
        content: Text(
          'Are you sure you want to delete this plan? This action cannot be undone.',
          style: GoogleFonts.poppins(color: const Color(0xFF3E2723)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF8D6E63))),
          ),
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
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: const Color(0xFFB71C1C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Color(0xFFFFFDF5),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF5D4037))));
    }
    if (_error != null) {
      return Scaffold(
          backgroundColor: const Color(0xFFFFFDF5),
          body: Center(child: Text("Error: $_error", style: const TextStyle(color: Color(0xFF3E2723)))));
    }

    final photoUrl = _userData?['photoUrl'] as String?;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFDF5), // Ivory background for daylight visibility
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFDF5), // Ivory
              Color(0xFFF5E6CA), // Sandalwood Beige
            ],
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
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
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

  // UPDATED HEADER WITH NOTIFICATION ICON
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5D4037), // Bronze/Deep Sandalwood
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.temple_hindu_rounded,
                  color: Color(0xFFFFFDF5), size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aranpani',
                    style: GoogleFonts.cinzelDecorative(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5D4037))),
                Text('Welcome',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF8D6E63), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ]),
          // Top Right Icons Row
          Row(
            children: [
              _notificationIcon(), // Added Notification Bell
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.menu, color: Color(0xFF5D4037)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NOTIFICATION ICON WITH BADGE
  Widget _notificationIcon() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser?.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF5D4037), size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationScreen()),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // BOTTOM NAV
  Widget _bottomNavBar() {
    final safeIndex =
        (_currentIndex < 0 || _currentIndex > 1) ? 0 : _currentIndex;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: const Color(0xFFFFFDF5),
        elevation: 0,
        currentIndex: safeIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF5D4037), // Bronze
        unselectedItemColor: const Color(0xFFBCAA9B),
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(),
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            _openProfile();
          }
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
        color: const Color(0xFFEFE6D5), // Light Sandalwood
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF5D4037),
            ),
            child: const Icon(Icons.person, color: Color(0xFFFFFDF5), size: 28),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,',
                  style:
                      GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF8D6E63))),
              Text(_userData?['name'] ?? 'User',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E2723))),
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
            style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3E2723))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF5D4037).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _project == null ? '0 Projects' : '1 Project',
            style: GoogleFonts.poppins(
                color: const Color(0xFF5D4037), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // CREATE BUTTON
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
              hasProject ? const Color(0xFFBCAA9B) : const Color(0xFF5D4037),
          foregroundColor: const Color(0xFFFFFDF5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: hasProject ? null : _navigateToCreateProject,
      ),
    );
  }

  // MAIN PROJECT SECTION
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
                  backgroundColor: Color(0xFF5D4037),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
              border: Border.all(color: const Color(0xFFEFE6D5)),
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
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3E2723),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (project['district'] ?? '') as String,
                      style: GoogleFonts.poppins(color: const Color(0xFF8D6E63)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isSanctioned || status == 'approved'
                      ? 'Status: Approved'
                      : 'Status: Pending admin approval',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSanctioned || status == 'approved'
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (progress / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF5E6CA),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 100 ? const Color(0xFF2E7D32) : const Color(0xFF5D4037),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Progress: ${progress.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    color:
                        progress == 100 ? const Color(0xFF2E7D32) : const Color(0xFF3E2723),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _deleteProject,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFB71C1C)),
            label: Text(
              'Delete plan',
              style: GoogleFonts.poppins(color: const Color(0xFFB71C1C), fontWeight: FontWeight.w500),
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
        color: const Color(0xFFEFE6D5).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFE6D5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
                color: Color(0xFFFFFDF5), shape: BoxShape.circle),
            child: Icon(Icons.auto_awesome_mosaic_rounded,
                size: 44, color: const Color(0xFFBCAA9B)),
          ),
          const SizedBox(height: 14),
          Text('No projects yet',
              style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D4037))),
          const SizedBox(height: 8),
          Text('Create your first project to get started',
              style: GoogleFonts.poppins(color: const Color(0xFF8D6E63)),
              textAlign: TextAlign.center),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5E6CA),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF5D4037),
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl) as ImageProvider
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(Icons.person,
                              color: Color(0xFFFFFDF5), size: 30)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_userData?['name'] ?? 'User',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF3E2723),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(_userData?['email'] ?? '',
                              style: GoogleFonts.poppins(
                                  color: const Color(0xFF8D6E63), fontSize: 12)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Color(0xFF5D4037)),
                title: Text('Profile',
                    style: GoogleFonts.poppins(color: const Color(0xFF3E2723))),
                onTap: () {
                  Navigator.pop(context);
                  _openProfile();
                },
              ),
              const Spacer(),
              const Divider(color: Color(0xFFEFE6D5)),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFFB71C1C)),
                title: Text('Logout',
                    style: GoogleFonts.poppins(color: const Color(0xFFB71C1C))),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// SIMPLE NOTIFICATION LIST SCREEN
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFDF5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5D4037)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('NOTIFICATIONS', 
          style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No notifications yet", style: GoogleFonts.poppins()));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;

              return Card(
                color: isRead ? Colors.white : const Color(0xFFF5E6CA).withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFFEFE6D5)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(data['title'] ?? 'Update', 
                    style: GoogleFonts.poppins(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(data['message'] ?? '', style: GoogleFonts.poppins()),
                  trailing: !isRead ? const CircleAvatar(radius: 4, backgroundColor: Colors.red) : null,
                  onTap: () {
                    FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notifications[index].id)
                        .update({'isRead': true});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}