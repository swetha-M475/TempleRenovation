import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'temple_detail_screen.dart';

class PlaceTemplesScreen extends StatefulWidget {
  final String placeId;

  const PlaceTemplesScreen({
    super.key,
    required this.placeId,
  });

  @override
  State<PlaceTemplesScreen> createState() => _PlaceTemplesScreenState();
}

class _PlaceTemplesScreenState extends State<PlaceTemplesScreen> {
  // --- Aranpani Theme Tokens ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryAccentGold = Color(0xFFD4AF37);
  static const Color secondaryGold = Color(0xFFB8962E);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color softParchment = Color(0xFFFFFBF2);
  static const Color darkMaroonText = Color(0xFF4A1010);
  static const Color lightGoldText = Color(0xFFFFF4D6);

  bool isLoading = true;
  String placeName = '';
  String districtName = '';
  List<Map<String, dynamic>> temples = [];
  int statusTab = 0;
  
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  List<Map<String, dynamic>> get currentList {
    List<Map<String, dynamic>> list;
    if (statusTab == 0) {
      list = temples.where((t) => t['status'] == 'pending').toList();
    } else if (statusTab == 1) {
      list = temples.where((t) => t['status'] == 'ongoing').toList();
    } else {
      list = temples.where((t) => t['status'] == 'completed').toList();
    }

    if (searchQuery.trim().isEmpty) return list;

    final query = searchQuery.toLowerCase().trim();
    return list.where((t) {
      final projectId = (t['projectId'] ?? '').toString().toLowerCase();
      final userName = (t['userName'] ?? '').toString().toLowerCase();
      final localName = (t['localName'] ?? '').toString().toLowerCase();
      
      return projectId.contains(query) || 
             userName.contains(query) || 
             localName.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTemples();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemples() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('taluk', isEqualTo: widget.placeId)
          .get();

      if (!mounted) return;
      placeName = widget.placeId;

      if (snap.docs.isNotEmpty) {
        final firstData = snap.docs.first.data();
        districtName = (firstData['district'] ?? '').toString();
      }

      final Set<String> userIds = {};
      for (final doc in snap.docs) {
        final uid = (doc.data()['userId'] ?? '').toString();
        if (uid.isNotEmpty) userIds.add(uid);
      }

      final Map<String, Map<String, dynamic>> usersById = {};
      if (userIds.isNotEmpty) {
        final List<String> idList = userIds.toList();
        for (var i = 0; i < idList.length; i += 10) {
          final end = (i + 10 < idList.length) ? i + 10 : idList.length;
          final chunk = idList.sublist(i, end);
          final userSnap = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final u in userSnap.docs) {
            usersById[u.id] = u.data();
          }
        }
      }

      temples = snap.docs.map((doc) {
        final data = doc.data();
        final uid = (data['userId'] ?? '').toString();
        final userData = usersById[uid] ?? {};

        final bool isSanctioned = data['isSanctioned'] == true;
        int progress = int.tryParse(data['progress']?.toString() ?? '0') ?? 0;
        final String rawStatus = (data['status'] ?? 'pending').toString().toLowerCase();

        String status;
        if (rawStatus == 'rejected') status = 'rejected';
        else if (!isSanctioned) status = 'pending';
        else if (progress >= 100) status = 'completed';
        else status = 'ongoing';

        // --- FETCHING WORKS ARRAY ---
        final List<dynamic> rawWorks = data['works'] ?? [];
        final List<Map<String, dynamic>> worksList = rawWorks.map((w) => Map<String, dynamic>.from(w)).toList();

        // FIX: Ensuring the correct 4+4+Number ID is fetched. 
        // If data['projectId'] is empty, it falls back to doc.id (which is usually the generated ID)
        String correctProjectId = data['projectId']?.toString() ?? '';
        if (correctProjectId.isEmpty || correctProjectId == 'null') {
          correctProjectId = doc.id;
        }

        return <String, dynamic>{
          'id': doc.id,
          'projectId': correctProjectId, // <--- Correct ID assigned here
          'userId': uid,
          'district': (data['district'] ?? '').toString(),
          'taluk': (data['taluk'] ?? '').toString(),
          'place': (data['place'] ?? '').toString(),
          'status': status,
          'progress': progress,
          'isSanctioned': isSanctioned,
          'userName': (userData['name'] ?? data['contactName'] ?? 'Unknown User').toString(),
          
          // --- FETCHING LOCAL CONTACT INFO ---
          'localName': (data['localPersonName'] ?? 'N/A').toString(),
          'localPhone': (data['localPersonPhone'] ?? 'N/A').toString(),
          
          // --- WORKS LIST ---
          'works': worksList,
          
          'imageUrls': List<String>.from(data['imageUrls'] ?? []),
          'raw': data,
        };
      }).toList();

      temples.removeWhere((t) => t['status'] == 'rejected');
      
    } catch (e) {
      debugPrint('Error loading temples: $e');
      temples = [];
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = temples.where((t) => t['status'] == 'pending').length;
    final ongoingCount = temples.where((t) => t['status'] == 'ongoing').length;
    final completedCount = temples.where((t) => t['status'] == 'completed').length;

    return Scaffold(
      backgroundColor: backgroundCream,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [primaryMaroon, Color(0xFF4A1010)]),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: lightGoldText),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(placeName.isEmpty ? 'Loading...' : placeName,
                                  style: const TextStyle(color: lightGoldText, fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(districtName.isEmpty ? 'Temple Projects' : '$districtName District',
                                  style: const TextStyle(color: primaryAccentGold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      onChanged: (val) => setState(() => searchQuery = val),
                      style: const TextStyle(color: darkMaroonText),
                      decoration: InputDecoration(
                        hintText: 'Search Project ID or Person...',
                        prefixIcon: const Icon(Icons.search, color: primaryMaroon),
                        filled: true,
                        fillColor: softParchment,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatusTab('Pending ($pendingCount)', 0),
                        _buildStatusTab('Ongoing ($ongoingCount)', 1),
                        _buildStatusTab('Done ($completedCount)', 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryMaroon))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentList.length,
                    itemBuilder: (context, index) => _buildTempleCard(currentList[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, int index) {
    final isActive = statusTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => statusTab = index),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primaryAccentGold : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isActive ? primaryAccentGold : lightGoldText.withOpacity(0.3)),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: isActive ? primaryMaroon : lightGoldText, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ),
    );
  }

  Widget _buildTempleCard(Map<String, dynamic> temple) {
    final List<Map<String, dynamic>> works = List<Map<String, dynamic>>.from(temple['works'] ?? []);
    
    // Status colors for the top right indicator
    Color statusColor;
    if (temple['status'] == 'ongoing') statusColor = Colors.blue;
    else if (temple['status'] == 'completed') statusColor = Colors.green;
    else statusColor = Colors.orange;

    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: primaryAccentGold, width: 0.8),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TempleDetailScreen(templeId: temple['id'], initialTempleData: temple))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // This is where the Correct ID is displayed
                  Text(temple['projectId'], 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: darkMaroonText, letterSpacing: 0.5)),
                  
