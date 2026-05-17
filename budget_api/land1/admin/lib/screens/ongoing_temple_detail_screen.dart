import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

// Ensure this file exists in your project for the Feedback tab
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
  // --- Theme Tokens ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundCream = Color(0xFFFFF7E8);
  static const Color darkMaroonText = Color(0xFF4A1010);
  static const Color successGreen = Color(0xFF2D6A4F);

  late Map<String, dynamic> temple;
  int selectedTab = 0;
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    temple = Map<String, dynamic>.from(widget.temple);
  }

  void _handleBackNavigation() {
    widget.onUpdated(temple);
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "N/A";
    DateTime date = timestamp.toDate();
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return "Select Date";
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  // --- AI Comparison Logic ---

  Future<void> _compareImages(String originalUrl, List<dynamic> allCompletedUrls) async {
    bool isAnalyzing = true;
    double avgSsim = 0.0;
    List<String> allChanges = [];
    String combinedInterpretation = "";
    String? firstDiffBase64;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          Future<void> runBatchAnalysis() async {
            try {
              final resp1 = await http.get(Uri.parse(originalUrl));
              double totalSsim = 0.0;

              for (int i = 0; i < allCompletedUrls.length; i++) {
                final resp2 = await http.get(Uri.parse(allCompletedUrls[i]));

                final request = http.MultipartRequest('POST', Uri.parse('http://192.168.186.51:5000/api/compare'));
                request.files.add(http.MultipartFile.fromBytes('image1', resp1.bodyBytes, filename: 'orig.jpg', contentType: MediaType('image', 'jpeg')));
                request.files.add(http.MultipartFile.fromBytes('image2', resp2.bodyBytes, filename: 'prog.jpg', contentType: MediaType('image', 'jpeg')));

                final streamedResponse = await request.send();
                final response = await http.Response.fromStream(streamedResponse);

                if (response.statusCode == 200) {
                  final analysisData = json.decode(response.body);
                  
                  final ssimData = analysisData['ssim'] ?? {};
                  totalSsim += (ssimData['ssim_score'] ?? 0.0);
                  
                  final changes = analysisData['changes'] ?? {};
                  final changeSummary = changes['change_summary'] ?? "";
                  
                  if (changeSummary.toString().isNotEmpty && changeSummary != "..." && changeSummary.toString().toLowerCase() != "none" && changeSummary.toString() != "No changes detected.") {
                     allChanges.add("Photo ${i + 1}: $changeSummary");
                  }

                  if (firstDiffBase64 == null) {
                    firstDiffBase64 = analysisData['diff_image_base64'];
                    combinedInterpretation = ssimData['interpretation'] ?? "...";
                  }
                } else {
                  throw "API Error: ${response.statusCode}";
                }
              }

              setDialogState(() {
                avgSsim = (totalSsim / allCompletedUrls.length) * 100;
                if (allChanges.isEmpty) {
                  allChanges.add("No major structural deviations found across all photos.");
                }
                isAnalyzing = false;
              });

            } catch (e) {
              if (context.mounted) {
                setDialogState(() => isAnalyzing = false);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Analysis failed: $e")));
              }
            }
          }

          // Run once
          if (isAnalyzing && avgSsim == 0.0 && allChanges.isEmpty) {
             runBatchAnalysis();
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 10),
                const Expanded(child: Text("Batch Progress Analysis")),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Analyzing ${allCompletedUrls.length} photos against baseline...", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allCompletedUrls.length,
                        itemBuilder: (ctx, i) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.network(allCompletedUrls[i], width: 60, height: 60, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isAnalyzing) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 10),
                      const Center(child: Text("Running multi-image structural comparison...", style: TextStyle(fontSize: 12, color: Colors.grey))),
                    ] else ...[
                      // AI RESULTS SUMMARY
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade100)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("AI Analysis Summary", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            const SizedBox(height: 8),
                            Text("Avg Match Score: ${avgSsim.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text("Status: $combinedInterpretation", style: const TextStyle(fontSize: 13)),
                            const Divider(),
                            const Text("Structural Changes Detected:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            ...allChanges.map((change) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text("• $change", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            )).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      if (firstDiffBase64 != null) ...[
                        const Text("Heatmap (First Image):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(base64Decode(firstDiffBase64!), height: 180, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ]
                    ]
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              )
            ],
          );
        },
      ),
    );
  }

  // --- Project Actions ---

  Future<void> _deleteProject() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Project?"),
        content: const Text(
          "This will permanently delete this project, all associated tasks, and bills. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isDeleting = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final String projectId = temple['id'];

      final tasksQuery = await FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: projectId)
          .get();
      for (var doc in tasksQuery.docs) {
        batch.delete(doc.reference);
      }

      final billsQuery = await FirebaseFirestore.instance
          .collection('bills')
          .where('projectId', isEqualTo: projectId)
          .get();
      for (var doc in billsQuery.docs) {
        batch.delete(doc.reference);
      }

      final projectRef =
          FirebaseFirestore.instance.collection('projects').doc(projectId);
      batch.delete(projectRef);

      await batch.commit();

      widget.onUpdated(null);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Project deleted successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting project: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  Future<void> _markProjectCompleted() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark Project as Completed?"),
        content: const Text(
          "This will mark the entire project as completed and move it to the Completed tab.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "MARK COMPLETED",
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final String projectId = temple['id'] ?? temple['projectId'];
      if (projectId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({
        'status': 'completed',
        'progress': 100,
        'completedDate': FieldValue.serverTimestamp(),
      });

      temple['status'] = 'completed';
      temple['progress'] = 100;

      widget.onUpdated(temple);

      if (mounted) {
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error marking project completed: $e")),
        );
      }
    }
  }

  // --- Finance Update Logic ---

  Future<void> _saveWorkFinanceDetails(int index, Map<String, dynamic> updatedWorkDetails, List<dynamic> allWorks) async {
    try {
      List<dynamic> updatedWorks = List.from(allWorks);
      // Merge old data with new data
      updatedWorks[index] = {
        ...updatedWorks[index],
        ...updatedWorkDetails,
      };

      // Recalculate total amount from all works
      double newTotal = 0;
      for (var w in updatedWorks) {
        newTotal += double.tryParse(w['amount']?.toString() ?? '0') ?? 0;
      }

      double currentEstimated = double.tryParse(temple['estimatedAmount']?.toString() ?? '0') ?? 0.0;
      
      // Update payload creation
      Map<String, dynamic> updatePayload = {
        'works': updatedWorks,
      };

      // LOGIC: If new calculated total exceeds current approved budget, update the total approved budget.
      // If it is less than or equal to current approved budget, do not change total approved budget.
      if (newTotal > currentEstimated) {
        updatePayload['estimatedAmount'] = newTotal.toStringAsFixed(2);
        temple['estimatedAmount'] = newTotal.toStringAsFixed(2);
      }

      final String projectId = temple['id'] ?? temple['projectId'];
      await FirebaseFirestore.instance.collection('projects').doc(projectId).update(updatePayload);

      setState(() {
        temple['works'] = updatedWorks;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Work finance updated successfully"), backgroundColor: successGreen),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating finance: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showFinanceUpdateDialog(int index, Map<String, dynamic> work, List<dynamic> allWorks) {
    final TextEditingController amtCtrl = TextEditingController(text: work['amount']?.toString() ?? "");
    String method = work['distributionMethod'] ?? 'amount_sent'; 
    final TextEditingController txnIdCtrl = TextEditingController(text: work['transactionId']?.toString() ?? "");
    
    DateTime? transDate = work['transactionDate'] != null ? (work['transactionDate'] as Timestamp).toDate() : null;
    DateTime? requestDate = work['requestDate'] != null ? (work['requestDate'] as Timestamp).toDate() : null;
    DateTime? dateSent = work['dateSent'] != null ? (work['dateSent'] as Timestamp).toDate() : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            Future<void> pickDate(DateTime? initial, Function(DateTime) onPicked) async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: initial ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) setDialogState(() => onPicked(picked));
            }

            return AlertDialog(
              title: Text("Update Finance Info", style: GoogleFonts.philosopher(fontWeight: FontWeight.bold, color: primaryMaroon)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: amtCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Allocated Amount (₹)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    const Text("Distribution Method:", style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<String>(
                      title: const Text("Amount Sent to User", style: TextStyle(fontSize: 14)),
                      value: "amount_sent",
                      groupValue: method,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryMaroon,
                      onChanged: (val) => setDialogState(() => method = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text("Requirement Distributed (By Admin)", style: TextStyle(fontSize: 14)),
                      value: "req_distributed",
                      groupValue: method,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryMaroon,
                      onChanged: (val) => setDialogState(() => method = val!),
                    ),
                    const Divider(),
                    
                    // Fields for "Amount Sent"
                    if (method == "amount_sent") ...[
                      TextField(
                        controller: txnIdCtrl,
                        decoration: const InputDecoration(labelText: "Transaction ID", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Transaction Date", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        subtitle: Text(_formatDateTime(transDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: const Icon(Icons.calendar_today, color: primaryMaroon),
                        onTap: () => pickDate(transDate, (date) => transDate = date),
                      ),
                    ] 
                    // Fields for "Requirement Distributed"
                    else ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Request Date", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        subtitle: Text(_formatDateTime(requestDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: const Icon(Icons.calendar_today, color: primaryMaroon),
                        onTap: () => pickDate(requestDate, (date) => requestDate = date),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Date Sent (Dispatched)", style: TextStyle(fontSize: 14, color: Colors.grey)),
                        subtitle: Text(_formatDateTime(dateSent), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: const Icon(Icons.local_shipping, color: primaryMaroon),
                        onTap: () => pickDate(dateSent, (date) => dateSent = date),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
                  onPressed: () {
                    Map<String, dynamic> updateData = {
                      'amount': amtCtrl.text.trim(),
                      'distributionMethod': method,
                    };

                    if (method == "amount_sent") {
                      updateData['transactionId'] = txnIdCtrl.text.trim();
                      updateData['transactionDate'] = transDate != null ? Timestamp.fromDate(transDate!) : null;
                      // Clear alternative fields
                      updateData['requestDate'] = null;
                      updateData['dateSent'] = null;
                    } else {
                      updateData['requestDate'] = requestDate != null ? Timestamp.fromDate(requestDate!) : null;
                      updateData['dateSent'] = dateSent != null ? Timestamp.fromDate(dateSent!) : null;
                      // Clear alternative fields
                      updateData['transactionId'] = null;
                      updateData['transactionDate'] = null;
                    }

                    Navigator.pop(context);
                    _saveWorkFinanceDetails(index, updateData, allWorks);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // --- Helper Widgets ---

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
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
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

  // --- Main Build ---

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
        // CHANGED: Display the Project ID in the title instead of the project name
        title: Text(
          (temple['projectId'] ?? temple['id'] ?? 'Project Details').toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (isDeleting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteProject,
              tooltip: "Delete Project",
            ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTab('Activities', 0),
                _buildTab('Finances', 1),
                _buildTab('Payment', 2),
                _buildTab('Feedback', 3),
              ],
            ),
          ),
          Expanded(child: _buildCurrentTabContent()),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _markProjectCompleted,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryMaroon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text(
            'Mark Project as Completed',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
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
                width: 3,
              ),
            ),
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
        return _buildFinanceTab(); 
      case 2:
        return _buildPaymentProcessTab();
      case 3:
        return ProjectChatSection(
          projectId: temple['id'],
          currentRole: 'admin',
        );
      default:
        return const Center(child: Text("Content Not Found"));
    }
  }

  // ==========================================
  // TAB 1: FINANCES
  // ==========================================

  Widget _buildFinanceTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(temple['id'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var data = snapshot.data!.data() as Map<String, dynamic>;
        List<dynamic> works = data['works'] ?? [];
        String totalBudget = data['estimatedAmount']?.toString() ?? '0';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryMaroon,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  const Text("Total Sanctioned Budget", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 5),
                  Text(
                    "₹$totalBudget",
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Sanctioned Works & Budgets",
              style: GoogleFonts.philosopher(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: primaryMaroon
              ),
            ),
            const SizedBox(height: 10),
            
            if (works.isEmpty)
               const Padding(
                 padding: EdgeInsets.all(16.0),
                 child: Center(child: Text("No works specified in this project.", style: TextStyle(color: Colors.grey))),
               ),
            ...works.asMap().entries.map((entry) {
              int idx = entry.key;
              Map<String, dynamic> work = Map<String, dynamic>.from(entry.value);
              return _buildWorkFinanceCard(work, idx, works);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildWorkFinanceCard(Map<String, dynamic> work, int index, List<dynamic> allWorks) {
    String method = work['distributionMethod'] ?? '';
    bool hasAmount = work['amount'] != null && work['amount'].toString().trim().isNotEmpty;
    bool isAdditional = work['isAdditional'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryGold.withOpacity(0.3))
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (work['workImageUrl'] != null && work['workImageUrl'] != "")
                  GestureDetector(
                    onTap: () => _showFullScreenImage(work['workImageUrl']),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(work['workImageUrl'], width: 50, height: 50, fit: BoxFit.cover),
                    ),
                  )
                else
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.engineering, color: Colors.grey),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(work['workName'] ?? "Work Item", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkMaroonText)),
                          ),
                          if (isAdditional)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                              child: const Text("Additional", style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      Text(work['workDescription'] ?? "", style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Allocated Amount", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      hasAmount ? "₹ ${work['amount']}" : "Not Set",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: hasAmount ? successGreen : Colors.red),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => _showFinanceUpdateDialog(index, work, allWorks),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Update"),
                  style: OutlinedButton.styleFrom(foregroundColor: primaryMaroon, side: const BorderSide(color: primaryMaroon)),
                )
              ],
            ),

            if (method == 'amount_sent') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.account_balance, size: 14, color: Colors.blue),
                        SizedBox(width: 6),
                        Text("Amount Sent to User", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text("Txn ID: ${work['transactionId'] ?? 'N/A'}", style: const TextStyle(fontSize: 12)),
                    Text("Date: ${_formatTimestamp(work['transactionDate'] as Timestamp?)}", style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )
            ] else if (method == 'req_distributed') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_shipping, size: 14, color: Colors.orange),
                        SizedBox(width: 6),
                        Text("Requirement Distributed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text("Req Date: ${_formatTimestamp(work['requestDate'] as Timestamp?)}", style: const TextStyle(fontSize: 12)),
                    Text("Sent Date: ${_formatTimestamp(work['dateSent'] as Timestamp?)}", style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )
            ] else if (!hasAmount) ...[
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text("* Please update allocation and distribution details.", style: TextStyle(color: Colors.red, fontSize: 10, fontStyle: FontStyle.italic)),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: ACTIVITIES
  // ==========================================

  Widget _buildActivitiesTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryGold.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: primaryMaroon,
                child: Icon(Icons.person_pin_circle, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Local Contact (POC)", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text(temple['localPersonName'] ?? temple['localName'] ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(temple['localPersonPhone'] ?? temple['localPhone'] ?? "N/A", style: const TextStyle(fontSize: 13, color: primaryMaroon)),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: DefaultTabController(
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
                      _buildCompletedList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: temple['id'])
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        
        if (docs.isEmpty) {
          return Center(child: Text("No $status works found", style: const TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(data['taskName'] ?? 'Unknown Work', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Not started yet"),
                trailing: const Icon(Icons.hourglass_empty, color: Colors.orange),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('project_tasks')
          .where('projectId', isEqualTo: temple['id'])
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        
        if (docs.isEmpty) {
          return const Center(child: Text("No completed works", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            Timestamp? start = data['startedAt'];
            Timestamp? end = data['completedAt'];
            String dateText = "Start: ${_formatTimestamp(start)}  -  End: ${_formatTimestamp(end)}";
            List<dynamic> endImages = data['endImages'] ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(data['taskName'] ?? 'Unknown Work', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(dateText, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    if (endImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text("Submitted Photos:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: endImages.length,
                          itemBuilder: (context, imgIndex) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () => _showFullScreenImage(endImages[imgIndex]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(endImages[imgIndex], width: 70, height: 70, fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
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
        
        if (docs.isEmpty) {
          return const Center(child: Text("No ongoing works", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final status = data['status'] ?? 'ongoing';

            Timestamp? startTs = data['startedAt'];
            String dateText = startTs != null ? "Started: ${_formatTimestamp(startTs)}" : "Started: N/A";
            List<dynamic> endImages = data['endImages'] ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                          decoration: BoxDecoration(
                            color: status == 'pending_approval' ? Colors.orange : Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status == 'pending_approval' ? "Pending Approval" : "In Progress",
                            style: TextStyle(color: status == 'pending_approval' ? Colors.white : Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(dateText, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 8),
                    if (endImages.isNotEmpty) ...[
                      const Text("Attached Photos:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: endImages.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () => _showFullScreenImage(endImages[i]),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(endImages[i], width: 80, height: 80, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (status == 'pending_approval') ...[
                      const Divider(),
                      () {
                        final List projectImages = temple['imageUrls'] as List? ?? [];
                        if (endImages.isNotEmpty && projectImages.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _compareImages(
                                  projectImages[0].toString(), 
                                  endImages
                                ),
                                icon: const Icon(Icons.compare, size: 18),
                                label: const Text("Compare & Verify (AI)"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  side: const BorderSide(color: Colors.blue),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => FirebaseFirestore.instance.collection('project_tasks').doc(docId).update({'status': 'ongoing'}),
                            child: const Text("Not Approved", style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => FirebaseFirestore.instance.collection('project_tasks').doc(docId).update({
                              'status': 'completed',
                              'completedAt': FieldValue.serverTimestamp(),
                            }),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text("Approve"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, 
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 2: PAYMENT PROCESS (BILLS)
  // ==========================================

  Widget _buildPaymentProcessTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bills')
          .where('projectId', isEqualTo: temple['id'])
          .snapshots(),
      builder: (context, snapshot) {
        double totalBillsAmount = 0.0;
        List<QueryDocumentSnapshot> billDocs = [];

        if (snapshot.hasData) {
          billDocs = snapshot.data!.docs;
          for (var doc in billDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = double.tryParse(data['amount'].toString()) ?? 0.0;
            totalBillsAmount += amount;
          }
        }

        final sanctionedAmount = double.tryParse(temple['estimatedAmount'].toString()) ?? 1.0; 
        final double progress = (totalBillsAmount / sanctionedAmount).clamp(0.0, 1.0);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Budget Utilization',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkMaroonText),
            ),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, 2), blurRadius: 5)
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sanctioned Budget', style: TextStyle(color: Colors.grey)),
                      Text(
                        '₹${temple['estimatedAmount'] ?? '0'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: primaryMaroon, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Utilized (Bills)', style: TextStyle(color: Colors.grey)),
                      Text(
                        '₹${totalBillsAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: backgroundCream,
                      color: progress > 0.9 ? Colors.red : primaryGold,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "${(progress * 100).toStringAsFixed(1)}% Used",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Text('Bills Uploaded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkMaroonText)),
            const SizedBox(height: 12),
            
            if (!snapshot.hasData)
               const Center(child: CircularProgressIndicator())
            else if (billDocs.isEmpty)
              Container(padding: const EdgeInsets.all(20), child: const Center(child: Text("No bills found.", style: TextStyle(color: Colors.grey))))
            else
              Column(
                children: billDocs.map((doc) {
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(images[i], width: 80, height: 80, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }
}