// lib/services/otp_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class OTPService {
  // Your 2Factor API key
  static const String apiKey = "0b23b35d-c516-11f0-a6b2-0200cd936042";

  // Send OTP
  static Future<Map<String, dynamic>> sendOTP(String phone) async {
    final url =
        Uri.parse("https://2factor.in/API/V1/$apiKey/SMS/+91$phone/AUTOGEN");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        "status": data["Status"],
        "sessionId": data["Details"],
      };
    } else {
      return {"status": "Error", "message": "Failed to send OTP"};
    }
  }

  // Verify OTP
  static Future<bool> verifyOTP(String sessionId, String otp) async {
    final url = Uri.parse(
        "https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$sessionId/$otp");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["Status"] == "Success";
    } else {
      return false;
    }
  }
}
