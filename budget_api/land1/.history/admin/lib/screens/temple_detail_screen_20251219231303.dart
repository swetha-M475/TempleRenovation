import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;
  final Map<String, dynamic>? initialTempleData;

  const TempleDetailScreen({
    Key? key,
    required this.templeId,
    this.initialTempleData,
  }) : super(key: key);

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.initialTempleData != null) {
        data = Map<String, dynamic>.from(widget.initialTempleData!['raw'] ?? {});
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.templeId)
            .get();
        data = doc.data();
      }
    } catch (_) {
      data = null;
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (data == null) {
      return const Scaffold(
        body: Center(child: Text('Project not found')),
      );
    }

    final List<String> images =
        List<String>.from(data!['imageUrls'] ?? []);

    final created = data!['dateCreated'] is Timestamp
        ? DateFormat('dd MMM yyyy')
            .format((data!['dateCreated'] as Timestamp).toDate())
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: 'Status',
            child: Text(
              (data!['status'] ?? 'pending').toString().toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),

          _card(
            title: 'Location',
            child: _kv({
              'Place': data!['place'],
              'Nearby Town': data!['nearbyTown'],
              'Taluk': data!['taluk'],
              'District': data!['district'],
              'Map Location': data!['mapLocation'],
              'Visit Date': created,
            }),
          ),

          _card(
            title: 'Feature Details',
            child: _kv({
              'Feature': data!['feature'],
              'Type': data!['featureType'],
              'Dimension': data!['featureDimension'],
              'Feature Amount': '₹${data!['featureAmount']}',
            }),
          ),

          _card(
            title: 'Contact',
            child: _kv({
              'Name': data!['contactName'],
              'Phone': data!['contactPhone'],
            }),
          ),

          _card(
            title: 'Budget',
            child: Text(
              '₹${data!['estimatedAmount']}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),

          _card(
            title: 'Site Images',
            child: images.isEmpty
                ? const Text('No images uploaded')
                : SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final url = images[i];
                        return GestureDetector(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: InteractiveViewer(
                                child: Image.network(url),
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 240,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _kv(Map<String, dynamic> map) {
    return Column(
      children: map.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  e.key,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                child: Text(
                  (e.value ?? '').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
