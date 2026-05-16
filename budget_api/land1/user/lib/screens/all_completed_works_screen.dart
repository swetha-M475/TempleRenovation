import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/user_completed_project_screen.dart';

class AllCompletedWorksScreen extends StatelessWidget {
  final String? statusFilter; // Added to handle 'completed' or 'archived_rejected'

  const AllCompletedWorksScreen({super.key, this.statusFilter});

  // Theme Colors
  static const Color primaryMaroon = Color(0xFF6A1F1A);
  static const Color backgroundCream = Color(0xFFFFFDF5);
  static const Color goldAccent = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Determine the title based on status
    String title = "Work History";
    if (statusFilter == 'completed') title = "Completed Works";
    if (statusFilter == 'archived_rejected') title = "Rejected Proposals";

    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFF5E6CA),
        foregroundColor: primaryMaroon,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('userId', isEqualTo: user?.uid)
            // If statusFilter is null, show both types. Otherwise, show specific.
            .where('status', isEqualTo: statusFilter ?? 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No records found in $title",
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              data['id'] = docs[index].id;

              bool isRejected = data['status'] == 'archived_rejected';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isRejected ? Colors.red[50] : const Color(0xFFFFF7E8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRejected ? Icons.block : Icons.auto_awesome,
                      color: isRejected ? Colors.red[800] : goldAccent,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    data['place'] ?? 'Unnamed Temple',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E2723),
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${data['taluk']}, ${data['district']}",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: primaryMaroon,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserCompletedProjectScreen(project: data),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}