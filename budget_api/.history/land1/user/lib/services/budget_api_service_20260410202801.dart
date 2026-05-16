import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BudgetApiService {
  static const String baseUrl = "http://10.161.190.46:8000";

  static Future<Map<String, dynamic>> analyzeDamage({
    required File imageFile,
    required double sqft,
    required String district,
  }) async {
    print('=== API CALL START ===');
    print('sqft value: $sqft  type: ${sqft.runtimeType}');

    try {
      var uri = Uri.parse('$baseUrl/analyze-damage-upload');
      var request = http.MultipartRequest('POST', uri);

      // ── Image file ─────────────────────────────────────────────
      var imageStream = http.ByteStream(imageFile.openRead());
      var imageLength = await imageFile.length();
      request.files.add(http.MultipartFile(
        'file',
        imageStream,
        imageLength,
        filename: imageFile.path.split('/').last,
      ));

      // ── sqft: send as integer string e.g. "25" not "25.0" ─────
      // FastAPI Form float parser sometimes rejects "25.0" format
      final sqftString = sqft == sqft.truncateToDouble()
          ? sqft.toInt().toString() // 25.0 → "25"
          : sqft.toString(); // 25.5 → "25.5"

      request.fields['sqft'] = sqftString;
      request.fields['work_description'] = 'Detected from image analysis';
      request.fields['district'] = district;

      print('Sending fields: ${request.fields}');

      var streamedResponse =
          await request.send().timeout(const Duration(seconds: 90));
      var response = await http.Response.fromStream(streamedResponse);

      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 422) {
        final errorBody = json.decode(response.body);
        throw Exception('422 Error: ${errorBody['detail']}');
      } else {
        throw Exception(
            'Server error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('ERROR: $e');
      rethrow;
    }
  }
}
