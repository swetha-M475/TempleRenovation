import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyProjectsScreen extends StatelessWidget {
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
      appBar: AppBar(title: Text("My Projects")),
      body: StreamBuilder(
        stream: fetchMyProjects(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text(data['place']),
                subtitle: Text("Status: ${data['status']}"),
              );
            },
          );
        },
      ),
    );
  }
}
