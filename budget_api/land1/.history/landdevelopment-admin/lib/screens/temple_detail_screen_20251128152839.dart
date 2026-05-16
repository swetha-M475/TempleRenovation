import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class TempleDetailScreen extends StatefulWidget {
  final String templeId;
  final Map<String, dynamic>? initialTempleData;

  const TempleDetailScreen({
    Key? key,
    required this.templeId,
    this.initialTempleData,
  }) : super(key: key);

  @override
  State<TempleDetailScreen> createState() => _TempleDetailScreenState();
}

class _TempleDetailScreenState extends State<TempleDetailScreen> {
  Map<String, dynamic>? temple;
  bool isLoading = true;

  int selectedTab = 0; // activities / bills / suggestions

  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> bills = [];
  List<String> suggestions = [];

  final TextEditingController _suggestionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _suggestionController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);

    // Project main data
    temple = await FirebaseService.getTempleById(widget.templeId);

    // Load subcollections
    activities = await FirebaseService.getActivities(widget.templeId);
    transactions = await FirebaseService.getTransactions(widget.templeId);
    bills = await FirebaseService.getBills(widget.templeId);
    suggestions = await FirebaseService.getSuggestions(widget.templeId);

    setState(() => isLoading = false);
  }

  Future<void> _handleSanction() async {
    final confirm = await _confirmDialog(
      title: "Sanction Project",
      message: "Do you want to approve this project?",
      positive: "Sanction",
    );

    if (confirm == true) {
      await FirebaseService.sanctionProject(widget.templeId);

      setState(() {
        temple!['status'] = 'ongoing';
      });

      Navigator.pop(context, temple);
    }
  }

  Future<void> _handleReject() async {
    final confirm = await _confirmDialog(
      title: "Reject Project",
      message:
          "Are you sure you want to reject this project? This action cannot be undone.",
      positive: "Reject",
      positiveColor: Colors.red,
    );

    if (confirm == true) {
      await FirebaseService.rejectProject(widget.templeId);
      Navigator.pop(context, null); // tells list to remove it
    }
  }

  Future<void> _handleMarkComplete() async {
    final confirm = await _confirmDialog(
      title: "Mark Project Completed",
      message: "Do you want to mark this project as completed?",
      positive: "Mark Completed",
    );

    if (confirm == true) {
      await FirebaseService.markProjectCompleted(widget.templeId);

      setState(() {
        temple!['status'] = 'completed';
        temple!['completedDate'] = DateTime.now().toString();
      });

      Navigator.pop(context, temple);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String positive,
    Color positiveColor = Colors.green,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: positiveColor),
            child: Text(positive),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

  Future<void> _addSuggestion() async {
    final text = _suggestionController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter suggestion')));
      return;
    }

    await FirebaseService.addSuggestion(widget.templeId, text);

    setState(() {
      suggestions.add(text);
    });

    _suggestionController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Suggestion sent")));
  }

  Future<void> _addTransaction() async {
    final amountController = TextEditingController();
    final detailsController = TextEditingController();
    String mode = "cash";

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Transaction"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount (₹)"),
              ),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 10),
              RadioListTile(
                value: "cash",
                groupValue: mode,
                title: const Text("Cash"),
                onChanged: (v) => setDialogState(() => mode = v.toString()),
              ),
              RadioListTile(
                value: "online",
                groupValue: mode,
                title: const Text("Online Payment"),
                onChanged: (v) => setDialogState(() => mode = v.toString()),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Add"),
              onPressed: () async {
                if (amountController.text.isEmpty ||
                    detailsController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Fill all fields")),
                  );
                  return;
                }

                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid amount")),
                  );
                  return;
                }

                await FirebaseService.addTransaction(
                  widget.templeId,
                  amount,
                  detailsController.text,
                  mode,
                );

                transactions = await FirebaseService.getTransactions(
                  widget.templeId,
                );

                setState(() {});

                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markActivityCompleted(String activityId) async {
    await FirebaseService.markActivityCompleted(widget.templeId, activityId);
    activities = await FirebaseService.getActivities(widget.templeId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final status = temple!['status'];

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, temple);
        return false;
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(),
            if (status == 'ongoing') _buildTabs(),

            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildUserInfoCard(),
                      const SizedBox(height: 16),

                      if (status == 'pending') ..._buildPending(),
                      if (status == 'ongoing') ..._buildOngoing(),
                      if (status == 'completed') ..._buildCompleted(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final status = temple!['status'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context, temple),
            ),
            Text(
              temple!['name'],
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text(
              status.toUpperCase(),
              style: const TextStyle(color: Color(0xFFC7D2FE)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _tab("Activities", 0),
        _tab("Bills", 1),
        _tab("Suggestions", 2),
      ],
    );
  }

  Widget _tab(String label, int index) {
    final active = selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? const Color(0xFF4F46E5) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? const Color(0xFF4F46E5) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "User Details",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _info("Name", temple!['userName']),
            _info("Email", temple!['userEmail']),
            _info("Phone", temple!['userPhone']),
            _info("Aadhar", temple!['userAadhar']),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPending() {
    return [
      _buildSiteImages(),
      const SizedBox(height: 16),

      Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _handleSanction,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Sanction"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _handleReject,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Reject"),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildOngoing() {
    if (selectedTab == 0) {
      return [
        _buildSiteImages(),
        const SizedBox(height: 16),
        _buildActivityList(),
        const SizedBox(height: 16),
        _buildTransactions(),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _handleMarkComplete,
          child: const Text("Mark Project Completed"),
        ),
      ];
    } else if (selectedTab == 1) {
      return [_buildBills()];
    } else {
      return [_buildSuggestions(), _buildAddSuggestion()];
    }
  }

  List<Widget> _buildCompleted() {
    return [
      _buildSiteImages(),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Project Completed on: ${temple!['completedDate']}",
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildSiteImages() {
    final images = List<String>.from(temple!['siteImages'] ?? []);
    if (images.isEmpty) {
      return const Text("No site images");
    }

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(images[i], width: 240, fit: BoxFit.cover),
          );
        },
      ),
    );
  }

  Widget _buildActivityList() {
    if (activities.isEmpty) {
      return const Text("No activities yet");
    }

    return Card(
      child: Column(
        children: activities.map((a) {
          final completed = a['status'] == 'completed';
          return ListTile(
            title: Text(a['title']),
            subtitle: Text(a['date']),
            trailing: completed
                ? const Icon(Icons.check_circle, color: Colors.green)
                : ElevatedButton(
                    onPressed: () => _markActivityCompleted(a['id']),
                    child: const Text("Complete"),
                  ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactions() {
    final total = transactions.fold<double>(
      0,
      (prev, t) => prev + (t['amount'] ?? 0.0),
    );

    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text("Transactions"),
            subtitle: Text("Total spent: ₹${total.toStringAsFixed(0)}"),
            trailing: ElevatedButton(
              onPressed: _addTransaction,
              child: const Text("Add"),
            ),
          ),
          ...transactions.map((t) {
            return ListTile(
              title: Text("₹${t['amount']} • ${t['description']}"),
              subtitle: Text("${t['paymentMode']} • ${t['date']}"),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBills() {
    if (bills.isEmpty) {
      return const Text("No bills uploaded");
    }

    return Card(
      child: Column(
        children: bills.map((b) {
          return ListTile(
            title: Text(b['title']),
            subtitle: Text("₹${b['amount']} • ${b['date']}"),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (suggestions.isEmpty) {
      return const Text("No suggestions yet");
    }

    return Card(
      child: Column(
        children: suggestions.map((s) {
          return ListTile(
            leading: const Icon(Icons.message, color: Color(0xFF4F46E5)),
            title: Text(s),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddSuggestion() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Add Suggestion"),
            const SizedBox(height: 12),
            TextField(
              controller: _suggestionController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Type suggestion...",
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addSuggestion,
              child: const Text("Send"),
            ),
          ],
        ),
      ),
    );
  }
}
