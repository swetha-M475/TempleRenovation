class Project {
  final String projectId; // new unique id
  final String place;
  final String nearbyTown;
  final String taluk;
  final String district;
  final String mapLocation; // could be "lat,lng" or JSON
  final DateTime? dateOfVisit;
  // remove status field from model (see step 3)

  Project({
    required this.projectId,
    required this.place,
    required this.nearbyTown,
    required this.taluk,
    required this.district,
    required this.mapLocation,
    this.dateOfVisit,
  });

  Map<String, dynamic> toJson() => {
        'projectId': projectId,
        'place': place,
        'nearbyTown': nearbyTown,
        'taluk': taluk,
        'district': district,
        'mapLocation': mapLocation,
        if (dateOfVisit != null) 'dateOfVisit': dateOfVisit!.toIso8601String(),
      };

  static Project fromJson(Map<String, dynamic> json) => Project(
        projectId: json['projectId'] as String,
        place: json['place'] ?? '',
        nearbyTown: json['nearbyTown'] ?? '',
        taluk: json['taluk'] ?? '',
        district: json['district'] ?? '',
        mapLocation: json['mapLocation'] ?? '',
        dateOfVisit: json['dateOfVisit'] != null
            ? DateTime.parse(json['dateOfVisit'])
            : null,
      );
}
