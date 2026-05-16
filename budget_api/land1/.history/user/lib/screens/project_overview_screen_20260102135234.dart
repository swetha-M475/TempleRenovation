import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectOverviewScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const ProjectOverviewScreen({
    Key? key,
    required this.projectId,
    required this.projectName,
  }) : super(key: key);

  @override
  State<ProjectOverviewScreen> createState() => _ProjectOverviewScreenState();
}

class _ProjectOverviewScreenState extends State<ProjectOverviewScreen> {
  // --- Theme Colors ---
  static const Color primaryMaroon = Color(0xFF6D1B1B);
  static const Color backgroundCream = Color(0xFFFFF7E8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        title: Text(widget.projectName, style: GoogleFonts.poppins(color: Colors.white)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadSection(),
            const SizedBox(height: 30),
            Text(
              "Recent Uploads",
              style: GoogleFonts.poppins(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: primaryMaroon
              ),
            ),
            const SizedBox(height: 12),
            _buildUserBillHistory(),
          ],
        ),
      ),
    );
  }

  // --- 1. UPLOAD BUTTON SECTION ---
  Widget _buildUploadSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 50, color: primaryMaroon),
          const SizedBox(height: 10),
          Text("Have a new bill?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () {
              // Trigger your existing showUploadBillDialog here
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryMaroon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("UPLOAD BILL", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 2. LIVE BILL HISTORY SECTION ---
  Widget _buildUserBillHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bills')
          .where('projectId', isEqualTo: widget.projectId)
          // Note: If index is not created yet, comment out orderBy below
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryMaroon));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text("No bills uploaded yet.", style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final bill = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: backgroundCream,
                  child: Icon(Icons.receipt_long, color: primaryMaroon),
                ),
                title: Text(
                  bill['title'] ?? 'Untitled Bill',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("₹${bill['amount']}", style: const TextStyle(color: Colors.green)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 3. DELETE LOGIC ---
  Future<void> _confirmDelete(String docId) async {
    bool? proceed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Bill?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("This will permanently remove the bill from the site and the Admin's records."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (proceed == true) {
      try {
        await FirebaseFirestore.instance.collection('bills').doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bill removed successfully")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting: $e")),
        );
      }
    }
  }
}