import 'package:flutter/material.dart';

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
  late Map<String, dynamic> temple;

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.initialTempleData);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images =
        List<String>.from(temple['imageUrls'] ?? []);

    return Scaffold(
      appBar: AppBar(title: Text(temple['name'] ?? 'Project')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('User Information'),
          _row('Name', temple['userName']),
          _row('Phone', temple['userPhone']),
          const SizedBox(height: 16),

          _sectionTitle('Site Images'),
          images.isEmpty
              ? const Text('No images uploaded')
              : SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
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

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    temple['status'] = 'ongoing';
                    Navigator.pop(context, temple);
                  },
                  child: const Text('Sanction'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    Navigator.pop(context, null);
                  },
                  child: const Text('Reject'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _row(String k, String? v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text('$k:')),
          Expanded(
              child: Text(v ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        t,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
