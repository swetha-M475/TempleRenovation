import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:flutter/material.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;

  const TempleDetailScreen({
    Key? key,
    required this.templeId,
  }) : super(key: key);

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}


class _PlaceTemplesScreenState extends State<PlaceTemplesScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> temples = [];

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
          .orderBy('dateCreated', descending: true)
          .get();

      temples = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'projectId': doc.id,
          'place': data['place'] ?? '',
          'status': data['status'] ?? 'pending',
          'district': data['district'] ?? '',
          'taluk': data['taluk'] ?? '',
          'dateCreated': data['dateCreated'],
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.placeId} Taluk'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : temples.isEmpty
              ? const Center(child: Text('No projects found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: temples.length,
                  itemBuilder: (context, index) {
                    final temple = temples[index];
                    final status = temple['status'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TempleDetailScreen(
                                templeId: temple['projectId'],
                              ),
                            ),
                          );
                        },
                        title: Text(
                          temple['place'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Status: ${status.toString().toUpperCase()}',
                        ),
                        trailing: _statusChip(status),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'ongoing':
        color = Colors.orange;
        break;
      case 'completed':
        color = Colors.green;
        break;
      default:
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
