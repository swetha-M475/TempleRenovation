import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProjectService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> fetchPendingProjects() {
    return _db
        .collection('projects')
        .where('status', isEqualTo: 'pending')
        .orderBy('dateCreated', descending: true)
        .snapshots();
  }

  Future<void> approve(String projectId) async {
    await _db.collection('projects').doc(projectId).update({
      'status': 'approved',
    });
  }

  Future<void> reject(String projectId) async {
    await _db.collection('projects').doc(projectId).update({
      'status': 'rejected',
    });
  }
}

mixin QuerySnapshot {
}
