import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class UserCompletedProjectScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const UserCompletedProjectScreen({super.key, required this.project});

  @override
  State<UserCompletedProjectScreen> createState() => _UserCompletedProjectScreenState();
}

class _UserCompletedProjectScreenState extends State<UserCompletedProjectScreen> {
  // Theme Colors matching your project style
  static const Color primaryMaroon = Color(0xFF6A1F1A);
  static const Color darkMaroonText = Color(0xFF4A1010);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color goldAccent = Color(0xFFD4AF37);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> works = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> bills = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllProjectDetails();
  }

  String get _projectId => widget.project['id'] ?? widget.project['projectId'] ?? '';

  Future<void> _loadAllProjectDetails() async {
    if (_projectId.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);
    try {
      // 1. Fetch Completed Activities
      final tasksSnap = await _firestore
          .collection('project_tasks')
          .where('projectId', isEqualTo: _projectId)
          .where('status', isEqualTo: 'completed')
          .get();

      // 2. Fetch Money Transactions
      final transSnap = await _firestore
          .collection('transactions')
          .where('projectId', isEqualTo: _projectId)
          .get();

      // 3. Fetch Uploaded Bills
      final billsSnap = await _firestore
          .collection('bills')
          .where('projectId', isEqualTo: _projectId)
          .get();

      if (mounted) {
        setState(() {
          works = tasksSnap.docs.map((d) => d.data()).toList();
          transactions = transSnap.docs.map((d) => d.data()).toList();
          bills = billsSnap.docs.map((d) => d.data()).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text('Project Detailed Report', 
            style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFFF5E6CA),
        foregroundColor: primaryMaroon,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryMaroon))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusHeader(),
                const SizedBox(height: 12),
                _buildInfoCard(),
                const SizedBox(height: 12),
                _buildFinanceSummaryCard(),
                const SizedBox(height: 12),
                _buildWorksSection(),
                const SizedBox(height: 12),
                _buildTransactionsSection(),
                const SizedBox(height: 12),
                _buildBillsSection(),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildStatusHeader() {
    final status = widget.project['status'] ?? 'completed';
    final isRejected = status == 'archived_rejected';
    return Card(
      color: isRejected ? Colors.red[50] : Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(isRejected ? Icons.archive : Icons.verified_user, 
            color: isRejected ? Colors.red[800] : Colors.green[800]),
        title: Text(isRejected ? "PROPOSAL ARCHIVED" : "PROJECT COMPLETED",
            style: TextStyle(fontWeight: FontWeight.bold, color: isRejected ? Colors.red[900] : Colors.green[900])),
        subtitle: Text("Project ID: $_projectId"),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFFFF2D5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('General Information', 
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: darkMaroonText)),
            const Divider(),
            _infoRow('Temple Name', widget.project['place']),
            _infoRow('Location', "${widget.project['taluk']}, ${widget.project['district']}"),
            _infoRow('Feature', widget.project['feature']),
            _infoRow('Estimated', "₹${widget.project['estimatedAmount']}"),
            _infoRow('Proposed Date', _formatDate(widget.project['dateCreated'])),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceSummaryCard() {
    double totalSpent = bills.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0));
    double totalReceived = transactions.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: darkMaroonText,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Financial Summary', style: GoogleFonts.cinzel(color: goldAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryColumn("Received", "₹${totalReceived.toStringAsFixed(0)}", Colors.green[300]!),
                _summaryColumn("Spent (Bills)", "₹${totalSpent.toStringAsFixed(0)}", Colors.red[300]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorksSection() {
    return _sectionWrapper(
      title: "Works Done",
      icon: Icons.construction,
      content: works.isEmpty 
          ? const Text("No activities recorded.") 
          : Column(
              children: works.map((w) => ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                title: Text(w['taskName'] ?? 'Unnamed Task', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(w['description'] ?? ''),
                trailing: (w['endImages'] != null && (w['endImages'] as List).isNotEmpty)
                    ? IconButton(icon: const Icon(Icons.image), onPressed: () => _showImageGallery(w['endImages']))
                    : null,
              )).toList(),
            ),
    );
  }

  Widget _buildTransactionsSection() {
    return _sectionWrapper(
      title: "Money Transfers",
      icon: Icons.account_balance,
      content: transactions.isEmpty 
          ? const Text("No transaction history.") 
          : Column(
              children: transactions.map((t) => ListTile(
                leading: const Icon(Icons.arrow_downward, color: Colors.blue),
                title: Text("₹${t['amount']}"),
                subtitle: Text(t['title'] ?? t['description'] ?? 'Funds Transfer'),
                trailing: Text(_formatDate(t['date']), style: const TextStyle(fontSize: 10)),
              )).toList(),
            ),
    );
  }

  Widget _buildBillsSection() {
    return _sectionWrapper(
      title: "Verified Bills",
      icon: Icons.receipt_long,
      content: bills.isEmpty 
          ? const Text("No bills found.") 
          : Column(
              children: bills.map((b) => ListTile(
                leading: const Icon(Icons.receipt, color: Colors.orange),
                title: Text(b['title'] ?? 'Bill'),
                subtitle: Text("Amount: ₹${b['amount']}"),
                trailing: const Icon(Icons.remove_red_eye, size: 18),
                onTap: () => _showImageGallery(b['imageUrls']),
              )).toList(),
            ),
    );
  }

  // --- Helper Widgets ---

  Widget _sectionWrapper({required String title, required IconData icon, required Widget content}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: primaryMaroon, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const Divider(),
            content,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _summaryColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    if (timestamp is Timestamp) return DateFormat('dd-MM-yyyy').format(timestamp.toDate());
    return timestamp.toString();
  }

  void _showImageGallery(dynamic urls) {
    final List list = urls is List ? urls : [];
    if (list.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Attachments", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(list[i], width: 220, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}