import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:admin/screens/temple_detail_screen.dart';

class PlaceTemplesScreen extends StatefulWidget {
  final String placeId;

  const PlaceTemplesScreen({Key? key, required this.placeId}) : super(key: key);

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
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('taluk', isEqualTo: widget.placeId)
          .get();

      placeName = widget.placeId;

      if (snap.docs.isNotEmpty) {
        districtName = (snap.docs.first.data()['district'] ?? '').toString();
      }

      temples = snap.docs.map((doc) {
        final data = doc.data();

        String status;
        if (data['isSanctioned'] != true) {
          status = 'pending';
        } else {
          final progress = (data['progress'] ?? 0) as num;
          status = progress >= 100 ? 'completed' : 'ongoing';
        }

        return {
          'id': doc.id,
          'name': data['feature'] != null && data['feature'] != ''
              ? '${data['feature']} Project'
              : 'Temple Project',
          'status': status,
          'district': data['district'] ?? '',
          'taluk': data['taluk'] ?? '',
          'place': data['place'] ?? '',
          'submittedDate': (data['dateCreated'] is Timestamp)
              ? (data['dateCreated'] as Timestamp)
                    .toDate()
                    .toIso8601String()
                    .substring(0, 10)
              : '',
          'estimatedAmount':
              double.tryParse((data['estimatedAmount'] ?? '0').toString()) ??
              0.0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading temples: $e');
      temples = [];
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = temples.where((t) => t['status'] == 'pending').toList();
    final ongoing = temples.where((t) => t['status'] == 'ongoing').toList();
    final completed = temples.where((t) => t['status'] == 'completed').toList();

    final currentList = statusTab == 0
        ? pending
        : statusTab == 1
        ? ongoing
        : completed;

    return Scaffold(
      body: Column(
        children: [
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
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                    Text(
                      districtName.isEmpty
                          ? 'Temple Projects'
                          : '$districtName District',
                      style: const TextStyle(
                        color: Color(0xFFC7D2FE),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
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
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : currentList.isEmpty
                ? const Center(child: Text('No projects found'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentList.length,
                    itemBuilder: (context, index) {
                      final temple = currentList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            temple['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '₹${(temple['estimatedAmount'] as double).toStringAsFixed(0)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          ,
                        ),
                      );
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
            border: Border.all(color: Colors.white24),
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
}
