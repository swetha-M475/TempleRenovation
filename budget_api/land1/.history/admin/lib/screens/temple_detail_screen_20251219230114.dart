import 'package:cloud_firestore/cloud_firestore.dart';
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

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  Map<String, dynamic>? temple;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTempleFromFirestore();
  }

  Future<void> _loadTempleFromFirestore() async {
    setState(() => isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .get();

      if (!doc.exists) {
        temple = null;
      } else {
        temple = doc.data()!..['projectId'] = doc.id;
      }
    } catch (e) {
      debugPrint('Error loading project: $e');
      temple = null;
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _handleSanction() async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.templeId)
        .update({'status': 'ongoing'});

    await _loadTempleFromFirestore();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project sanctioned')),
    );
  }

  Future<void> _handleReject() async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.templeId)
        .update({'status': 'rejected'});

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (temple == null) {
      return const Scaffold(
        body: Center(child: Text('Project not found')),
      );
    }

    final status = temple!['status'] ?? 'pending';
    final images =
        List<String>.from(temple!['imageUrls'] ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: Text('Project ${temple!['projectId']}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('User Information'),
          _infoRow('Name', temple!['contactName'] ?? '-'),
          _infoRow('Phone', temple!['contactPhone'] ?? '-'),

          const SizedBox(height: 16),

          _sectionTitle('Location'),
          _infoRow('Place', temple!['place'] ?? '-'),
          _infoRow('Nearby Town', temple!['nearbyTown'] ?? '-'),
          _infoRow('Taluk', temple!['taluk'] ?? '-'),
          _infoRow('District', temple!['district'] ?? '-'),

          const SizedBox(height: 16),

          _sectionTitle('Budget'),
          Text(
            '₹${temple!['estimatedAmount'] ?? '0'}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 16),

          _sectionTitle('Site Images'),
          images.isEmpty
              ? const Text(
                  'No images uploaded',
                  style: TextStyle(color: Colors.grey),
                )
              : SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final url = images[index];
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: InteractiveViewer(
                                child: Image.network(url),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 240,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),

          const SizedBox(height: 24),

          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleSanction,
                    icon: const Icon(Icons.check),
                    label: const Text('Sanction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
