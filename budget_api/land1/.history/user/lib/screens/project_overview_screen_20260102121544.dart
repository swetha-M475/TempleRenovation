import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProjectOverviewScreen extends StatefulWidget {
  const ProjectOverviewScreen({super.key});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isScanning = false;

  // Replace with your actual Gemini API Key
  final String _apiKey = "YOUR_GEMINI_API_KEY";

  Future<void> _scanBill() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _isScanning = true);

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final bytes = await photo.readAsBytes();

      final prompt =
          TextPart("Extract the following from this receipt in JSON format: "
              "store_name, total_amount, date, and category. "
              "If not found, return 'Unknown'.");

      final content = [
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ];

      final response = await model.generateContent(content);

      // Show results in a bottom sheet
      if (mounted) {
        _showScanResult(response.text ?? "No data found");
      }
    } catch (e) {
      _showError("Failed to scan bill: $e");
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showScanResult(String data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI Receipt Summary",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8)),
              child:
                  Text(data, style: const TextStyle(fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Project Overview",
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildProgressCard(),
            const SizedBox(height: 24),
            _buildSectionTitle("Quick Actions"),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildSectionTitle("Recent Expenses"),
            _buildExpenseList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _scanBill,
        backgroundColor: Colors.blueAccent,
        icon: _isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.document_scanner),
        label: Text(_isScanning ? "Scanning..." : "Scan Bill"),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, MMM d').format(DateTime.now()),
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const Text(
          "Skyline Apartment A",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [Colors.blue[700]!, Colors.blue[400]!]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Overall Completion",
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          const Text("74%",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.74,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _actionIcon(Icons.add_task, "Add Task", Colors.orange),
        _actionIcon(Icons.people, "Team", Colors.purple),
        _actionIcon(Icons.analytics, "Reports", Colors.green),
        _actionIcon(Icons.settings, "Config", Colors.grey),
      ],
    );
  }

  Widget _actionIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildExpenseList() {
    final expenses = [
      {"title": "Cement Supply", "amount": "\$1,200", "date": "Today"},
      {"title": "Labor Payout", "amount": "\$850", "date": "Yesterday"},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
          title: Text(expenses[index]["title"]!),
          subtitle: Text(expenses[index]["date"]!),
          trailing: Text(expenses[index]["amount"]!,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}
