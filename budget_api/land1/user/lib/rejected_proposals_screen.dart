import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class RejectedProposalsScreen extends StatelessWidget {
  const RejectedProposalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        title: Text(
          'Rejected History',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF3E2723)),
        ),
        backgroundColor: const Color(0xFFF5E6CA),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5D4037)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('userId', isEqualTo: user?.uid)
            .where('status', isEqualTo: 'archived_rejected') 
            .orderBy('dateCreated', descending: true) // This is what needs the index
            .snapshots(),
        builder: (context, snapshot) {
          // Handle specific Index Error visually
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('requires an index')) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    "Building Database Index...\nPlease wait 2-3 minutes and try again.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.brown),
                  ),
                ),
              );
            }
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5D4037)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No rejected history found.",
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildRejectedCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildRejectedCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['place'] ?? 'Unnamed Temple',
            style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            "${data['taluk']}, ${data['district']}",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Estimated Cost:", style: GoogleFonts.poppins(fontSize: 12)),
              Text("₹${data['estimatedAmount']}", 
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}