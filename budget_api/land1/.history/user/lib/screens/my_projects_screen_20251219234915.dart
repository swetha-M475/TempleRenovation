import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyProjectsScreen extends StatelessWidget {
  const MyProjectsScreen({super.key});

  Stream<QuerySnapshot> fetchMyProjects() {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return FirebaseFirestore.instance
        .collection('projects')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['approved', 'completed'])
        .orderBy('dateCreated', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Projects")),
      body: StreamBuilder<QuerySnapshot>(
        stream: fetchMyProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No approved projects yet',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final place = data['place'] ?? '';
              final status = data['status'] ?? '';
              final amount = data['estimatedAmount'] ?? '';
              final feature = data['feature'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: ListTile(
                  title: Text(
                    place,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (feature.toString().isNotEmpty)
                        Text('Feature: $feature'),
                      Text('Status: ${status.toUpperCase()}'),
                    ],
                  ),
                  trailing: Text(
                    amount.toString().isNotEmpty ? '₹$amount' : '',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
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