                  // Adding a small visual indicator for status
                  Icon(Icons.circle, size: 12, color: statusColor),
                ],
              ),
              const SizedBox(height: 8),
              
              // Works Chips
              const Text("SCOPE OF WORK:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: secondaryGold, letterSpacing: 1)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: works.map((w) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryMaroon.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: primaryMaroon.withOpacity(0.1)),
                  ),
                  child: Text(w['workName'] ?? 'General Work', 
                    style: const TextStyle(fontSize: 11, color: primaryMaroon, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(height: 1, color: Color(0xFFF0E0C0)),
              ),

              // Local Contact Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundCream.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryAccentGold.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: primaryMaroon,
                      child: Icon(Icons.person_pin_circle_outlined, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(temple['localName'], 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkMaroonText)),
                          const SizedBox(height: 2),
                          Text("Local Contact: ${temple['localPhone']}", 
                            style: TextStyle(fontSize: 12, color: darkMaroonText.withOpacity(0.7), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call_outlined, color: Colors.green, size: 20),
                      onPressed: () {}, // Add logic for calling if needed
                    )
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Bottom Proposer Info
              Row(
                children: [
                  Icon(Icons.account_circle_outlined, size: 14, color: secondaryGold.withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Text("Proposed by: ${temple['userName']}", 
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: darkMaroonText.withOpacity(0.6))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}