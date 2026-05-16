// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetch district document by ID
  static Future<Map<String, dynamic>?> getDistrictById(
    String districtId,
  ) async {
    final doc = await _db.collection('districts').doc(districtId).get();
    return doc.data();
  }

  // Fetch all places belonging to a district
  static Future<List<Map<String, dynamic>>> getPlacesByDistrict(
    String districtId,
  ) async {
    final query = await _db
        .collection('places')
        .where('districtId', isEqualTo: districtId)
        .get();

    return query.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // important for navigation
      return data;
    }).toList();
  }
}
