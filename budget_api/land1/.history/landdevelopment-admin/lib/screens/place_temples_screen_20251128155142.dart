import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'temple_detail_screen.dart';

class PlaceTemplesScreen extends StatefulWidget {
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
  bool isLoading = true;

  List<Map<String, dynamic>> temples = [];
  int statusTab = 0; // 0 = pending, 1 = ongoing, 2 = completed

  @override
  void initState() {
    super.initState();
    _loadTemples();
  }

  Future<void> _loadTemples() async {
    setState(() => isLoading = true);

    // Fetch place data
    final placeData = await FirebaseService.getPlaceById(widget.placeId);
    placeName = placeData?['name'] ?? '';

    // Fetch temples in this place
    temples = await FirebaseService.getTemplesByPlace(widget.placeId);

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final pending = temples.where((t) => t['status'] == 'pending').toList();
    final ongoing = temples.where((t) => t['status'] == 'ongoing').toList();
    final completed = temples.where((t) => t['status'] == 'completed').toList();

    List<Map<String, dynamic>> currentList =
        statusTab == 0 ? pending : statusTab == 1 ? ongoing : completed;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(pending.length, ongoing.length, completed.length),

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
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final temple = currentList[index];

                          Color borderColor = temple['status'] == 'pending'
                              ? Colors.orange
                              : temple['status'] == 'ongoing'
                                  ? Colors.blue
                                  : Colors.green;

                          return _buildTempleCard(temple, borderColor);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int p, int o, int c) {
    return Container(
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
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Text(
                placeName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tirunelveli District',
                style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatusTab('Pending ($p)', 0),
                  _buildStatusTab('Ongoing ($o)', 1),
                  _buildStatusTab('Completed ($c)', 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTab(String label, int index) {
    final bool isActive = statusTab == index;
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
    final id = temple['id'] ?? '';
    final name = temple['name'] ?? '';
    final userName = temple['userName'] ?? '';
    final userEmail = temple['userEmail'] ?? '';
    final submittedDate = temple['submittedDate'] ?? '';
    final estimatedAmount = (temple['estimatedAmount'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: 3),
      ),
      child: InkWell(
        onTap: () async {
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TempleDetailScreen(
                templeId: id,
                initialTempleData: temple,
              ),
            ),
          );

          if (updated == null) {
            // Project rejected -> remove from list
            setState(() {
              temples.removeWhere((t) => t['id'] == id);
            });
          } else {
            // Update temple in list
            final int index = temples.indexWhere((t) => t['id'] == updated['id']);
            if (index != -1) {
              setState(() {
                temples[index] = updated;
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          userEmail,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Submitted: $submittedDate',
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
              Text(
                '₹${estimatedAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
