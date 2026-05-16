import 'package:flutter/material.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;
  final Map<String, dynamic> initialTempleData;

  const TempleDetailScreen({
    Key? key,
    required this.templeId,
    required this.initialTempleData,
  }) : super(key: key);

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  late Map<String, dynamic> temple;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemple();
  }

  void _loadTemple() {
    temple = Map<String, dynamic>.from(widget.initialTempleData);

    temple['imageUrls'] =
        List<String>.from(temple['raw']?['imageUrls'] ?? []);

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(temple['name'] ?? 'Temple Project'),
        backgroundColor: const Color(0xFF4F46E5),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUserInfo(),
          const SizedBox(height: 16),
          _buildLocationInfo(),
          const SizedBox(height: 16),
          _buildFeatureInfo(),
          const SizedBox(height: 16),
          _buildImagesSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------- USER INFO ----------------

  Widget _buildUserInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _row('Name', temple['userName'] ?? ''),
            _row('Email', temple['userEmail'] ?? ''),
            _row('Phone', temple['userPhone'] ?? ''),
          ],
        ),
      ),
    );
  }

  // ---------------- LOCATION ----------------

  Widget _buildLocationInfo() {
    final raw = temple['raw'] ?? {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _row('Place', raw['place'] ?? ''),
            _row('Nearby Town', raw['nearbyTown'] ?? ''),
            _row('Taluk', raw['taluk'] ?? ''),
            _row('District', raw['district'] ?? ''),
            _row('Map Location', raw['mapLocation'] ?? ''),
            _row(
              'Visit Date',
              raw['dateCreated'] != null
                  ? raw['dateCreated'].toDate().toString().substring(0, 10)
                  : '',
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- FEATURE ----------------

  Widget _buildFeatureInfo() {
    final raw = temple['raw'] ?? {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Proposed Feature',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _row('Feature', raw['feature'] ?? ''),
            _row('Type', raw['featureType'] ?? ''),
            _row('Dimension', raw['featureDimension'] ?? ''),
            _row('Feature Amount', raw['featureAmount'] ?? ''),
            const SizedBox(height: 8),
            Text(
              'Estimated Amount: ₹${raw['estimatedAmount'] ?? '0'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- IMAGES (FIXED) ----------------

  Widget _buildImagesSection() {
    final List<String> images =
        List<String>.from(temple['imageUrls'] ?? []);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site Images',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (images.isEmpty)
              const Text(
                'No images uploaded',
                style: TextStyle(color: Colors.grey),
              )
            else
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final url = images[index];
                    return GestureDetector(
                      onTap: () async {
  final updated = await Navigator.push<Map<String, dynamic>?>(
    context,
    MaterialPageRoute(
      builder: (_) => TempleDetailScreen(
        templeId: temple['id'],
        initialTempleData: temple, // ✅ REQUIRED FIX
      ),
    ),
  );

  if (updated == null) {
    setState(() {
      temples.removeWhere((t) => t['id'] == temple['id']);
    });
  } else {
    final idx = temples.indexWhere((t) => t['id'] == updated['id']);
    if (idx != -1) {
      setState(() {
        temples[idx] = updated;
      });
    }
  }
}

                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 240,
                          fit: BoxFit.cover,
                          loadingBuilder:
                              (context, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              width: 240,
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder:
                              (context, error, stackTrace) {
                            return Container(
                              width: 240,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.broken_image,
                                size: 40,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- HELPER ----------------

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
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
