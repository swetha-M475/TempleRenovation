import 'package:flutter/material.dart';

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
  Map<String, dynamic>? temple;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemple();
  }

  Future<void> _loadTemple() async {
    setState(() => isLoading = true);

    await Future.delayed(const Duration(milliseconds: 200));

    temple = Map<String, dynamic>.from(widget.initialTempleData ?? {});

    temple ??= {};
    temple!['id'] = widget.templeId;
    temple!['name'] = temple!['name'] ?? 'Temple Project';
    temple!['status'] = temple!['status'] ?? 'pending';
    temple!['userName'] = temple!['userName'] ?? '';
    temple!['userEmail'] = temple!['userEmail'] ?? '';
    temple!['userPhone'] = temple!['userPhone'] ?? '';
    temple!['estimatedAmount'] = temple!['estimatedAmount'] ?? 0;

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
        title: const Text('Temple Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  temple!['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _info('Status', temple!['status']),
                _info('User', temple!['userName']),
                _info('Email', temple!['userEmail']),
                _info('Phone', temple!['userPhone']),
                const SizedBox(height: 12),
                Text(
                  '₹${(temple!['estimatedAmount'] as num).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
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
