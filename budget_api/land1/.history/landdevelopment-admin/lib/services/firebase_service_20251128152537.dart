import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --------------------------------------------------------
  // DISTRICTS
  // --------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getDistricts() async {
    final snapshot = await _db.collection('districts').get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'] ?? '',
        'places': doc['placesCount'] ?? 0,
        'newRequests': doc['newRequests'] ?? 0,
      };
    }).toList();
  }

  // --------------------------------------------------------
  // PLACES BY DISTRICT
  // --------------------------------------------------------
  static Future<Map<String, dynamic>?> getDistrictById(String id) async {
    final doc = await _db.collection('districts').doc(id).get();
    return doc.exists ? doc.data() : null;
  }

  static Future<List<Map<String, dynamic>>> getPlacesByDistrict(
    String districtId,
  ) async {
    final snapshot = await _db
        .collection('places')
        .where('districtId', isEqualTo: districtId)
        .get();

    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'] ?? '',
        'temples': doc['templeCount'] ?? 0,
        'newRequests': doc['newRequests'] ?? 0,
      };
    }).toList();
  }

  // --------------------------------------------------------
  // TEMPLES / PROJECTS
  // --------------------------------------------------------
  static Future<List<Map<String, dynamic>>> getTemplesByPlace(
    String placeId,
  ) async {
    final snapshot = await _db
        .collection('projects')
        .where('placeId', isEqualTo: placeId)
        .get();

    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }

  // --------------------------------------------------------
  // SANCTION PROJECT
  // --------------------------------------------------------
  static Future<void> approveProject(String projectId) async {
    await _db.collection('projects').doc(projectId).update({
      'status': 'approved',
      'approvedDate': FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------------------
  // REJECT PROJECT
  // --------------------------------------------------------
  static Future<void> rejectProject(String projectId) async {
    await _db.collection('projects').doc(projectId).update({
      'status': 'rejected',
      'rejectedDate': FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------------------
  // MARK COMPLETED
  // --------------------------------------------------------
  static Future<void> completeProject(String projectId) async {
    await _db.collection('projects').doc(projectId).update({
      'status': 'completed',
      'completedDate': FieldValue.serverTimestamp(),
    });
  }
}
