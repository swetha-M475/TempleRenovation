import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'temple_detail_screen.dart';

class PlaceTemplesScreen extends StatefulWidget {
  /// Here placeId is the TALUK NAME stored in projects.taluk
  final String placeId;

  const PlaceTemplesScreen({
    Key? key,
    required this.placeId,
  }) : super(key: key);

  @override
  State<PlaceTemplesScreen> createState() => _PlaceTemplesScreenState();
}

class _PlaceTemplesScreenState extends State<PlaceTemplesScreen> {
  String placeName = '';
  String districtName = '';
  List<Map<String, dynamic>> temples = [];
  bool isLoading = true;

  int statusTab = 0; // 0: Pending, 1: Ongoing, 2: Completed

  @override
  void initState() {
    super.initState();
    _loadTemples();
  }

  Future<void> _loadTemples() async {
    setState(() => isLoading = true);

    try {
      // Get all projects whose taluk matches this taluk
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('taluk', isEqualTo: widget.placeId)
          .get();

      placeName = widget.placeId;

      // Try to read district name from first project (if any)
      if (snap.docs.isNotEmpty) {
        districtName =
            (snap.docs.first.data()['district'] ?? '').toString();
      } else {
        districtName = '';
      }

      // collect all userIds
      final Set<String> userIds = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = (data['userId'] ?? '').toString();
        if (uid.isNotEmpty) userIds.add(uid);
      }

      // load all users used here
      final Map<String, Map<String, dynamic>> usersById = {};
      if (userIds.isNotEmpty) {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: userIds.toList())
            .get();
        for (final u in userSnap.docs) {
          usersById[u.id] = u.data();
        }
      }

      temples = snap.docs.map((doc) {
        final data = doc.data();
        final uid = (data['userId'] ?? '').toString();
        final userData = usersById[uid] ?? {};

        final bool isSanctioned = data['isSanctioned'] == true;
        String status;
        if (!isSanctioned) {
          status = 'pending';
        } else {
          // simple mapping: if progress == 100 -> completed, else ongoing
          final num progressNum = (data['progress'] ?? 0) as num;
          final int progress = progressNum.toInt();
          if (progress >= 100) {
            status = 'completed';
          } else {
            status = 'ongoing';
          }
        }

        return <String, dynamic>{
          'id': doc.id,
          'district': data['district'] ?? '',
          'taluk': data['taluk'] ?? '',
          'place': data['place'] ?? '',
          'name': data['feature'] != null && data['feature'] != ''
              ? '${data['feature']} Project'
              : 'Temple Project',
          'status': status,
          'userName': userData['name'] ?? data['contactName'] ?? '',
          'userEmail': userData['email'] ?? '',
          'userPhone': userData['phoneNumber'] ?? data['contactPhone'] ?? '',
          'submittedDate':
              (data['dateCreated'] != null && data['dateCreated'] is Timestamp)
                  ? (data['dateCreated'] as Timestamp)
                      .toDate()
                      .toIso8601String()
                      .substring(0, 10)
                  : '',
          'estimatedAmount':
              double.tryParse((data['estimatedAmount'] ?? '0').toString()) ??
                  0.0,
          'raw': data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading temples: $e');
      placeName = widget.placeId;
      districtName = '';
      temples = [];
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = temples.where((t) => t['status'] == 'pending').toList();
    final ongoing = temples.where((t) => t['status'] == 'ongoing').toList();
    final completed =
        temples.where((t) => t['status'] == 'completed').toList();

    List<Map<String, dynamic>> currentList;
    if (statusTab == 0) {
      currentList = pending;
    } else if (statusTab == 1) {
      currentList = ongoing;
    } else {
      currentList = completed;
    }

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      placeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      districtName.isEmpty
                          ? 'Temple Projects'
                          : '$districtName District',
                      style: const TextStyle(
                          color: Color(0xFFC7D2FE), fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    // Status tabs for this taluk
                    Row(
                      children: [
                        _buildStatusTab('Pending (${pending.length})', 0),
                        _buildStatusTab('Ongoing (${ongoing.length})', 1),
                        _buildStatusTab('Completed (${completed.length})', 2),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : currentList.isEmpty
                    ? Center(
                        child: Text(
                          statusTab == 0
                              ? 'No pending projects'
                              : statusTab == 1
                                  ? 'No ongoing projects'
                                  : 'No completed projects',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final temple = currentList[index];
                          Color borderColor;
                          if (temple['status'] == 'pending') {
                            borderColor = Colors.orange;
                          } else if (temple['status'] == 'ongoing') {
                            borderColor = Colors.blue;
                          } else {
                            borderColor = Colors.green;
                          }
                          return _buildTempleCard(temple, borderColor);
                        },
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? Colors.white : Colors.white24,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? const Color(0xFF4F46E5) : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTempleCard(Map<String, dynamic> temple, Color borderColor) {
    final id = (temple['id'] ?? '') as String;
    final name = (temple['name'] ?? '') as String;
    final userName = (temple['userName'] ?? '') as String;
    final userEmail = (temple['userEmail'] ?? '') as String;
    final userPhone = (temple['userPhone'] ?? '') as String;
    final submittedDate = (temple['submittedDate'] ?? 'N/A') as String;
    final estimatedAmountNum =
        (temple['estimatedAmount'] ?? 0.0) as num;
    final estimatedAmount = estimatedAmountNum.toDouble();

    final district = (temple['district'] ?? '') as String;
    final taluk = (temple['taluk'] ?? '') as String;
    final place = (temple['place'] ?? '') as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: 3),
      ),
      child: InkWell(
        onTap: () async {
          final updated = await Navigator.push<Map<String, dynamic>?>(
            context,
            MaterialPageRoute(
              builder: (_) => TempleDetailScreen(
                templeId: id,
                initialTempleData: temple,
              ),
            ),
          );

          if (updated == null) {
            setState(() {
              temples.removeWhere((t) => t['id'] == id);
            });
          } else {
            final idx = temples.indexWhere((t) => t['id'] == updated['id']);
            if (idx != -1) {
              setState(() {
                temples[idx] = updated;
              });
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              if (district.isNotEmpty || taluk.isNotEmpty || place.isNotEmpty)
                Text(
                  [district, taluk, place]
                      .where((s) => s.isNotEmpty)
                      .join(' • '),
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person,
                      size: 14, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        Text(
                          userEmail,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        if (userPhone.isNotEmpty)
                          Text(
                            userPhone,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Submitted: $submittedDate',
                style:
                    const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              Text(
                '₹${estimatedAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
