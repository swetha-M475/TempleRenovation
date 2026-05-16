import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:landdevelop/screens/project_chat_section.dart'; 

class PendingProjectScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final String currentUserId;

  const PendingProjectScreen({
    super.key,
    required this.project,
    required this.currentUserId,
  });

  @override
  State<PendingProjectScreen> createState() => _PendingProjectScreenState();
}

class _PendingProjectScreenState extends State<PendingProjectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
      return timestamp.toString().split(' ')[0];
    } catch (e) {
      return 'N/A';
    }
  }

  bool _hasImages() {
    final imageFields = ['imageUrl', 'images', 'photoUrl', 'imageUrls'];
    for (var field in imageFields) {
      if (widget.project[field] != null && (widget.project[field] as List).isNotEmpty) return true;
    }
    return false;
  }

  List<String> _getAllImages() {
    List<String> images = [];
    if (widget.project['imageUrls'] != null) {
      final urls = widget.project['imageUrls'] as List?;
      if (urls != null) images.addAll(urls.cast<String>());
    }
    return images;
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        title: Text(
          widget.project['projectId'] ?? 'Project Details',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(text: '📋 Details'),
            Tab(text: '💬 Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(20.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeaderSection(),
                    const SizedBox(height: 24),
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    _buildMainProjectCard(),
                    const SizedBox(height: 24),
                    if (_hasImages()) ...[
                      _buildImageGallery(),
                      const SizedBox(height: 24),
                    ],
                    _buildTimelineSection(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
          ProjectChatSection(
            projectId: widget.project['id'].toString(),
            currentRole: 'user',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFB8962E)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Text(
            widget.project['place']?.toString() ?? 'Unnamed Project',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.project['taluk']?.toString() ?? ''}, ${widget.project['district']?.toString() ?? ''}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = (widget.project['status'] ?? 'pending').toString().toLowerCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: status == 'pending' ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'pending' ? Colors.orange : Colors.green, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(status == 'pending' ? Icons.hourglass_empty : Icons.check_circle,
              color: status == 'pending' ? Colors.orange : Colors.green, size: 40),
          const SizedBox(width: 16),
          Column(
            children: [
              Text(status.toUpperCase(),
                  style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.bold,
                      color: status == 'pending' ? Colors.orange.shade800 : Colors.green.shade800)),
              Text('Waiting for Admin Approval',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainProjectCard() {
    // 1. Safely cast the works list from Firestore
    List<dynamic> rawWorks = widget.project['works'] ?? [];
    List<Map<String, dynamic>> worksList = [];
    if (rawWorks is List) {
      for (var w in rawWorks) {
        if (w is Map) {
          worksList.add(Map<String, dynamic>.from(w));
        }
      }
    }

    final String localContactName = widget.project['localPersonName'] ?? 'Not provided';
    final String localContactPhone = widget.project['localPersonPhone'] ?? 'Not provided';
    final String totalEstimate = widget.project['estimatedAmount']?.toString() ?? '0';

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- General Info ---
            Text(
              "Local Contact Information",
              style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037)),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, "Name:", localContactName),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, "Phone:", localContactPhone),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.account_balance_wallet, "Total Estimate:", "₹ $totalEstimate"),
            
            const SizedBox(height: 24),
            const Divider(color: Color(0xFFF5E6CA), thickness: 1),
            const SizedBox(height: 24),

            // --- Works Header ---
            Row(
              children: [
                const Icon(Icons.engineering_outlined, color: Color(0xFFD4AF37), size: 24), 
                const SizedBox(width: 8),
                Text(
                  'Proposed Works',
                  style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Works Grid ---
            if (worksList.isNotEmpty)
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: worksList.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _buildDetailedWorkCard(worksList[index], index + 1);
                },
              )
            else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF3E2723))),
        ),
      ],
    );
  }

  Widget _buildDetailedWorkCard(Map<String, dynamic> data, int number) {
    final String name = data['workName'] ?? 'Unknown Work';
    final String description = data['workDescription'] ?? 'No description provided';
    final String amount = data['amount'] ?? '';
    final String imageUrl = data['workImageUrl'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section: Title & Description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display specific work image if it exists
                if (imageUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showFullScreenImage(imageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                    ),
                  )
                else
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                const SizedBox(width: 16),
                
                // Name & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$number. $name",
                        style: GoogleFonts.cinzel(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold, 
                          color: const Color(0xFF3E2723)
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 12, 
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Section: Estimate
          if (amount.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6CA).withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15), 
                  bottomRight: Radius.circular(15)
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF5D4037)),
                  const SizedBox(width: 4),
                  Text("Estimated Cost: ", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
                  Text(amount, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2D6A4F))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(child: Text("No works data available", style: GoogleFonts.poppins(color: Colors.grey))),
    );
  }

  Widget _buildImageGallery() {
    final images = _getAllImages();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library, color: Color(0xFF5D4037), size: 24),
            const SizedBox(width: 12),
            Text('Main Site Gallery (${images.length})',
                style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _showFullScreenImage(images[index]),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(image: NetworkImage(images[index]), fit: BoxFit.cover),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineSection() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Timeline',
                style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
            const SizedBox(height: 20),
            _buildTimelineItem('📝 Project Proposed', _formatTimestamp(widget.project['dateCreated'])),
            if (widget.project['visitDate'] != null)
              _buildTimelineItem('👀 Intended Visit Date', _formatTimestamp(widget.project['visitDate'])),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(String event, String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: const Color(0xFFD4AF37)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(date, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}