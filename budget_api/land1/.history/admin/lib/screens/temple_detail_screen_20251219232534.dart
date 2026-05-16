import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;
  final Map<String, dynamic> initialTempleData;

  const TempleDetailScreen({
    super.key,
    required this.templeId,
    required this.initialTempleData,
  });

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  late Map<String, dynamic> t;

  @override
  void initState() {
    super.initState();
    t = Map<String, dynamic>.from(widget.initialTempleData['raw'] ?? {});
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return value.toDate().toString().substring(0, 10);
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = List<String>.from(t['imageUrls'] ?? []);

    return Scaffold(
      appBar: AppBar(title: const Text('Project Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('User Information', [
            _row('Contact Name', t['contactName']),
            _row('Phone', t['contactPhone']),
          ]),

          _section('Location Details', [
            _row('Place', t['place']),
            _row('Nearby Town', t['nearbyTown']),
            _row('Taluk', t['taluk']),
            _row('District', t['district']),
            _row('Map Location', t['mapLocation']),
            _row('Date Created', _formatDate(t['dateCreated'])),
          ]),

          _section('Proposed Feature', [
            _row('Feature', t['feature']),
            _row('Type', t['featureType']),
            _row('Dimension', t['featureDimension']),
            _row('Feature Amount', '₹${t['featureAmount']}'),
          ]),

          _section('Budget', [
            _row('Estimated Amount', '₹${t['estimatedAmount']}'),
          ]),

          _section(
            'Site Images',
            images.isEmpty
                ? [_text('No images uploaded')]
                : [
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              images[i],
                              width: 240,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                width: 240,
                                child: Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    widget.initialTempleData['status'] = 'ongoing';
                    Navigator.pop(context, widget.initialTempleData);
                  },
                  child: const Text('Sanction'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    Navigator.pop(context, null);
                  },
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _text(String t) {
    return Text(t, style: const TextStyle(color: Colors.grey));
  }
}
