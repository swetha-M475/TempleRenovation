import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'project_chat_section.dart';

class PendingTempleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> temple;
  final void Function(Map<String, dynamic>?) onUpdated;
  final VoidCallback onDeleted;

  const PendingTempleDetailScreen({
    Key? key,
    required this.temple,
    required this.onUpdated,
    required this.onDeleted,
  }) : super(key: key);

  @override
  State<PendingTempleDetailScreen> createState() =>
      _PendingTempleDetailScreenState();
}

class _PendingTempleDetailScreenState extends State<PendingTempleDetailScreen> {
  static const Color maroonDeep = Color(0xFF6A1B1A);
  static const Color maroonLight = Color(0xFF8E3D2C);
  static const Color goldAccent = Color(0xFFFFD700);
  static const Color creamBg = Color(0xFFFFFBF2);
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color successGreen = Color(0xFF2D6A4F);

  final TextEditingController _amountController = TextEditingController();
  bool _isEditingAmount = false;

  @override
  void initState() {
    super.initState();
    final amount = widget.temple['estimatedAmount']?.toString() ?? '0';
    _amountController.text = amount;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _getProjectId() {
    return widget.temple['id']?.toString() ?? 
           widget.temple['projectId']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.temple['status'] ?? 'pending').toString();

    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          widget.onUpdated(widget.temple);
          Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: creamBg,
          body: Column(
            children: [
              _buildHeader(context, status),
              Container(
                color: Colors.white,
                child: TabBar(
                  labelColor: maroonDeep,
                  indicatorColor: maroonDeep,
                  tabs: const [
                    Tab(text: 'Project Details'),
                    Tab(text: 'Chat'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildDetailsTab(status),
                    _buildChatTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTab(String status) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        if (status == 'ongoing' || status == 'completed') ...[
          _buildBudgetTracker(),
          const SizedBox(height: 16),
        ],

        // 1. Proposer Information
        _buildSectionCard(
          icon: Icons.person_outline_rounded,
          title: 'Proposer Information',
          child: Column(
            children: [
              _buildInfoRow('Name', widget.temple['userName'] ?? 'N/A'),
              _buildInfoRow('Email', widget.temple['userEmail'] ?? 'N/A'),
              _buildInfoRow('Phone', widget.temple['userPhone'] ?? 'N/A'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Local Person Contact (Corrected LOC/LOP)
        _buildSectionCard(
          icon: Icons.location_history_rounded,
          title: 'Local Contact (POC)',
          child: Column(
            children: [
              _buildInfoRow('Name', widget.temple['localPersonName'] ?? widget.temple['localName'] ?? 'N/A'),
              _buildInfoRow('Phone', widget.temple['localPersonPhone'] ?? widget.temple['localPhone'] ?? 'N/A'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Proposed Works List (Corrected Works Fetching)
        _buildWorksListCard(),
        const SizedBox(height: 16),

        _buildSiteImagesCard(context),
        const SizedBox(height: 16),

        _buildSectionCard(
          icon: Icons.map_outlined,
          title: 'Site Location',
          child: Column(
            children: [
              _buildInfoRow('Place', widget.temple['place'] ?? 'N/A'),
              _buildInfoRow('Taluk', widget.temple['taluk'] ?? 'N/A'),
              _buildInfoRow('District', widget.temple['district'] ?? 'N/A'),
              _buildInfoRow('Coordinates', widget.temple['mapLocation'] ?? 'N/A'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildContactBudgetCard(),
        const SizedBox(height: 24),

        if (status == 'pending') _buildPendingActions(context),
        if (status == 'ongoing') _buildCompletionAction(context),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWorksListCard() {
    final List<dynamic> works = widget.temple['works'] ?? [];

    return _buildSectionCard(
      icon: Icons.engineering_outlined,
      title: 'Proposed Works',
      child: works.isEmpty
          ? const Text('No specific works listed.', style: TextStyle(color: Colors.grey))
          : Column(
              children: works.map((work) {
                final w = Map<String, dynamic>.from(work);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: maroonDeep.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: maroonDeep.withOpacity(0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (w['workImageUrl'] != null && w['workImageUrl'] != "")
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenImageViewer(source: w['workImageUrl']))),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(w['workImageUrl'], width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image)),
                          ),
                        )
                      else
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w['workName'] ?? 'Unnamed Work', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: maroonDeep)),
                            const SizedBox(height: 4),
                            Text(w['workDescription'] ?? 'No description', style: TextStyle(fontSize: 12, color: textDark.withOpacity(0.7))),
                            if (w['amount'] != null && w['amount'] != "")
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text("Est: ₹${w['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: successGreen)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // --- Actions and Budget Trackers ---

  Widget _buildBudgetTracker() {
    final projectId = _getProjectId();
    final double estimated = double.tryParse(widget.temple['estimatedAmount']?.toString() ?? '0') ?? 0.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').doc(projectId).collection('expenses').orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();

        double totalSpent = 0.0;
        final expenses = snapshot.data!.docs;
        for (var doc in expenses) {
          totalSpent += (doc['amount'] as num).toDouble();
        }

        double percentage = estimated > 0 ? (totalSpent / estimated) : 0.0;
        Color progressColor = totalSpent > estimated ? Colors.red : (percentage > 0.8 ? Colors.orange : successGreen);

        return _buildSectionCard(
          icon: Icons.payments_outlined,
          title: 'Budget Utilization',
          child: Column(
            children: [
              LinearProgressIndicator(value: percentage.clamp(0.0, 1.0), minHeight: 10, borderRadius: BorderRadius.circular(10), backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(progressColor)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Utilized: ₹${totalSpent.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: progressColor)),
                  Text('Total: ₹${estimated.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 24),
              if (expenses.isNotEmpty) ...[
                 _buildExpenseMiniList(expenses),
                 const SizedBox(height: 12),
              ],
              _buildAddExpenseButton(projectId),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseMiniList(List<QueryDocumentSnapshot> docs) {
    return Column(
      children: docs.take(3).map((d) {
        final data = d.data() as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data['description'] ?? 'Work Item', style: const TextStyle(fontSize: 12)),
              Text('- ₹${data['amount']}', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddExpenseButton(String projectId) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showAddExpenseDialog(context, projectId),
        icon: const Icon(Icons.add),
        label: const Text("Record Payment"),
        style: OutlinedButton.styleFrom(foregroundColor: maroonDeep, side: const BorderSide(color: maroonDeep)),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, String projectId) {
    final desc = TextEditingController();
    final amt = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Add Payment Record'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description')),
        TextField(controller: amt, decoration: const InputDecoration(labelText: 'Amount (₹)'), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (desc.text.isNotEmpty && amt.text.isNotEmpty) {
            await FirebaseFirestore.instance.collection('projects').doc(projectId).collection('expenses').add({
              'description': desc.text,
              'amount': double.parse(amt.text),
              'date': FieldValue.serverTimestamp(),
            });
            Navigator.pop(context);
          }
        }, style: ElevatedButton.styleFrom(backgroundColor: maroonDeep), child: const Text('Add')),
      ],
    ));
  }

  Widget _buildCompletionAction(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _handleCompletion(context),
      icon: const Icon(Icons.check_circle),
      label: const Text("MARK AS COMPLETED"),
      style: ElevatedButton.styleFrom(
        backgroundColor: successGreen, foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleCompletion(BuildContext context) async {
    final confirm = await _showDialog(context, 'Complete Project', 'Has all work been verified and completed?', successGreen);
    if (confirm == true) {
      final id = _getProjectId();
      await FirebaseFirestore.instance.collection('projects').doc(id).update({'status': 'completed'});
      setState(() => widget.temple['status'] = 'completed');
      widget.onUpdated(widget.temple);
    }
  }

  // --- UI Helpers ---

  Widget _buildSectionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [Icon(icon, color: maroonLight, size: 20), const SizedBox(width: 8), Text(title, style: GoogleFonts.philosopher(fontWeight: FontWeight.bold, fontSize: 17, color: maroonDeep))]),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
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
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textDark))),
        ],
      ),
    );
  }

  Widget _buildPendingActions(BuildContext context) {
    return Row(children: [
      Expanded(child: ElevatedButton(onPressed: () => _handleSanction(context), style: ElevatedButton.styleFrom(backgroundColor: successGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('SANCTION'))),
      const SizedBox(width: 12),
      Expanded(child: OutlinedButton(onPressed: widget.onDeleted, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('REJECT'))),
    ]);
  }

  void _handleSanction(BuildContext context) async {
    final confirm = await _showDialog(context, 'Sanction Project', 'Is the budget and scope verified?', successGreen);
    if (confirm == true) {
      final id = _getProjectId();
      await FirebaseFirestore.instance.collection('projects').doc(id).update({'isSanctioned': true, 'status': 'ongoing'});
      setState(() { widget.temple['isSanctioned'] = true; widget.temple['status'] = 'ongoing'; });
      widget.onUpdated(widget.temple);
    }
  }

  Future<bool?> _showDialog(BuildContext context, String title, String msg, Color color) {
    return showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(title, style: GoogleFonts.philosopher(fontWeight: FontWeight.bold)),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: color), child: const Text('Confirm')),
      ],
    ));
  }

  Widget _buildChatTab() {
    final id = _getProjectId();
    return id.isEmpty ? const Center(child: Text("Chat Unavailable")) : ProjectChatSection(projectId: id, currentRole: 'admin');
  }

  Widget _buildHeader(BuildContext context, String status) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [maroonDeep, maroonLight]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios, color: goldAccent, size: 20)),
            const SizedBox(height: 20),
            Text(widget.temple['name'] ?? 'Project Details', style: GoogleFonts.philosopher(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            Text('STATUS: ${status.toUpperCase()}', style: const TextStyle(color: goldAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSiteImagesCard(BuildContext context) {
    final List<dynamic> images = widget.temple['imageUrls'] ?? [];
    return _buildSectionCard(
      icon: Icons.photo_library_outlined,
      title: 'Site Gallery',
      child: images.isEmpty ? const Text("No site images uploaded") : SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenImageViewer(source: images[i]))),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 120,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(images[i]), fit: BoxFit.cover)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactBudgetCard() {
    final double amount = double.tryParse(widget.temple['estimatedAmount']?.toString() ?? '0') ?? 0.0;
    return _buildSectionCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Budget Info',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ESTIMATED BUDGET', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              IconButton(onPressed: () => setState(() => _isEditingAmount = !_isEditingAmount), icon: Icon(_isEditingAmount ? Icons.close : Icons.edit, size: 18)),
            ],
          ),
          if (_isEditingAmount)
            Row(children: [
              Expanded(child: TextField(controller: _amountController, keyboardType: TextInputType.number)),
              IconButton(onPressed: _updateEstimatedAmount, icon: const Icon(Icons.check, color: Colors.green))
            ])
          else
            Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.philosopher(fontSize: 28, fontWeight: FontWeight.bold, color: maroonDeep)),
        ],
      ),
    );
  }

  void _updateEstimatedAmount() async {
    final id = _getProjectId();
    await FirebaseFirestore.instance.collection('projects').doc(id).update({'estimatedAmount': _amountController.text});
    setState(() { widget.temple['estimatedAmount'] = _amountController.text; _isEditingAmount = false; });
  }
}

// ---------------- FULLSCREEN IMAGE VIEWER ----------------
class FullscreenImageViewer extends StatelessWidget {
  final String source;
  const FullscreenImageViewer({Key? key, required this.source}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: source.startsWith('http') 
            ? Image.network(source, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Icon(Icons.broken_image, color: Colors.white))
            : const Icon(Icons.image, color: Colors.white),
        ),
      ),
    );
  }
}