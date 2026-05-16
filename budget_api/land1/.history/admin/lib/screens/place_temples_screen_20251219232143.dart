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
  bool isLoading = true;
  List<Map<String, dynamic>> temples = [];
  int statusTab = 0;

  @override
  void initState() {
    super.initState();
    _loadTemples();
  }

  Future<void> _loadTemples() async {
    setState(() => isLoading = true);

    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('taluk', isEqualTo: widget.placeId)
        .get();

    temples = snap.docs.map((doc) {
      final d = doc.data();

      String status = 'pending';
      if (d['progress'] != null && (d['progress'] as num) >= 100) {
        status = 'completed';
      } else if (d['progress'] != null && (d['progress'] as num) > 0) {
        status = 'ongoing';
      }

      return {
        'id': doc.id,
        'name': d['feature'] ?? 'Temple Project',
        'district': d['district'] ?? '',
        'taluk': d['taluk'] ?? '',
        'place': d['place'] ?? '',
        'status': status,
        'userName': d['contactName'] ?? '',
        'userPhone': d['contactPhone'] ?? '',
        'estimatedAmount': d['estimatedAmount'] ?? '0',
        'submittedDate': d['dateCreated'] is Timestamp
            ? (d['dateCreated'] as Timestamp)
                .toDate()
                .toString()
                .substring(0, 10)
            : '',
        'imageUrls': List<String>.from(d['imageUrls'] ?? []),
        'raw': d,
      };
    }).toList();

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = temples.where((t) {
      if (statusTab == 0) return t['status'] == 'pending';
      if (statusTab == 1) return t['status'] == 'ongoing';
      return t['status'] == 'completed';
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.placeId)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final temple = filtered[i];

                return Card(
                  child: ListTile(
                    title: Text(temple['name']),
                    subtitle: Text(temple['userName']),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final updated =
                          await Navigator.push<Map<String, dynamic>?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TempleDetailScreen(
                            templeId: temple['id'],
                            initialTempleData: temple,
                          ),
                        ),
                      );

                      if (updated != null) {
                        setState(() {
                          final idx = temples.indexWhere(
                              (e) => e['id'] == updated['id']);
                          if (idx != -1) temples[idx] = updated;
                        });
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
