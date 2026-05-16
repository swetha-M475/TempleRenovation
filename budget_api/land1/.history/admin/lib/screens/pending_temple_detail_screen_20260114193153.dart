import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PendingTempleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;
  final VoidCallback onDeleted;

  const PendingTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
    required this.onDeleted,
  }) : super(key: key);

  static const Color maroonDeep = Color(0xFF6A1B1A);
  static const Color maroonLight = Color(0xFF8E3D2C);
  static const Color goldAccent = Color(0xFFFFD700);
  static const Color creamBg = Color(0xFFFFFBF2);
  static const Color textDark = Color(0xFF2D2D2D);

  @override
  Widget build(BuildContext context) {
    final status = (temple['status'] ?? 'pending') as String;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onUpdated(temple);
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: creamBg,
        body: Column(
          children: [
            _buildHeader(context, status),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  _buildSectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'User Information',
                    child: Column(
                      children: [
                        _buildInfoRow('Name', (temple['userName'] ?? temple['name'] ?? 'N/A').toString()),
                        _buildInfoRow('Email', (temple['userEmail'] ?? temple['email'] ?? 'N/A').toString()),
                        _buildInfoRow('Phone', (temple['userPhone'] ?? temple['phone'] ?? 'N/A').toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSiteImagesCard(),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location Details',
                    child: Column(
                      children: [
                        _buildInfoRow('Place', (temple['place'] ?? '').toString()),
                        _buildInfoRow('District', (temple['district'] ?? '').toString()),
                        _buildInfoRow('Taluk', (temple['taluk'] ?? '').toString()),
                        _buildInfoRow('Map Link', (temple['mapLocation'] ?? 'Not provided').toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProjectComponentCard(),
                  const SizedBox(height: 16),
                  _buildContactBudgetCard(),
                  const SizedBox(height: 24),
                  _buildActionButtons(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String status) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [maroonDeep, maroonLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: goldAccent, size: 20),
                onPressed: () => onUpdated(temple),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (temple['name'] ?? 'Temple Project').toString(),
                      style: GoogleFonts.philosopher(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${temple['projectNumber'] ?? temple['projectId'] ?? 'P000'} • ${status.toUpperCase()}',
                      style: GoogleFonts.poppins(
                        color: goldAccent.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: maroonDeep.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: maroonLight, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.philosopher(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: maroonDeep,
                  ),
                ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSiteImagesCard() {
    // UPDATED FALLBACK LOGIC
    // This checks every possible field the User app might use to store images
    List<String> siteImages = [];
    
    final rawData = temple['siteImages'] ?? 
                    temple['imageUrls'] ?? 
                    temple['images'] ?? 
                    temple['photos'];

    if (rawData is List) {
      siteImages = rawData.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    } else if (rawData is String && rawData.isNotEmpty) {
      siteImages = [rawData];
    }

    return _buildSectionCard(
      icon: Icons.camera_alt_outlined,
      title: 'Site Gallery',
      child: siteImages.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No site images found in database', 
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ),
            )
          : SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: siteImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      siteImages[index],
                      width: 280,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 280,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        );
                      },
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 280,
                          color: Colors.grey[100],
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildProjectComponentCard() {
    final feature = (temple['feature'] ?? 'General Renovation').toString();
    return _buildSectionCard(
      icon: Icons.architecture,
      title: 'Project Focus',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: maroonDeep.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: goldAccent, width: 4)),
        ),
        child: Text(
          feature,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: maroonDeep),
        ),
      ),
    );
  }

  Widget _buildContactBudgetCard() {
    final double amount = double.tryParse((temple['estimatedAmount'] ?? '0').toString()) ?? 0.0;
    return _buildSectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Budget & Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Local POC', (temple['contactName'] ?? temple['userName'] ?? temple['name'] ?? 'N/A').toString()),
          const SizedBox(height: 12),
          Text('ESTIMATED BUDGET', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey, letterSpacing: 1.2)),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: GoogleFonts.philosopher(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: maroonDeep,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13, color: textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _handleSanction(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('SANCTION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => onDeleted(), 
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[800],
              side: BorderSide(color: Colors.red[800]!),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
          ),
        ),
      ],
    );
  }

  void _handleSanction(BuildContext context) async {
    final confirm = await _showDialog(context, 'Sanction Project', 'Move this project to the ongoing phase?', Colors.green);
    if (confirm == true) {
      final docId = (temple['id'] ?? temple['projectId'] ?? '').toString();
      if (docId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Project ID not found")));
        return;
      }
      
      await FirebaseFirestore.instance.collection('projects').doc(docId).update({
        'isSanctioned': true,
        'status': 'ongoing',
      });
      temple['isSanctioned'] = true;
      temple['status'] = 'ongoing';
      onUpdated(temple);
    }
  }

  Future<bool?> _showDialog(BuildContext context, String title, String msg, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.philosopher(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}