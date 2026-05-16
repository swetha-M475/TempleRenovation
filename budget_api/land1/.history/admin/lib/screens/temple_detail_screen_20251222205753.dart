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
  Map<String, dynamic>? temple;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemple();
  }

  Future<void> _loadTemple() async {
    setState(() => isLoading = true);

    temple = Map<String, dynamic>.from(widget.initialTempleData);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.templeId)
          .get();

      if (doc.exists) {
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
    final t = temple!;

    final bool isSanctioned = t['isSanctioned'] == true;
    final int progress = ((t['progress'] ?? 0) as num).toInt();

    if (!isSanctioned) {
      t['status'] = 'pending';
    } else if (progress >= 100) {
      t['status'] = 'completed';
    } else {
      t['status'] = 'ongoing';
    }

    t['projectNumber'] =
        (t['projectNumber'] ?? t['projectId'] ?? 'P000').toString();

    t['name'] = (t['name'] ??
            (t['feature'] != null && t['feature'] != ''
                ? '${t['feature']} Project'
                : 'Temple Project'))
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || temple == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String status = (temple!['status'] ?? 'pending').toString();

    if (status == 'pending') {
      return PendingTempleDetailScreen(
        temple: temple!,
        onUpdated: (updated) => Navigator.pop(context, updated),
        onDeleted: () => Navigator.pop(context, null),
      );
    }

    if (status == 'ongoing') {
      return OngoingTempleDetailScreen(
        temple: temple!,
        onUpdated: (updated) => Navigator.pop(context, updated),
      );
    }

    return CompletedTempleDetailScreen(
      temple: temple!,
      onUpdated: (updated) => Navigator.pop(context, updated),
    );
  }
}
