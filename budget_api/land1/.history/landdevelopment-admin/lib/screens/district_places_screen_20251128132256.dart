import 'package:flutter/material.dart';
import 'place_temples_screen.dart';

class DistrictPlacesScreen extends StatefulWidget {
  final String districtId;

  const DistrictPlacesScreen({
    Key? key,
    required this.districtId,
  }) : super(key: key);

  @override
  State<DistrictPlacesScreen> createState() =>
      _DistrictPlacesScreenState();
}

class _DistrictPlacesScreenState
    extends State<DistrictPlacesScreen> {
  String searchQuery = '';
  String districtName = '';
  List<Map<String, dynamic>> places = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() => isLoading = true);

    // TODO: Backend Integration
    // final district = await FirebaseService.getDistrictById(widget.districtId);
    // districtName = district['name'];
    // places = await FirebaseService.getPlacesByDistrict(widget.districtId);

    await Future.delayed(const Duration(milliseconds: 500));

    districtName = 'Tirunelveli';
    places = [
      {
        'id': '1',
        'name': 'Vadakku Valliyur',
        'temples': 2,
        'newRequests': 2
      },
      {
        'id': '2',
        'name': 'Tirunelveli City',
        'temples': 1,
        'newRequests': 0
      },
    ];

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = places.where((p) {
      return p['name']
          .toString()
          .toLowerCase()
          .contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () =>
                              Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text(
                      '$districtName District',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${places.length} Places',
                      style: const TextStyle(
                        color: Color(0xFFC7D2FE),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) =>
                  setState(() => searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search places...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator())
                : places.isEmpty
                    ? const Center(
                        child: Text('No places available'),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('No results found'),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final place = filtered[index];
                              return Card(
                                margin:
                                    const EdgeInsets.only(
                                        bottom: 12),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PlaceTemplesScreen(
                                          placeId: place['id'],
                                        ),
                                      ),
                                    );
                                  },
                                  title: Text(
                                    place['name'],
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${place['temples']} Temple${place['temples'] != 1 ? 's' : ''}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      if (place['newRequests'] >
                                          0)
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                                        12),
                                          ),
                                          child: Text(
                                            '${place['newRequests']} New',
                                            style:
                                                const TextStyle(
                                              color:
                                                  Colors.white,
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(
                                          width: 8),
                                      const Icon(Icons
                                          .chevron_right),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
