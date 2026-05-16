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

  final List<Map<String, dynamic>> _predefinedDimensions = [
    {'name': '2 feet', 'amount': 50000},
    {'name': '3 feet', 'amount': 75000},
    {'name': '4 feet', 'amount': 100000},
  ];

  final List<String> _tnDistricts = [
    'Ariyalur', 'Chengalpattu', 'Chennai', 'Coimbatore', 'Cuddalore',
    'Dharmapuri', 'Dindigul', 'Erode', 'Kallakurichi', 'Kancheepuram',
    'Kanniyakumari', 'Karur', 'Krishnagiri', 'Madurai', 'Mayiladuthurai',
    'Nagapattinam', 'Namakkal', 'Nilgiris', 'Perambalur', 'Pudukkottai',
    'Ramanathapuram', 'Ranipet', 'Salem', 'Sivagangai', 'Tenkasi',
    'Thanjavur', 'Theni', 'Thoothukudi', 'Tiruchirappalli', 'Tirunelveli',
    'Tirupathur', 'Tiruppur', 'Tiruvallur', 'Tiruvannamalai', 'Tiruvarur',
    'Vellore', 'Viluppuram', 'Virudhunagar'
  ];

  final Map<String, List<String>> _districtTaluks = {
    'Ariyalur': ['Ariyalur', 'Sendurai', 'Udayarpalayam', 'Andimadam'],
    'Chengalpattu': ['Chengalpattu', 'Cheyyur', 'Madurantakam', 'Pallavaram', 'Tambaram', 'Tiruporur', 'Vandalur', 'Thirukalukundram'],
    'Chennai': ['Ayanavaram', 'Egmore', 'Guindy', 'Mylapore', 'Perambur', 'Tondiarpet', 'Velachery', 'Madhavaram', 'Ambattur', 'Sholinganallur'],
    'Coimbatore': ['Coimbatore North', 'Coimbatore South', 'Pollachi', 'Mettupalayam', 'Annur', 'Sulur', 'Valparai', 'Perur', 'Madukkarai'],
    'Cuddalore': ['Cuddalore', 'Panruti', 'Chidambaram', 'Virudhachalam', 'Tittakudi', 'Kurinjipadi', 'Bhuvanagiri', 'Srimushnam'],
    'Dharmapuri': ['Dharmapuri', 'Harur', 'Pappireddipatti', 'Pennagaram', 'Palacode', 'Nallampalli', 'Karimangalam'],
    'Dindigul': ['Dindigul East', 'Dindigul West', 'Palani', 'Oddanchatram', 'Kodaikanal', 'Natham', 'Nilakottai', 'Vedasandur', 'Gujiliamparai'],
    'Erode': ['Erode', 'Perundurai', 'Bhavani', 'Gobichettipalayam', 'Sathyamangalam', 'Anthiyur', 'Kodumudi', 'Modakkurichi', 'Thalavadi'],
    'Kallakurichi': ['Kallakurichi', 'Sankarapuram', 'Chinnasalem', 'Tirukkoilur', 'Ulundurpet', 'Kalvarayan Hills'],
    'Kancheepuram': ['Kancheepuram', 'Sriperumbudur', 'Uthiramerur', 'Walajabad', 'Kundrathur'],
    'Kanniyakumari': ['Agastheeswaram', 'Thovalai', 'Kalkulam', 'Vilavancode', 'Killiyur', 'Thiruvattar'],
    'Karur': ['Karur', 'Aravakurichi', 'Manmangalam', 'Pugalur', 'Kulithalai', 'Krishnarayapuram', 'Kadavur'],
    'Krishnagiri': ['Krishnagiri', 'Hosur', 'Pochampalli', 'Uthangarai', 'Denkanikottai', 'Shoolagiri', 'Bargur', 'Anchetti'],
    'Madurai': ['Madurai North', 'Madurai South', 'Madurai West', 'Madurai East', 'Melur', 'Vadipatti', 'Usilampatti', 'Peraiyur', 'Thirumangalam', 'Thirupparankundram'],
    'Mayiladuthurai': ['Mayiladuthurai', 'Sirkazhi', 'Tharangambadi', 'Kuthalam'],
    'Nagapattinam': ['Nagapattinam', 'Kilvelur', 'Vedaranyam', 'Thirukkuvalai'],
    'Namakkal': ['Namakkal', 'Rasipuram', 'Tiruchengode', 'Paramathi Velur', 'Sendamangalam', 'Kolli Hills', 'Mohanur', 'Kumarapalayam'],
    'Nilgiris': ['Udhagamandalam', 'Coonoor', 'Kotagiri', 'Gudalur', 'Pandalur', 'Kundah'],
    'Perambalur': ['Perambalur', 'Kunnam', 'Alathur', 'Veppanthattai'],
    'Pudukkottai': ['Pudukkottai', 'Alangudi', 'Aranthangi', 'Gandarvakottai', 'Karambakudi', 'Kulathur', 'Illuppur', 'Ponnamaravathi', 'Thirumayam', 'Avudaiyarkoil', 'Manamelkudi'],
    'Ramanathapuram': ['Ramanathapuram', 'Rameswaram', 'Tiruvadanai', 'Paramakudi', 'Mudukulathur', 'Kadaladi', 'Kamuthi', 'Rajasingamangalam', 'Keelakarai'],
    'Ranipet': ['Ranipet', 'Walajah', 'Arcot', 'Nemili', 'Arakkonam', 'Sholinghur'],
    'Salem': ['Salem', 'Salem South', 'Salem West', 'Attur', 'Mettur', 'Omalur', 'Sankari', 'Vazhapadi', 'Gangavalli', 'Edappadi', 'Kadayampatti', 'Pethanaickenpalayam'],
    'Sivagangai': ['Sivagangai', 'Karaikudi', 'Devakottai', 'Manamadurai', 'Ilayangudi', 'Thiruppuvanam', 'Kalayarkoil', 'Tiruppathur', 'Singampunari'],
    'Tenkasi': ['Tenkasi', 'Sengottai', 'Kadayanallur', 'Sivagiri', 'Sankarankovil', 'Thiruvengadam', 'Alangulam', 'V.K.Pudur'],
    'Thanjavur': ['Thanjavur', 'Kumbakonam', 'Papanasam', 'Pattukkottai', 'Peravurani', 'Orathanadu', 'Thiruvaiyaru', 'Thiruvidaimarudur', 'Budalur'],
    'Theni': ['Theni', 'Periyakulam', 'Bodinayakanur', 'Uthamapalayam', 'Andipatti'],
    'Thoothukudi': ['Thoothukudi', 'Srivaikuntam', 'Tiruchendur', 'Sathankulam', 'Eral', 'Ettayapuram', 'Kovilpatti', 'Ottapidaram', 'Vilathikulam', 'Kayathar'],
    'Tiruchirappalli': ['Tiruchirappalli East', 'Tiruchirappalli West', 'Srirangam', 'Lalgudi', 'Manachanallur', 'Musiri', 'Thuraiyur', 'Thottiyam', 'Manapparai', 'Marungapuri'],
    'Tirunelveli': ['Tirunelveli', 'Palayamkottai', 'Ambasamudram', 'Cheranmahadevi', 'Radhapuram', 'Nanguneri', 'Tisayanvilai'],
    'Tirupathur': ['Tirupathur', 'Vaniyambadi', 'Ambur', 'Natrampalli'],
    'Tiruppur': ['Tiruppur North', 'Tiruppur South', 'Avinashi', 'Dharapuram', 'Kangeyam', 'Udumalaipettai', 'Palladam', 'Madathukulam', 'Uthukuli'],
    'Tiruvallur': ['Tiruvallur', 'Avadi', 'Poonamallee', 'Ponneri', 'Gummidipoondi', 'Uthukottai', 'Tiruttani', 'Pallipattu', 'R.K. Pet'],
    'Tiruvannamalai': ['Tiruvannamalai', 'Arni', 'Cheyyar', 'Vandavasi', 'Polur', 'Chengam', 'Thandarampattu', 'Kalasapakkam', 'Jawadhu Hills', 'Kilpennathur', 'Chetpet', 'Jamunamarathur'],
    'Tiruvarur': ['Tiruvarur', 'Mannargudi', 'Nannilam', 'Thiruthuraipoondi', 'Needamangalam', 'Kodavasal', 'Valangaiman', 'Koothanallur'],
    'Vellore': ['Vellore', 'Katpadi', 'Gudiyatham', 'Anaicut', 'Kaveripakkam', 'Pernambut'],
    'Viluppuram': ['Viluppuram', 'Vikravandi', 'Vanur', 'Gingee', 'Marakkanam', 'Kandachipuram', 'Thiruvennainallur'],
    'Virudhunagar': ['Virudhunagar', 'Sivakasi', 'Srivilliputhur', 'Rajapalayam', 'Aruppukkottai', 'Sattur', 'Tiruchuli', 'Kariapatti', 'Watrap'],
  };

  late List<FeatureEntry> _features;
  FeatureEntry? _selectedFeatureEntry;

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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          setState(() {
            _contactNameController.text = (data['name'] ?? data['fullName'] ?? '').toString();
            String? fetchedPhone = data['phone']?.toString() ?? data['phoneNumber']?.toString() ?? data['mobile']?.toString();
            _contactPhoneController.text = fetchedPhone ?? user.phoneNumber ?? '';
            _aadharNumber = (data['aadhar'] ?? data['aadharNumber'] ?? 'N/A').toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  bool _validateCurrentPage() {
    if (_currentPage == 0) {
      if (_placeController.text.trim().isEmpty) return _showWarning('Place name is required');
      if (_districtController.text.trim().isEmpty) return _showWarning('District is required');
      if (_talukController.text.trim().isEmpty) return _showWarning('Taluk is required');
      if (_mapLocationController.text.trim().isEmpty) return _showWarning('Please capture GPS coordinates');
      if (_selectedDate == null) return _showWarning('Please select a visit date');
      return true;
    }
    
    if (_currentPage == 1) {
      bool hasNew = _features.any((f) => f.condition == 'new');
      if (!hasNew) {
        return _showWarning('Please select at least one structure to be NEW to proceed.');
      }
      return true;
    }

    if (_currentPage == 2) {
      if (_selectedImages.length < 5) return _showWarning('At least 5 site images are required');
      if (_estimatedAmountController.text.isEmpty) return _showWarning('Estimated amount is required');
    }

    return true; 
  }

  bool _showWarning(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFB71C1C), behavior: SnackBarBehavior.floating),
    );
    return false;
  }

  /// ROBUST LOCATION FETCHING (Like Uber/Ola)
  Future<void> _detectAndFillLocation() async {
    setState(() => _isLoading = true);
    
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // 1. Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        _showWarning("Location services are disabled. Please enable GPS.");
        await Geolocator.openLocationSettings();
        return;
      }

      // 2. Check for permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          _showWarning("Location permissions are denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        _showWarning("Location permissions are permanently denied. Open settings to allow.");
        await Geolocator.openAppSettings();
        return;
      }

      // 3. Get Position with high accuracy
      // Note: use getCurrentPosition for a one-time precise fix
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _mapLocationController.text = "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      });
      
    } catch (e) {
      debugPrint("Location Error: $e");
      _showWarning("Timeout or Error fetching location. Try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createProject() async {
    if (!_validateCurrentPage()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final String rawId = const Uuid().v4();
      final String projectDisplayId = "PRJ-${rawId.substring(0, 8).toUpperCase()}";
      final List<String> uploadedImageUrls = [];

      for (final imgPath in _selectedImages) {
        final url = await CloudinaryService.uploadImage(imageFile: XFile(imgPath), userId: user.uid, projectId: projectDisplayId);
        if (url != null) uploadedImageUrls.add(url);
      }

      final List<Map<String, dynamic>> featureMaps = _features.map((f) => f.toMap()).toList();
      await FirebaseFirestore.instance.collection('projects').doc(rawId).set({
        'projectId': projectDisplayId,
        'userId': user.uid,
        'aadharNumber': _aadharNumber,
        'place': _placeController.text.trim(),
        'taluk': _talukController.text.trim(),
        'district': _districtController.text.trim(),
        'state': _stateController.text.trim(),
        'mapLocation': _mapLocationController.text.trim(),
        'visitDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        'features': featureMaps,
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'estimatedAmount': _estimatedAmountController.text.trim(),
        'imageUrls': uploadedImageUrls,
        'dateCreated': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      Navigator.pop(context, true);
    } catch (e) {
      _showWarning('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [_buildLocationPage(), _buildFeaturePage(), _buildContactPage()],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPage() {
    return _buildFormContainer(
      child: Column(
        children: [
          _title('Location Info', 'Enter details of the site'),
          const SizedBox(height: 16),
          _plainTextField(_placeController, 'Place'),
          _buildDistrictAutocomplete(),
          _buildTalukAutocomplete(),
          _plainTextField(_stateController, 'State', readOnly: true),
          Row(
            children: [
              Expanded(child: _plainTextField(_mapLocationController, 'Map Location', readOnly: true)),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFF5D4037), borderRadius: BorderRadius.circular(10)),
                child: IconButton(
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.my_location, color: Colors.white), 
                  onPressed: _isLoading ? null : _detectAndFillLocation
                ),
              ),
            ],
          ),
          InkWell(onTap: () => _selectDate(context), child: _dateField()),
        ],
      ),
    );
  }

  Widget _buildDistrictAutocomplete() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue val) {
          if (val.text.isEmpty) return const Iterable<String>.empty();
          return _tnDistricts.where((d) => d.toLowerCase().startsWith(val.text.toLowerCase()));
        },
        onSelected: (String selection) {
          setState(() {
            _districtController.text = selection;
            _talukController.clear(); 
          });
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          if (controller.text.isEmpty && _districtController.text.isNotEmpty) {
            controller.text = _districtController.text;
          }
          return _buildStyledTextField(controller, focusNode, 'District', onFieldSubmitted);
        },
      ),
    );
  }

  Widget _buildTalukAutocomplete() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue val) {
          final selectedDistrict = _districtController.text;
          if (selectedDistrict.isEmpty || val.text.isEmpty) return const Iterable<String>.empty();
          final taluks = _districtTaluks[selectedDistrict] ?? [];
          return taluks.where((t) => t.toLowerCase().startsWith(val.text.toLowerCase()));
        },
        onSelected: (String selection) {
          setState(() => _talukController.text = selection);
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          if (controller.text.isEmpty && _talukController.text.isNotEmpty) {
            controller.text = _talukController.text;
          }
          
          bool canInput = _districtController.text.isNotEmpty;
          return _buildStyledTextField(
            controller, 
            focusNode, 
            'Taluk', 
            onFieldSubmitted,
            enabled: canInput,
            isTalukField: true, 
            hint: canInput ? 'Type to search Taluk' : 'Select District First'
          );
        },
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController controller, FocusNode focusNode, String label, VoidCallback onSubmitted, {bool enabled = true, String? hint, bool isTalukField = false}) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onFieldSubmitted: (v) => onSubmitted(),
      style: TextStyle(color: enabled ? Colors.black : Colors.black54),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: (enabled || isTalukField) ? Colors.white : Colors.grey.shade100,
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF5E6CA))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF5E6CA))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5D4037))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text('Propose a Plan', style: GoogleFonts.cinzel(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Row(children: [_step(0, 'Location'), _line(0), _step(1, 'Feature'), _line(1), _step(2, 'Details')]),
    );
  }

  Widget _step(int step, String label) {
    final active = _currentPage >= step;
    return Column(children: [
      CircleAvatar(radius: 18, backgroundColor: active ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA), child: Text('${step + 1}', style: TextStyle(fontSize: 12, color: active ? Colors.white : const Color(0xFF8D6E63)))),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    ]);
  }

  Widget _line(int step) {
    return Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4), color: _currentPage > step ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA)));
  }

  Widget _plainTextField(TextEditingController c, String label, {TextInputType keyboard = TextInputType.text, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c, keyboardType: keyboard, readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label, filled: true, fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF5E6CA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5D4037))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFormContainer({required Widget child}) {
    return SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(20),
      child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFF5E6CA).withOpacity(0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF5E6CA))), child: child),
    );
  }

  Widget _buildFeaturePage() {
    return _buildFormContainer(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_title('Select Features', 'Set condition for each structure'), const SizedBox(height: 16), ..._features.map(_buildFeatureCard)]));
  }

  Widget _buildFeatureCard(FeatureEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF5E6CA))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(entry.label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))), const SizedBox(width: 8), 
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: entry.condition == 'old' ? Colors.grey.shade200 : Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
          child: Text(entry.condition == 'old' ? 'Old' : 'New', style: TextStyle(fontSize: 10, color: entry.condition == 'old' ? Colors.grey.shade800 : Colors.green.shade800, fontWeight: FontWeight.w600)))]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildFeatureConditionButton(label: 'Old / Existing', isSelected: entry.condition == 'old', onTap: () { setState(() { entry.condition = 'old'; entry.dimension = null; entry.amount = null; }); })),
          const SizedBox(width: 8),
          Expanded(child: _buildFeatureConditionButton(label: 'New Structure', isSelected: entry.condition == 'new', onTap: () { setState(() { entry.condition = 'new'; _selectedFeatureEntry = entry; }); })),
        ]),
        if (entry.condition == 'new') ...[
          const SizedBox(height: 12),
          ..._predefinedDimensions.map((dim) => _buildFeatureDimensionTile(entry: entry, value: dim['name'], title: dim['name'], subtitle: 'Estimate: ₹${dim['amount']}', onSelected: () { setState(() { entry.dimension = dim['name']; entry.amount = dim['amount'].toString(); }); })),
          _buildFeatureDimensionTile(entry: entry, value: 'custom', title: 'Other', subtitle: 'Custom Size & Amount', onSelected: () { setState(() { entry.dimension = 'custom'; }); }),
          if (entry.dimension == 'custom') ...[
            const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(labelText: 'Size (e.g. 5 ft)', border: OutlineInputBorder()), onChanged: (v) => entry.customSize = v),
            const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(labelText: 'Required Amount (Rs)', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => entry.amount = v),
          ]
        ]
      ]),
    );
  }

  Widget _buildFeatureConditionButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), decoration: BoxDecoration(color: isSelected ? const Color(0xFFF5E6CA) : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA))),
    child: Row(children: [Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: const Color(0xFF5D4037)), const SizedBox(width: 6), Expanded(child: Text(label, style: const TextStyle(fontSize: 12)))])));
  }

  Widget _buildFeatureDimensionTile({required FeatureEntry entry, required String value, required String title, required String subtitle, required VoidCallback onSelected}) {
    final bool selected = entry.dimension == value;
    return InkWell(onTap: onSelected, child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: selected ? const Color(0xFFF5E6CA) : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: selected ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA))),
    child: Row(children: [Icon(selected ? Icons.check_circle : Icons.circle_outlined, size: 20, color: const Color(0xFF5D4037)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey))])])));
  }

  Widget _buildContactPage() {
    return _buildFormContainer(child: Column(children: [
      _title('Contact Details', 'Contractor Information'),
      const SizedBox(height: 16),
      _plainTextField(_contactNameController, 'Contact Name', readOnly: true),
      _plainTextField(_contactPhoneController, 'Phone Number', readOnly: true),
      _plainTextField(TextEditingController(text: _aadharNumber), 'Aadhar Number', readOnly: true),
      _plainTextField(_estimatedAmountController, 'Total Estimated Cost', keyboard: TextInputType.number),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Site Photos', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
        Text('(At least 5 required)', style: GoogleFonts.poppins(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500))
      ]),
      const SizedBox(height: 12),
      ImagePickerWidget(
        maxImages: 10, 
        onImagesSelected: (imgs) => setState(() => _selectedImages = imgs)
      )
    ]));
  }

  Widget _buildNavigationButtons() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF5E6CA)))),
      child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: () { if (_currentPage > 0) { _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } else { Navigator.pop(context); } }, style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF5D4037), side: const BorderSide(color: Color(0xFF5D4037)), padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text('Back'))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton(onPressed: _isLoading ? null : () { if (_validateCurrentPage()) { if (_currentPage < 2) { _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } else { _createProject(); } } }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)), child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_currentPage < 2 ? 'Continue' : 'Submit Proposal'))),
      ]),
    );
  }

  Widget _title(String t, String s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E2723))), Text(s, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF8D6E63)))]);
  }

  Widget _dateField() {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF5E6CA))),
    child: Row(children: [const Icon(Icons.calendar_month, color: Color(0xFF5D4037), size: 20), const SizedBox(width: 12), Text(_selectedDate == null ? 'Visit Date' : DateFormat('dd-MM-yyyy').format(_selectedDate!), style: const TextStyle(fontSize: 14))]));
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => _selectedDate = picked);
  }
}