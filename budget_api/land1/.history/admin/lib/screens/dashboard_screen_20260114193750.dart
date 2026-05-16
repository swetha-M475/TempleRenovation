import 'package:flutter/material.dart';
import 'district_places_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int activeTab = 0; // 0: Projects, 1: Users
  String searchQuery = '';
  bool showNotifications = false;

  // Real-time notifications (Static for now, but integrated)
  List<Map<String, dynamic>> notifications = [
    {'id': '1', 'message': 'New project request from Ravi Kumar', 'time': '2 hours ago', 'read': false},
    {'id': '2', 'message': 'Bill uploaded for Ongoing Temple', 'time': '1 day ago', 'read': true},
  ];

  int get unreadCount => notifications.where((n) => n['read'] == false).length;

  // Streams for real-time updates
  late Stream<QuerySnapshot> _usersStream;
  late Stream<QuerySnapshot> _projectsStream;

  @override
  void initState() {
    super.initState();
    // Initialize the streams
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
    _projectsStream = FirebaseFirestore.instance.collection('projects').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      endDrawer: _buildNotificationsDrawer(),
      body: Builder(
        builder: (innerContext) {
          return Column(
            children: [
              _buildModernHeader(innerContext),
              _buildSearchAndTabs(),
              Expanded(
                child: activeTab == 1 
                  ? _buildRealTimeUsers() 
                  : _buildRealTimeDistricts(),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- REAL-TIME USERS LIST ---
  Widget _buildRealTimeUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading users"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6D1B1B)));

        final userDocs = snapshot.data!.docs;
        final filteredUsers = userDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery.toLowerCase()) || email.contains(searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index].data() as Map<String, dynamic>;
            user['id'] = filteredUsers[index].id;
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  // --- REAL-TIME DISTRICTS/PROJECTS LIST ---
  Widget _buildRealTimeDistricts() {
    return StreamBuilder<QuerySnapshot>(
      stream: _projectsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading projects"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6D1B1B)));

        // Logic to group projects by district on the fly
        final Map<String, Map<String, dynamic>> byDistrict = {};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final districtName = (data['district'] ?? 'Unknown').toString();
          
          final entry = byDistrict.putIfAbsent(districtName, () => {
            'id': districtName,
            'name': districtName,
            'places': <String>{},
            'newRequests': 0,
          });

          if (data['place'] != null) (entry['places'] as Set).add(data['place']);
          if (data['isSanctioned'] != true) entry['newRequests']++;
        }

        final districtList = byDistrict.values.where((d) => 
          d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: districtList.length,
          itemBuilder: (context, index) {
            final district = districtList[index];
            return _buildDistrictCard(district);
          },
        );
      },
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildModernHeader(BuildContext innerContext) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6D1B1B), Color(0xFF4A1010)]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.menu, color: Color(0xFFFFF4D6)), onPressed: _showAdminMenu),
                      const SizedBox(width: 8),
                      const Text('Admin Portal', style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications, color: Color(0xFFFFF4D6)),
                            onPressed: () => Scaffold.of(innerContext).openEndDrawer(),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 8, top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle),
                                child: Text('$unreadCount', style: const TextStyle(color: Color(0xFF6D1B1B), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndTabs() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: activeTab == 0 ? 'Search Districts...' : 'Search Users...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6D1B1B)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              elevation: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTabButton('Projects', Icons.architecture, 0)),
              const SizedBox(width: 12),
              Expanded(child: _buildTabButton('Users', Icons.people_alt, 1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final isSel = activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFD4AF37) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSel ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictCard(Map<String, dynamic> district) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPlacesScreen(districtId: district['id']))),
        title: Text(district['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('${(district['places'] as Set).length} Areas with projects'),
        trailing: district['newRequests'] > 0 
          ? Badge(label: Text('${district['newRequests']}'), backgroundColor: const Color(0xFF6D1B1B))
          : const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _showUserDetail(user),
        leading: const CircleAvatar(backgroundColor: Color(0xFFFFF7E8), child: Icon(Icons.person, color: Color(0xFF6D1B1B))),
        title: Text(user['name'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user['email'] ?? 'No Email'),
        trailing: const Icon(Icons.more_vert),
      ),
    );
  }

  // --- EXISTING DIALOGS & DRAWERS ---
  
  Drawer _buildNotificationsDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFFFF7E8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF6D1B1B),
            child: const SafeArea(child: Row(children: [Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return ListTile(
                  leading: Icon(Icons.info_outline, color: n['read'] ? Colors.grey : const Color(0xFFD4AF37)),
                  title: Text(n['message'], style: TextStyle(fontWeight: n['read'] ? FontWeight.normal : FontWeight.bold)),
                  onTap: () => setState(() => n['read'] = true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout'), onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  void _showUserDetail(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name']),
        content: Text('Phone: ${user['phoneNumber'] ?? 'N/A'}\nAddress: ${user['address'] ?? 'N/A'}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }
}