import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ProjectOverviewScreen extends StatefulWidget {
  // FIX: Added the 'project' parameter to the constructor
  final Map<String, dynamic> project;
  const ProjectOverviewScreen({super.key, required this.project});

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  bool _isScanning = false;

  // Replace with your actual Gemini API Key from Google AI Studio
  final String _apiKey = "YOUR_GEMINI_API_KEY";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  // AI Logic to parse the bill image
  Future<void> _scanBillWithAI() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _isScanning = true);

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final bytes = await photo.readAsBytes();
      
      final prompt = TextPart(
        "Extract the Store Name and Total Amount from this bill. "
        "Return ONLY a JSON object: {'name': 'string', 'amount': double}."
      );
      
      final response = await model.generateContent([
        Content.multi([prompt, DataPart('image/jpeg', bytes)])
      ]);

      if (mounted) _showResultDialog(response.text ?? "{}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showResultDialog(String jsonStr) {
    // Clean JSON string if AI adds markdown backticks
    final cleanJson = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();
    final Map<String, dynamic> data = jsonDecode(cleanJson);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("AI Scanned Bill"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text("Vendor"), subtitle: Text(data['name'] ?? "Unknown")),
            ListTile(title: const Text("Amount"), subtitle: Text("₹${data['amount'] ?? '0.00'}")),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Save"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access the project data using 'widget.project'
    final String projectName = widget.project['place'] ?? "Project Overview";

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Work"), Tab(text: "Txn"), Tab(text: "Bills"), Tab(text: "Chat")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          const Center(child: Text("Transaction History")),
          _buildBillsTab(),
          const Center(child: Text("Project Chat")),
        ],
      ),
      floatingActionButton: _tabController.index == 2 
        ? FloatingActionButton.extended(
            onPressed: _isScanning ? null : _scanBillWithAI,
            label: Text(_isScanning ? "Reading..." : "Scan Bill"),
            icon: const Icon(Icons.document_scanner),
          ) 
        : null,
    );
  }

  Widget _buildActivityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Recent Progress", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const Card(child: ListTile(title: Text("Foundation Work"), subtitle: Text("Completed on Dec 28"))),
      ],
    );
  }

  Widget _buildBillsTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text("No bills uploaded yet", style: GoogleFonts.poppins(color: Colors.grey)),
      ],
    );
  }
}