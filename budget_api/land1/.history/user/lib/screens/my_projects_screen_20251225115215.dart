import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class MyProjectsScreen extends StatelessWidget {
  const MyProjectsScreen({super.key});

  Stream<QuerySnapshot> fetchMyProjects() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return FirebaseFirestore.instance
        .collection('projects')
        .where('userId', isEqualTo: uid)
        .orderBy('dateCreated', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5), // Ivory Background
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFDF5),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "My Projects",
          style: GoogleFonts.cinzel(
            color: const Color(0xFF3E2723), // Dark Coffee
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5D4037)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: fetchMyProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5D4037)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No projects found",
                style: GoogleFonts.poppins(color: const Color(0xFF8D6E63)),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'pending';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E6CA).withOpacity(0.5), // Sandalwood
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF5E6CA)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    data['place'] ?? 'Unknown Location',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E2723),
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        "Status: ",
                        style: GoogleFonts.poppins(color: const Color(0xFF8D6E63)),
                      ),
                      Text(
                        status.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: status == 'rejected' 
                              ? const Color(0xFFB71C1C) 
                              : const Color(0xFF5D4037),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFF5D4037), // Bronze
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}