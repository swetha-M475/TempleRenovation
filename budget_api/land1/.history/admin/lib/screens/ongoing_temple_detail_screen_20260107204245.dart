import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'project_chat_section.dart';
import 'finance_tab_section.dart'; // IMPORTED NEW FILE

class OngoingTempleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;

  const OngoingTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
  }) : super(key: key);

  @override
  State<OngoingTempleDetailScreen> createState() =>
      _OngoingTempleDetailScreenState();
}

class _OngoingTempleDetailScreenState extends State<OngoingTempleDetailScreen> {
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late Map<String, dynamic> temple;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
  }

  void _handleBackNavigation() {
    widget.onUpdated(temple);
    Navigator.pop(context);
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
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                ),
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
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBackNavigation,
        ),
        title: Text(
          (temple['name'] ?? 'Temple Project').toString(),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('Activities', 0),
                _buildTab('Finances', 1),
                _buildTab('Payment Process', 2),
                _buildTab('Feedback', 3),
              ],
            ),
          ),
          Expanded(child: _buildCurrentTabContent()),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: isActive ? primaryGold : Colors.transparent,
                    width: 3)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? primaryMaroon : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (selectedTab) {
      case 0:
        return _buildActivitiesTab();
      case 1:
        // UPDATED: Now calls the separate file widget
        return FinanceTabSection(
          projectId: temple['id'],
          onShowImage: _showFullScreenImage,
        );
      case 2:
        return _buildPaymentProcessTab();
      case 3:
        return ProjectChatSection(projectId: temple['id'], currentRole: 'admin');
      default:
        return const Center(child: Text("Content Not Found"));
    }
  }

  // =========================================================
  // ACTIVITIES & OTHER TABS (Kept as provided by user)
  // =========================================================

  Widget _buildActivitiesTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: const TabBar(
              labelColor: primaryMaroon,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primaryMaroon,
              tabs: [
                Tab(text: "To Do"),
                Tab(text: "Ongoing"),
                Tab(text: "Completed"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTaskList('todo'),
                _buildOngoingList(), 
                _buildTaskList('completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: temple['id'])
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("No $status works found", style: const TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            DateTime? fromDate = (data['fromDate'] as Timestamp?)?.toDate();
            DateTime? toDate = (data['toDate'] as Timestamp?)?.toDate();
            String dateText = fromDate != null && toDate != null ? "${fromDate.day}/${fromDate.month} - ${toDate.day}/${toDate.month}/${toDate.year}" : "Date not set";

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(data['taskName'] ?? 'Unknown Work', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(dateText),
                trailing: status == 'completed' ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.hourglass_empty, color: Colors.orange),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOngoingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: temple['id'])
          .where('status', whereIn: ['ongoing', 'pending_approval'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No ongoing works", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final status = data['status'] ?? 'ongoing';
            List<dynamic> allImages = [...(data['startImages'] ?? []), ...(data['endImages'] ?? [])];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(data['taskName'] ?? 'Unknown Work', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: darkMaroonText)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: status == 'pending_approval' ? Colors.orange : Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                          child: Text(status == 'pending_approval' ? "Pending Approval" : "In Progress", style: TextStyle(color: status == 'pending_approval' ? Colors.white : Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (allImages.isNotEmpty) ...[
                      const Text("Attached Photos:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: allImages.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () => _showFullScreenImage(allImages[i]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(allImages[i], width: 80, height: 80, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (status == 'pending_approval') ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => FirebaseFirestore.instance.collection('project_tasks').doc(docId).update({'status': 'ongoing'}),
                            child: const Text("Not Approved", style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => FirebaseFirestore.instance.collection('project_tasks').doc(docId).update({'status': 'completed', 'completedAt': FieldValue.serverTimestamp()}),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("Approve"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentProcessTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Budget Utilization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [Text('Total Budget', style: TextStyle(color: Colors.grey)), Text('₹5,00,000', style: TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon))],
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(value: 0.6, backgroundColor: backgroundCream, color: primaryGold, minHeight: 8),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Bills Uploaded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bills').where('projectId', isEqualTo: temple['id']).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Container(padding: const EdgeInsets.all(20), child: const Center(child: Text("No bills found.")));
            return Column(
              children: snapshot.data!.docs.map((doc) {
                final bill = doc.data() as Map<String, dynamic>;
                List<dynamic> images = bill['imageUrls'] ?? [];
                return Card(
                  child: ExpansionTile(
                    title: Text(bill['title'] ?? 'Bill', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('₹${bill['amount']}', style: const TextStyle(color: Colors.green)),
                    children: [
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: GestureDetector(
                                onTap: () => _showFullScreenImage(images[i]),
                                child: Image.network(images[i]),
                              ),
                            ),
                          ),
                        )
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}