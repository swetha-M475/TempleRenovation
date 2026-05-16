import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<String> getDistrict() async {
    try {
      // Check if location service is enabled at all
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location service disabled — using default');
        return "Coimbatore";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Location permission denied — using default');
        return "Coimbatore";
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,  // faster than high
      ).timeout(const Duration(seconds: 10));   // don't wait forever

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String district = place.subAdministrativeArea ??
            place.administrativeArea ??
            "Coimbatore";
        district = district.replaceAll(" District", "").trim();
        print('Detected district: $district');
        return district.isEmpty ? "Coimbatore" : district;
      }
      return "Coimbatore";
    } catch (e) {
      print("Location error: $e — using default Coimbatore");
      return "Coimbatore";  // ← always return a valid district
    }
  }
}