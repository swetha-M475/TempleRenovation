import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pending_temple_detail_screen.dart';
import 'ongoing_temple_detail_screen.dart';
import 'completed_temple_detail_screen.dart';

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
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color primaryGold = Color(0xFFD4AF37);

  Map<String, dynamic>? temple;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemple();
  }

  Future<void> _loadTemple() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    temple = Map<String, dynamic>.from(widget.initialTempleData);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        temple!.addAll(data);
        temple!['id'] = widget.templeId;
      }
    } catch (e) {
      debugPrint('Error loading temple: $e');
    }

    _normalizeTempleFields();

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _normalizeTempleFields() {
    if (temple == null) return;
    final t = temple!;

    // 1. Status Logic: Check for Rejected status first
    final String currentStatus = (t['status'] ?? 'pending').toString().toLowerCase();
    final bool isSanctioned = t['isSanctioned'] == true;
    final int progress = ((t['progress'] ?? 0) as num).toInt();

    if (currentStatus == 'rejected') {
      t['status'] = 'rejected';
    } else if (!isSanctioned) {
      t['status'] = 'pending';
    } else if (progress >= 100) {
      t['status'] = 'completed';
    } else {
      t['status'] = 'ongoing';
    }

    // 2. BUG FIX: Normalize Aadhar from user app key 'aadhar' to admin app key 'userAadhar'
    t['userAadhar'] = (t['userAadhar'] ?? t['aadhar'] ?? 'Not provided').toString();

    // 3. BUG FIX: Normalize Site Images from user app key 'siteImages' to admin app key 'imageUrls'
    if (t['imageUrls'] == null || (t['imageUrls'] as List).isEmpty) {
      t['imageUrls'] = t['siteImages'] ?? [];
    }

    // Ensure User Info fallback
    t['userName'] = (t['userName'] ?? t['name'] ?? 'User').toString();
    t['userEmail'] = (t['userEmail'] ?? t['email'] ?? '').toString();
    t['userPhone'] = (t['userPhone'] ?? t['phone'] ?? '').toString();

    t['projectNumber'] = (t['projectNumber'] ?? t['projectId'] ?? 'P000').toString();

    t['name'] = (t['name'] ??
            (t['feature'] != null && t['feature'] != ''
                ? '${t['feature']} Project'
                : 'Temple Project'))
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || temple == null) {
      return Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(
          backgroundColor: primaryMaroon,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Loading Details...',
            style: TextStyle(color: Color(0xFFFFF4D6), fontSize: 18),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: primaryMaroon),
        ),
      );
    }

    final String status = (temple!['status'] ?? 'pending').toString();

    switch (status) {
      case 'pending':
        return PendingTempleDetailScreen(
          temple: temple!,
          onUpdated: (updated) => Navigator.pop(context, updated),
          onDeleted: () => _markAsRejected(), // Handle rejection as a status update
        );
      case 'ongoing':
        return OngoingTempleDetailScreen(
          temple: temple!,
          onUpdated: (updated) => Navigator.pop(context, updated),
        );
      case 'completed':
        return CompletedTempleDetailScreen(
          temple: temple!,
          onUpdated: (updated) => Navigator.pop(context, updated),
        );
      case 'rejected':
        return Scaffold(
          appBar: AppBar(backgroundColor: Colors.red[900], title: const Text("Rejected Project")),
          body: const Center(child: Text("This project has been rejected.")),
        );
      default:
        return const Scaffold(body: Center(child: Text('Unknown Status')));
    }
  }

  // New helper to handle the rejection display for User Phase
  void _markAsRejected() async {
    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.templeId)
        .update({'status': 'rejected', 'isSanctioned': false});
    if (mounted) Navigator.pop(context, null);
  }
}