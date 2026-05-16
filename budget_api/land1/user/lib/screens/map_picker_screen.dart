import 'dart:async';
import 'dart:convert'; // For decoding JSON
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http; // Use standard HTTP

class MapPickerScreen extends StatefulWidget {
  final String mapboxApiKey;

  const MapPickerScreen({super.key, required this.mapboxApiKey});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  
  // Default location (e.g., Chennai)
  LatLng _currentCenter = const LatLng(13.0827, 80.2707); 
  
  String _placeName = "Searching address...";
  String? _district;
  String? _state;
  bool _isLoadingAddress = false;
  Timer? _debounce;
  bool _hasMovedOnce = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 1. Get User's Current GPS Location on startup
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final newPos = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentCenter = newPos;
      });
      
      _mapController.move(newPos, 15);
      _fetchAddress(newPos);
    } catch (e) {
      debugPrint("GPS Error: $e");
    }
  }

  // 2. Manual Mapbox API Call (Replaces mapbox_search library)
  Future<void> _fetchAddress(LatLng point) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);

    try {
      // API URL
      final String url = 
          "https://api.mapbox.com/geocoding/v5/mapbox.places/${point.longitude},${point.latitude}.json?access_token=${widget.mapboxApiKey}&types=place,district,region,locality&limit=1";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          final feature = data['features'][0];
          
          String place = feature['text'] ?? "Unknown Place";
          String? dist;
          String? st;

          // Parse Mapbox Context to find District and State
          if (feature['context'] != null) {
            for (var ctx in feature['context']) {
              String id = ctx['id'].toString();
              String text = ctx['text'];

              if (id.startsWith('district')) dist = text;
              if (id.startsWith('region')) st = text;
              if (id.startsWith('place') || id.startsWith('locality')) {
                // If the main text isn't the place name, grab it from context
                if (place == "Unknown Place") place = text;
              }
            }
          }

          if (mounted) {
            setState(() {
              _placeName = place;
              _district = dist;
              _state = st;
              _isLoadingAddress = false;
            });
          }
        } else {
           if (mounted) setState(() { 
             _placeName = "Unknown Location"; 
             _isLoadingAddress = false; 
           });
        }
      } else {
        debugPrint("Mapbox Error: ${response.body}");
        if (mounted) setState(() => _isLoadingAddress = false);
      }
    } catch (e) {
      debugPrint("Network Error: $e");
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  // 3. Handle Map Movement (Drag)
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    _currentCenter = camera.center;
    
    // Debounce: Wait 800ms after user stops dragging to fetch address
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchAddress(_currentCenter);
    });
  }

  void _confirmSelection() {
    Navigator.pop(context, {
      'place': _placeName,
      'district': _district,
      'state': _state,
      'lat': _currentCenter.latitude,
      'lng': _currentCenter.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location"),
        backgroundColor: const Color(0xFF5D4037),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // A. The Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onPositionChanged: _onMapPositionChanged,
              interactionOptions: const InteractionOptions(
                 flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Disable rotation
              ),
            ),
            children: [
              TileLayer(
                // Using Mapbox Tiles
                urlTemplate: "https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=${widget.mapboxApiKey}",
                additionalOptions: const {
                  'id': 'mapbox.streets',
                },
                // Add your package name here to satisfy Mapbox/OSM requirements
                userAgentPackageName: 'com.yourcompany.app',
              ),
            ],
          ),

          // B. The Center Pin (Fixed)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40), // Lift pin slightly so tip is at center
              child: Icon(Icons.location_on, size: 50, color: Colors.red),
            ),
          ),

          // C. Bottom Details Card
         // C. Bottom Details Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              // FIX: Move color and boxShadow inside BoxDecoration
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Selected Location:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 5),
                  
                  Row(
                    children: [
                      const Icon(Icons.map, color: Color(0xFF5D4037)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _isLoadingAddress
                            ? const LinearProgressIndicator(color: Color(0xFF5D4037))
                            : Text(
                                "$_placeName${_district != null ? ', $_district' : ''}",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isLoadingAddress || _placeName == "Searching address...") 
                          ? null 
                          : _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D4037),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text("Confirm Location"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}