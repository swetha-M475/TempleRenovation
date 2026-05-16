// USER SIDE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProjectService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> createProject({
    required String name,
    required String description,
    required String location,
  }) async {
    String uid = _auth.currentUser!.uid;

    await _firestore.collection('projects').add({
      'userId': uid,
      'name': name,
      'description': description,
      'location': location,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> myProjects() {
    String uid = _auth.currentUser!.uid;

    return _firestore
        .collection('projects')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
