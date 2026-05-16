import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'temple_detail_screen.dart';

class PlaceTemplesScreen extends StatefulWidget {
  final String placeId; // this represents district
  final String placeName; // display name

  const PlaceTemplesScreen({
    Key? key,
    required this.placeId,
    required this.placeName,
  }) : super(key: key);

  @override
  State<PlaceTemplesScreen> createState() => _PlaceTemplesScreenState();
}

class _PlaceTemplesScreenState extends State<PlaceTemplesScreen> {
  int statusTab = 0; // 0: pending, 1: approved, 2: rejected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('projects')
                  .where('district', isEqualTo: widget.placeName)
                  .where('removedByUser', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final pending = docs.where((d) => d['status'] == 'pending');
                final approved = docs.where((d) => d['status'] == 'approved');
                final rejected = docs.where((d) => d['status'] == 'rejected');

                List<QueryDocumentSnapshot> current;

                if (statusTab == 0)
                  current = pending.toList();
                else if (statusTab == 1)
                  current = approved.toList();
                else
                  current = rejected.toList();

                if (current.isEmpty) {
                  return const Center(
                    child: Text(
                      'No projects found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: current.length,
                  itemBuilder: (context, index) {
                    final data = current[index].data() as Map<String, dynamic>;
                    final docId = current[index].id;

                    return _buildCard(docId, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                widget.placeName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Projects',
                style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _tab('Pending', 0),
                  _tab('Approved', 1),
                  _tab('Rejected', 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(String label, int tab) {
    final active = statusTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => statusTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? Colors.white : Colors.white30),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.indigo : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String docId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: data['status'] == 'pending'
              ? Colors.orange
              : data['status'] == 'approved'
              ? Colors.blue
              : Colors.red,
          width: 3,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TempleDetailScreen(templeId: docId, initialTempleData: data),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${data['place']}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Feature: ${data['feature']}",
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                "Amount: ₹${data['estimatedAmount']}",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo,
                ),
              ),
              Text(
                "Status: ${data['status']}",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
