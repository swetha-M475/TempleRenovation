import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BudgetApiService {
  // ⚠️ IMPORTANT: Change this to your PC's IP address
  // Find it by running: ipconfig (Windows) → IPv4 Address under WiFi
  // Example: http://192.168.1.5:8000
  // For Android emulator use: http://10.0.2.2:8000
  static const String baseUrl = "http://10.52.162.46:8000";

  static Future<Map<String, dynamic>> analyzeDamage({
    required File imageFile,
    required double sqft,
    required String workDescription,
    required String district,
  }) async {
    print('=== API CALL START ===');
    print('URL: $baseUrl/analyze-damage-upload');
    print('sqft: $sqft');
    print('district: $district');
    print('work: $workDescription');
    print('image path: ${imageFile.path}');

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/analyze-damage-upload'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      request.fields['sqft']             = sqft.toString();
      request.fields['work_description'] = workDescription;
      request.fields['district']         = district;

      print('Sending request...');
      var streamedResponse = await request.send()
          .timeout(const Duration(seconds: 60));           // 60s timeout for AI

      var response = await http.Response.fromStream(streamedResponse);

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('=== API CALL SUCCESS ===');
        return data;
      } else {
        throw Exception('Server error ${response.statusCode}: ${response.body}');
      }
    } on http.ClientException catch (e) {
      print('ClientException: $e');
      throw Exception('Cannot connect to server.\nMake sure backend is running and IP is correct.\nDetails: $e');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }
}