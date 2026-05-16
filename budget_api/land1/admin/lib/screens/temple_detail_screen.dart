import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pending_temple_detail_screen.dart';
import 'ongoing_temple_detail_screen.dart';
import 'completed_temple_detail_screen.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;
  final Map initialTempleData;

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

  Map? temple;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemple();
  }

  Future<void> _loadTemple() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    // Start with data passed from the list
    temple = Map.from(widget.initialTempleData);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        temple!.addAll(data);

        // Ensure IDs are consistent
        temple!['id'] = widget.templeId;
        temple!['projectId'] = data['projectId'] ?? widget.templeId;
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

    // 1. Status Logic
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

    // 2. Local Person Data (LOC and LOP)
    // Ensuring these fields exist for the detail screens to display
    t['localPersonName'] = (t['localPersonName'] ?? t['localName'] ?? 'Not Provided').toString();
    t['localPersonPhone'] = (t['localPersonPhone'] ?? t['localPhone'] ?? 'Not Provided').toString();

    // 3. Multiple Works Feature
    // Ensure 'works' is a clean List of Maps
    if (t['works'] != null && t['works'] is List) {
      t['works'] = (t['works'] as List).map((w) => Map<String, dynamic>.from(w)).toList();
    } else {
      t['works'] = [];
    }

    // 4. Security: Remove sensitive data
    t.remove('aadhar');
    t.remove('userAadhar');
    t.remove('aadharNumber');

    // 5. Image Normalization
    if (t['imageUrls'] != null) {
      if (t['imageUrls'] is List) {
        t['imageUrls'] = (t['imageUrls'] as List)
            .map((e) => e.toString())
            .where((url) => url.startsWith('http'))
            .toList();
      }
    } else {
      t['imageUrls'] = [];
    }

    // 6. User and Project Identity
    t['userName'] = (t['userName'] ?? t['name'] ?? 'User').toString();
    t['userEmail'] = (t['userEmail'] ?? t['email'] ?? '').toString();
    t['userPhone'] = (t['userPhone'] ?? t['phone'] ?? '').toString();
    
    // Fallback for name if works list is empty
    if (t['name'] == null || t['name'] == 'Temple Project') {
       if (t['works'] != null && (t['works'] as List).isNotEmpty) {
         t['name'] = t['works'][0]['workName'];
       } else {
         t['name'] = t['feature'] ?? 'Temple Project';
       }
    }
  }

  void _markAsRejected() async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .update({
        'status': 'rejected',
        'isSanctioned': false,
      });

      if (mounted) {
        Navigator.pop(context, 'deleted');
      }
    } catch (e) {
      debugPrint('Error rejecting project: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || temple == null) {
      return Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(
          backgroundColor: primaryMaroon,
          elevation: 0,
          title: const Text('Loading Details...', style: TextStyle(color: Color(0xFFFFF4D6))),
        ),
        body: const Center(child: CircularProgressIndicator(color: primaryMaroon)),
      );
    }

    final String status = (temple!['status'] ?? 'pending').toString();
    final Map<String, dynamic> displayData = Map<String, dynamic>.from(temple!);

    // Each of these sub-screens will now receive 'localPersonName', 
    // 'localPersonPhone', and the 'works' list inside the temple map.
    switch (status) {
      case 'pending':
        return PendingTempleDetailScreen(
          temple: displayData,
          onUpdated: (updated) => Navigator.pop(context, updated),
          onDeleted: _markAsRejected,
        );
      case 'ongoing':
        return OngoingTempleDetailScreen(
          temple: displayData,
          onUpdated: (updated) => Navigator.pop(context, updated),
        );
      case 'completed':
        return CompletedTempleDetailScreen(
          temple: displayData,
          onUpdated: (updated) => Navigator.pop(context, updated),
        );
      case 'rejected':
        Future.microtask(() {
          if (mounted) Navigator.pop(context, 'deleted');
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      default:
        return const Scaffold(body: Center(child: Text('Unknown Status')));
    }
  }
}