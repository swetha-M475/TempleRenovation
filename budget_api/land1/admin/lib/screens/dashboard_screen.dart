import 'package:flutter/material.dart';
import 'district_places_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int activeTab = 0; // 0: Projects, 1: Users
  String searchQuery = '';
  bool showNotifications = false;

  List<Map<String, dynamic>> districts = [];
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  StreamSubscription? _projectsSubscription;
  StreamSubscription? _usersSubscription;

  // Store snapshots to combine them effectively
  QuerySnapshot? _lastProjectsSnap;
  QuerySnapshot? _lastUsersSnap;

  @override
  void initState() {
    super.initState();
    _startRealTimeListeners();
  }

  @override
  void dispose() {
    _projectsSubscription?.cancel();
    _usersSubscription?.cancel();
    super.dispose();
  }

  void _startRealTimeListeners() {
    setState(() => isLoading = true);

    // Listen to Projects
    _projectsSubscription = FirebaseFirestore.instance
        .collection('projects')
        .snapshots()
        .listen((projectsSnap) {
      _lastProjectsSnap = projectsSnap;
      if (_lastUsersSnap != null) {
        _processData(_lastProjectsSnap!, _lastUsersSnap!);
      }
    });

    // Listen to Users
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((usersSnap) {
      _lastUsersSnap = usersSnap;
      if (_lastProjectsSnap != null) {
        _processData(_lastProjectsSnap!, _lastUsersSnap!);
      } else {
        // If projects haven't loaded yet, we still want to show users
        _fetchProjectsOnceAndProcess(usersSnap);
      }
    });
  }

  // Fallback if one stream fires before the other
  Future<void> _fetchProjectsOnceAndProcess(QuerySnapshot usersSnap) async {
    final projectsSnap = await FirebaseFirestore.instance.collection('projects').get();
    _processData(projectsSnap, usersSnap);
  }

  void _processData(QuerySnapshot projectsSnap, QuerySnapshot usersSnap) {
    try {
      final Set<String> idsWithOngoing = {};
      final Set<String> idsWithProposals = {};
      final Map<String, Map<String, dynamic>> byDistrict = {};

      // 1. Process Projects
      for (final doc in projectsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String status = (data['status'] ?? 'pending').toString().toLowerCase();
        
        // REMOVE REJECTED FROM UI ENTIRELY
        if (status == 'rejected') continue;

        final String dName = (data['district'] ?? '').toString().trim();
        final String uId = (data['userId'] ?? '').toString().trim();
        final bool isSanctioned = data['isSanctioned'] == true;

        if (uId.isNotEmpty) {
          idsWithProposals.add(uId);
          if (isSanctioned || status == 'ongoing') {
            idsWithOngoing.add(uId);
          }
        }

        if (dName.isEmpty || dName.toLowerCase() == 'null') continue;

        final entry = byDistrict.putIfAbsent(dName, () {
          return <String, dynamic>{
            'id': dName,
            'name': dName,
            'places': 0,
            'newRequests': 0,
            '_placeSet': <String>{},
          };
        });

        final placeName = (data['place'] ?? '').toString();
        if (placeName.isNotEmpty) {
          (entry['_placeSet'] as Set<String>).add(placeName);
          entry['places'] = (entry['_placeSet'] as Set<String>).length;
        }

        if (!isSanctioned && status == 'pending') {
          entry['newRequests'] = (entry['newRequests'] as int) + 1;
        }
      }

      // 2. Process Users
      final List<Map<String, dynamic>> allUsers = usersSnap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final String currentUserId = doc.id;
        
        String sanitize(dynamic value) {
          if (value == null) return 'Not Assigned';
          String valStr = value.toString().trim();
          if (valStr.isEmpty || valStr.toLowerCase() == 'null') return 'Not Assigned';
          return valStr;
        }

        return {
          'id': currentUserId,
          'name': data['name'] ?? data['contactName'] ?? 'Unknown User',
          'phone': data['phone'] ?? data['phoneNumber'] ?? 'N/A',
          'district': sanitize(data['district']),
          'taluk': sanitize(data['taluk']),
          'isOngoing': idsWithOngoing.contains(currentUserId),
          'hasProposal': idsWithProposals.contains(currentUserId),
        };
      }).toList();

      allUsers.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));

      if (mounted) {
        setState(() {
          districts = byDistrict.values.toList();
          districts.sort((a, b) {
            int countA = a['newRequests'] as int;
            int countB = b['newRequests'] as int;
            if (countB != countA) return countB.compareTo(countA);
            return a['name'].toString().compareTo(b['name'].toString());
          });

          users = allUsers;
          isLoading = false;
          notifications = [{'id': '1', 'message': 'Sync Complete', 'time': 'Live', 'read': false}];
        });
      }
    } catch (e) {
      debugPrint('Error processing data: $e');
    }
  }

  int get unreadCount => notifications.where((n) => n['read'] == false).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7E8),
      endDrawer: _buildNotificationsDrawer(),
      body: Builder(
        builder: (innerContext) {
          return Column(
            children: [
              _buildHeader(innerContext),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF6D1B1B)))
                    : Column(
                        children: [
                          _buildSearchBar(),
                          Expanded(child: activeTab == 0 ? _buildDistrictsList() : _buildUsersList()),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF6D1B1B), Color(0xFF4A1010)]),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Color(0xFFFFF4D6)), 
                        onPressed: _showAdminMenu
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Dashboard', style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Real-time Monitoring', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  _buildNotificationIcon(context),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTab('Projects', Icons.location_on, 0)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTab('Users', Icons.people, 1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications, color: Color(0xFFFFF4D6)),
          onPressed: () => Scaffold.of(context).openEndDrawer(),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text('$unreadCount', style: const TextStyle(color: Color(0xFF6D1B1B), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: activeTab == 0 ? 'Search districts...' : 'Search name or phone...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6D1B1B)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          
        ),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isActive = activeTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        activeTab = index;
        searchQuery = '';
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? const Color(0xFF6D1B1B) : Colors.white),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isActive ? const Color(0xFF6D1B1B) : Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildDistrictsList() {
    final filtered = districts.where((d) => d['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final district = filtered[index];
        final int newReq = district['newRequests'];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DistrictPlacesScreen(districtId: district['id']))),
            title: Text(district['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${district['places']} Places'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (newReq > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF6D1B1B), borderRadius: BorderRadius.circular(8)),
                    child: Text('$newReq NEW', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    final filtered = users.where((u) => u['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final user = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(user['phone']),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmRemoveUser(user),
            ),
          ),
        );
      },
    );
  }

  void _confirmRemoveUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(user['id']).delete();
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 100,
            color: const Color(0xFF6D1B1B),
            alignment: Alignment.center,
            child: const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(notifications[index]['message']),
                subtitle: Text(notifications[index]['time']),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              // FIXED: Changed from onPressed to onTap
              onTap: () {
                Navigator.pop(context);
                // Add Logout Logic Here
              },
            ),
          ],
        ),
      ),
    );
  }
}