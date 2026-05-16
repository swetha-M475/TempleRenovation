import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiBillService {
  // Replace with your actual API Key
  static const _apiKey = 'YOUR_GEMINI_API_KEY';

  static Future<Map<String, dynamic>?> extractBillData(File imageFile) async {
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);

    final bytes = await imageFile.readAsBytes();
    final content = [
      Content.multi([
        TextPart(
            "Extract the Merchant/Shop Name and the Total Bill Amount from this image. "
            "Return strictly a JSON object with keys 'name' and 'amount'. "
            "If you can't find them, return null values."),
        DataPart('image/jpeg', bytes),
      ])
    ];

    try {
      final response = await model.generateContent(content);
      final text = response.text;
      if (text != null) {
        // Cleaning the response string to ensure it's pure JSON
        final cleanJson =
            text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanJson) as Map<String, dynamic>;
      }
    } catch (e) {
      print("AI Extraction Error: $e");
    }
    return null;
  }
}
