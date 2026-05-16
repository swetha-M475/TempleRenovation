import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<String> getDistrict() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return "Thanjavur";
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String district = place.subAdministrativeArea ??
            place.administrativeArea ??
            "Thanjavur";
        district = district.replaceAll(" District", "").trim();
        return district;
      }
      return "Thanjavur";
    } catch (e) {
      print("Location error: $e");
      return "Thanjavur";
    }
  }
}