import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/user_completed_project_screen.dart';

class AllCompletedWorksScreen extends StatelessWidget {
  const AllCompletedWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      appBar: AppBar(
        title: Text('Completed Works', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5E6CA),
        foregroundColor: const Color(0xFF5D4037),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .where('userId', isEqualTo: user?.uid)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text("No completed projects found.", 
              style: GoogleFonts.poppins(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.size,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              data['id'] = snapshot.data!.docs[index].id;

              return Card(
                margin: const EdgeInsets.bottom(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: const Icon(Icons.verified, color: Colors.blue, size: 30),
                  title: Text(data['place'] ?? 'Unnamed Temple', 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Text("${data['district']}, ${data['taluk']}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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