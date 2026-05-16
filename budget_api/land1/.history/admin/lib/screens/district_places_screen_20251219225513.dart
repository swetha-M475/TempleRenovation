import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'place_temples_screen.dart';

class DistrictPlacesScreen extends StatefulWidget {
  final String districtId; // district name stored in projects.district

  const DistrictPlacesScreen({
    Key? key,
    required this.districtId,
  }) : super(key: key);

  @override
  State<DistrictPlacesScreen> createState() => _DistrictPlacesScreenState();
}

class _DistrictPlacesScreenState extends State<DistrictPlacesScreen> {
  String searchQuery = '';
  String districtName = '';
  List<Map<String, dynamic>> places = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() => isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('district', isEqualTo: widget.districtId)
          .get();

      districtName = widget.districtId;

      final Map<String, Map<String, dynamic>> talukMap = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final String taluk =
            (data['taluk'] ?? '').toString().trim();
        if (taluk.isEmpty) continue;

        final String status =
            (data['status'] ?? 'pending').toString();

        talukMap.putIfAbsent(taluk, () {
          return {
            'id': taluk,
            'name': taluk,
            'temples': 0,
            'newRequests': 0,
          };
        });

        // total projects in this taluk
        talukMap[taluk]!['temples'] =
            (talukMap[taluk]!['temples'] as int) + 1;

        // pending = new request
        if (status == 'pending') {
          talukMap[taluk]!['newRequests'] =
              (talukMap[taluk]!['newRequests'] as int) + 1;
        }
      }

      places = talukMap.values.toList()
        ..sort((a, b) =>
            a['name'].toString().compareTo(b['name'].toString()));
    } catch (e) {
      debugPrint('Error loading district places: $e');
      places = [];
      districtName = widget.districtId;
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = places.where((p) {
      return p['name']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

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
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      '$districtName District',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${places.length} Taluks',
                      style: const TextStyle(
                        color: Color(0xFFC7D2FE),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search taluks...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No taluks available'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final place = filtered[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlaceTemplesScreen(
                                      placeId: place['id'],
                                    ),
                                  ),
                                );
                              },
                              title: Text(
                                place['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${place['temples']} Temple${place['temples'] == 1 ? '' : 's'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if ((place['newRequests'] as int) > 0)
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${place['newRequests']} New',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
