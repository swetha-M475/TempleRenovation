import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'project_chat_section.dart';

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
  int selectedTab = 0; // Updated to handle 4 tabs

  final TextEditingController _godNameController = TextEditingController();
  final TextEditingController _visitorsController = TextEditingController();
  final TextEditingController _donatedController = TextEditingController();

  final List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
    _normalizeTransactions();
  }

  void _normalizeTransactions() {
    final existing = temple['transactions'];
    if (existing is List) {
      for (final t in existing) {
        if (t is Map) {
          final raw = t['amount'];
          _transactions.add({
            'amount': raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0.0,
            'description': t['description']?.toString() ?? '',
            'mode': t['mode']?.toString() ?? '',
            'date': t['date']?.toString() ?? '',
          });
        }
      }
    }
  }

  void _handleBackNavigation() {
    temple['transactions'] = _transactions;
    widget.onUpdated(temple);
    Navigator.pop(context);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (temple['name'] ?? 'Temple Project').toString(),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Project: ${temple['projectNumber'] ?? 'N/A'}',
              style: const TextStyle(color: primaryGold, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('Activities', 0),
                  _buildTab('Finances', 1),
                  _buildTab('Payment Process', 2), // New Tab
                  _buildTab('Feedback', 3),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildCurrentTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabContent() {
    switch (selectedTab) {
      case 0:
        return ListView(padding: const EdgeInsets.all(20), children: _buildActivitiesTab());
      case 1:
        return ListView(padding: const EdgeInsets.all(20), children: _buildTransactionsTab());
      case 2:
        return _buildPaymentProcessTab(); // New Tab View
      case 3:
        return ProjectChatSection(projectId: temple['id'], currentRole: 'admin');
      default:
        return Container();
    }
  }

  Widget _buildTab(String label, int index) {
    final isActive = selectedTab == index;
    return InkWell(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        width: MediaQuery.of(context).size.width / 3.5, // Adjusted for 4 tabs
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isActive ? primaryGold : Colors.transparent, width: 3)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? primaryMaroon : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // --- PAYMENT PROCESS TAB ---
  Widget _buildPaymentProcessTab() {
    // Dummy values for demonstration - Replace with Firestore data
    double totalBudget = 500000;
    double amountPaid = 320000;
    double percentage = amountPaid / totalBudget;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Budget Utilization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Budget', style: TextStyle(color: Colors.grey)),
                    Text('₹$totalBudget', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon)),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: backgroundCream,
                  color: primaryGold,
                  minHeight: 10,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(percentage * 100).toStringAsFixed(1)}% Paid', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                    Text('Remaining: ₹${totalBudget - amountPaid}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Milestone Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
          const SizedBox(height: 12),
          _buildMilestoneItem('Foundation Completion', '₹1,00,000', true),
          _buildMilestoneItem('Main Pillar Work', '₹1,50,000', true),
          _buildMilestoneItem('Roofing & Finishes', '₹2,50,000', false),
        ],
      ),
    );
  }

  Widget _buildMilestoneItem(String title, String amount, bool isDone) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.grey),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, decoration: isDone ? TextDecoration.lineThrough : null)),
        trailing: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Keep your existing _buildActivitiesTab, _buildTransactionsTab, and _buildInputField here...
  List<Widget> _buildActivitiesTab() {
    return [
      const Text('Daily Work Update', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText)),
      const SizedBox(height: 20),
      _buildInputField(_godNameController, 'Name of God', Icons.auto_awesome),
      const SizedBox(height: 16),
      _buildInputField(_visitorsController, 'Visitors Count', Icons.people, isNum: true),
      const SizedBox(height: 16),
      _buildInputField(_donatedController, 'Amount Donated (₹)', Icons.currency_rupee, isNum: true),
      const SizedBox(height: 30),
      ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryMaroon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('SAVE ACTIVITY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    ];
  }

  List<Widget> _buildTransactionsTab() {
    return [
      const Text('Finances', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText)),
      const SizedBox(height: 10),
      if (_transactions.isEmpty)
        const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No transactions recorded.')))
      else
        ..._transactions.map((tx) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          child: ListTile(
            title: Text('₹${tx['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(tx['description']),
            trailing: const Icon(Icons.chevron_right),
          ),
        )),
    ];
  }

  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryMaroon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDEE2E6))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryGold, width: 2)),
      ),
    );
  }
}