import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .get();

      if (!doc.exists) {
        temple = null;
      } else {
        temple = doc.data()!;
      }
    } catch (e) {
      temple = null;
    }

    setState(() => isLoading = false);
  }

  Future<void> _handleApprove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Project'),
        content: const Text('Do you want to approve this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final admin = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .update({
        'status': 'approved',
        'adminId': admin.uid,
        'adminActionAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project approved successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval failed: $e')),
      );
    }
  }

  Future<void> _handleReject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Project'),
        content: const Text('Do you want to reject this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final admin = FirebaseAuth.instance.currentUser!;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .update({
        'status': 'rejected',
        'adminId': admin.uid,
        'adminActionAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project rejected')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejection failed: $e')),
      );
    }
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

    final status = (temple!['status'] ?? 'pending') as String;
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _info('Place', temple!['place']),
            _info('Taluk', temple!['taluk']),
            _info('District', temple!['district']),
            _info('Contact Name', temple!['contactName']),
            _info('Phone', temple!['contactPhone']),
            _info('Estimated Amount', temple!['estimatedAmount']),
            const SizedBox(height: 16),

            _statusChip(status),

            const Spacer(),

            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleApprove,
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

            if (isApproved)
              const Center(
                child: Text(
                  'Project Approved',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

            if (isRejected)
              const Center(
                child: Text(
                  'Project Rejected',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
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

  Widget _statusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'APPROVED';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'REJECTED';
        break;
      default:
        color = Colors.orange;
        text = 'PENDING';
    }

    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }
}
