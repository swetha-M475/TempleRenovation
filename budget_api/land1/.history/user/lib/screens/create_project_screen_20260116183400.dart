import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/image_picker_widget.dart';
import '../services/cloudinary_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class FeatureEntry {
  final String key;
  final String label;
  String condition;
  String? dimension;
  String? amount;
  String? customSize;

  FeatureEntry({
    required this.key,
    required this.label,
    this.condition = 'old',
    this.dimension,
    this.amount,
    this.customSize,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'condition': condition,
        'dimension': dimension,
        'amount': amount,
        'customSize': customSize,
      };
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _nearbyTownController = TextEditingController();
  final TextEditingController _talukController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController =
      TextEditingController(text: "Tamil Nadu");
  final TextEditingController _mapLocationController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _estimatedAmountController =
      TextEditingController();

  DateTime? _selectedDate;
  List<String> _selectedImages = [];
  bool _isLoading = false;
  String _aadharNumber = "N/A";

  final List<String> _tnDistricts = [
    'Ariyalur','Chengalpattu','Chennai','Coimbatore','Cuddalore','Dharmapuri',
    'Dindigul','Erode','Kallakurichi','Kancheepuram','Kanniyakumari','Karur',
    'Krishnagiri','Madurai','Mayiladuthurai','Nagapattinam','Namakkal',
    'Nilgiris','Perambalur','Pudukkottai','Ramanathapuram','Ranipet','Salem',
    'Sivagangai','Tenkasi','Thanjavur','Theni','Thoothukudi',
    'Tiruchirappalli','Tirunelveli','Tirupathur','Tiruppur','Tiruvallur',
    'Tiruvannamalai','Tiruvarur','Vellore','Viluppuram','Virudhunagar'
  ];

  // 🔹 Taluks mapped to Districts
  final Map<String, List<String>> _tnTaluks = {
    'Chennai': ['Ambattur','Egmore','Mylapore','Perambur','Sholinganallur'],
    'Coimbatore': ['Coimbatore North','Coimbatore South','Pollachi','Mettupalayam'],
    'Madurai': ['Madurai North','Madurai South','Melur','Thirumangalam'],
    'Salem': ['Salem','Attur','Mettur','Omalur'],
    'Tiruchirappalli': ['Srirangam','Manapparai','Musiri','Lalgudi'],
  };

  late List<FeatureEntry> _features;

  @override
  void initState() {
    super.initState();
    _fetchContractorData();
    _features = [
      FeatureEntry(key: 'lingam', label: 'Lingam'),
      FeatureEntry(key: 'nandhi', label: 'Nandhi'),
      FeatureEntry(key: 'avudai', label: 'Avudai'),
      FeatureEntry(key: 'shed', label: 'Shed'),
    ];
  }

  Future<void> _fetchContractorData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) return;

    final data = doc.data()!;
    _contactNameController.text = data['name'] ?? '';
    _contactPhoneController.text = data['phone'] ?? '';
    _aadharNumber = data['aadhar'] ?? 'N/A';
  }

  // ---------------- TALUK AUTOCOMPLETE ----------------
  Widget _buildTalukField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: _talukController.text),
        optionsBuilder: (TextEditingValue value) {
          final district = _districtController.text.trim();
          if (district.isEmpty ||
              !_tnTaluks.containsKey(district) ||
              value.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          return _tnTaluks[district]!.where(
            (t) => t.toLowerCase().contains(value.text.toLowerCase()),
          );
        },
        onSelected: (selection) => _talukController.text = selection,
        fieldViewBuilder:
            (context, controller, focusNode, onFieldSubmitted) {
          controller.addListener(() {
            _talukController.text = controller.text;
          });
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Taluk',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDistrictField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        optionsBuilder: (value) {
          if (value.text.isEmpty) return const Iterable<String>.empty();
          return _tnDistricts.where(
            (d) => d.toLowerCase().contains(value.text.toLowerCase()),
          );
        },
        onSelected: (selection) {
          _districtController.text = selection;
          _talukController.clear(); // reset taluk on district change
        },
        fieldViewBuilder:
            (context, controller, focusNode, onFieldSubmitted) {
          controller.addListener(() {
            _districtController.text = controller.text;
          });
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'District',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _plainTextField(
    TextEditingController c,
    String label, {
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _plainTextField(_placeController, 'Place'),
          _plainTextField(_nearbyTownController, 'Nearby Town'),
          _buildTalukField(),          // ✅ TALUK
          _buildDistrictField(),       // ✅ DISTRICT
          _plainTextField(_stateController, 'State', readOnly: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildLocationPage(),
          const Center(child: Text('Other pages unchanged')),
        ],
      ),
    );
  }
}
