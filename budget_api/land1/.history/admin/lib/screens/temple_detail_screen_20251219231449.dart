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
    _loadTemple();
  }

  Future<void> _loadTemple() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .get();

      if (!doc.exists) {
        temple = null;
      } else {
        temple = doc.data();
        temple!['id'] = doc.id;
      }
    } catch (e) {
      temple = null;
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _sanctionProject() async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.templeId)
        .update({'status': 'ongoing'});

    Navigator.pop(context, true);
  }

  Future<void> _rejectProject() async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.templeId)
        .delete();

    Navigator.pop(context, false);
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

    final List<String> images =
        List<String>.from(temple!['imageUrls'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('User Details'),
          _info('Contact Name', temple!['contactName']),
          _info('Phone', temple!['contactPhone']),
          _info('Feature', temple!['feature']),
          _info('Type', temple!['featureType']),
          _info('Dimension', temple!['featureDimension']),
          _info('Estimated Amount', '₹${temple!['estimatedAmount']}'),

          const SizedBox(height: 20),
          _sectionTitle('Location'),
          _info('Place', temple!['place']),
          _info('Nearby Town', temple!['nearbyTown']),
          _info('Taluk', temple!['taluk']),
          _info('District', temple!['district']),
          _info('Map Location', temple!['mapLocation']),

          const SizedBox(height: 20),
          _sectionTitle('Site Images'),

          if (images.isEmpty)
            const Text('No images uploaded')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: images.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(images[i]),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      images[i],
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 30),

          if (temple!['status'] == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _sanctionProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Sanction'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _rejectProject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _info(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
