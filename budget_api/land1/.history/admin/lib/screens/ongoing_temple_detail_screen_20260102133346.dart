import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'project_chat_section.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  // --- Aranpani Theme Colors ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);

  late Map<String, dynamic> temple;
  int selectedTab = 0;

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
  void dispose() {
    _godNameController.dispose();
    _visitorsController.dispose();
    _donatedController.dispose();
    super.dispose();
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
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('Activities', 0),
                  _buildTab('Finances', 1),
                  _buildTab('Payment Process', 2),
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
        return _buildPaymentProcessTab();
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
        width: MediaQuery.of(context).size.width / 3.2,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: isActive ? primaryGold : Colors.transparent, width: 3),
          ),
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
    double totalBudget = 500000; 
    double amountPaid = 320000;
    double percentage = amountPaid / totalBudget;

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        const Text('Budget Utilization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText)),
        const SizedBox(height: 16),
        _buildBudgetCard(totalBudget, amountPaid, percentage),
        
        const SizedBox(height: 24),
        const Text('Live Site Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
        const SizedBox(height: 12),
        
        // --- IMPROVED STREAMBUILDER WITH ERROR CATCHING ---
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bills')
              .where('projectId', isEqualTo: temple['id'])
              // NOTE: If you haven't clicked the index link in your logs yet,
              // comment out the line below to see data immediately.
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryMaroon));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState('No bills uploaded by user yet.');
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final billData = doc.data() as Map<String, dynamic>;
                return _buildBillCard(billData);
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),
        const Text('Milestone Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
        const SizedBox(height: 12),
        _buildMilestoneItem('Foundation Completion', '₹1,00,000', true),
        _buildMilestoneItem('Main Pillar Work', '₹1,50,000', true),
        _buildMilestoneItem('Roofing & Finishes', '₹2,50,000', false),
      ],
    );
  }

  // --- UI HELPER COMPONENTS ---

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
      child: Text(
        "Database Error: $error\n\nTip: Check if you need to create a Firestore Index via the link in your console.",
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  Widget _buildBudgetCard(double total, double paid, double percent) {
    return Container(
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
              Text('₹$total', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: backgroundCream,
            color: primaryGold,
            minHeight: 10,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(percent * 100).toStringAsFixed(1)}% Paid', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
              Text('Rem: ₹${total - paid}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final List<dynamic> images = bill['imageUrls'] ?? [];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        iconColor: primaryMaroon,
        collapsedIconColor: primaryMaroon,
        title: Text(bill['title'] ?? 'Bill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text('₹${bill['amount']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        children: [
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _showImagePreview(images[index]),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[index], 
                            width: 100, 
                            height: 100, 
                            fit: BoxFit.cover,
                            errorBuilder: (context, obj, stack) => const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showImagePreview(String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, anim1, anim2) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: Center(
            child: InteractiveViewer(child: Image.network(url)),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Center(child: Text(msg, style: const TextStyle(color: Colors.grey))),
    );
  }

  // --- ACTIVITIES TAB ---
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

  // --- FINANCES TAB ---
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
}