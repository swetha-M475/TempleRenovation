import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// Ensure these files exist in your project
import 'map_picker_screen.dart'; 
import '../services/cloudinary_service.dart';
import '../services/temple_detection_service.dart';
import '../models/temple_detection_result.dart';
import '../widgets/detection_result_dialog.dart';

/// Model to hold data for each individual work/task entry
class WorkEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  String? localImagePath; // Optional image for this specific work

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    amountController.dispose();
  }
}

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final String _mapboxApiKey = "YOUR_MAPBOX_TOKEN"; // Redacted for GitHub push

  final _pageController = PageController();
  int _currentPage = 0;

  // -- STEP 1: LOCATION CONTROLLERS --
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _talukController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController(text: "Tamil Nadu");
  final TextEditingController _mapLocationController = TextEditingController();

  TextEditingController? _autoDistrictController;
  TextEditingController? _autoTalukController;

  // -- STEP 2: MULTIPLE WORKS --
  // Initialize with one empty work entry
  List<WorkEntry> _workEntries = [WorkEntry()];

  // -- STEP 3: CONTACT & TOTALS --
  final TextEditingController _localPersonNameController = TextEditingController(); 
  final TextEditingController _localPersonPhoneController = TextEditingController();
  final TextEditingController _estimatedAmountController = TextEditingController();

  DateTime? _selectedDate;
  List<String> _selectedImages = []; // Main site images
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // -- TEMPLE DETECTION --
  final TempleDetectionService _detectionService = TempleDetectionService();
  bool _isDetecting = false;
  // Store detection results per image path for showing badges
  final Map<String, TempleDetectionResult> _detectionResults = {};

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

  @override
  void initState() {
    super.initState();
    // Pre-load detection model for faster first-scan
    _detectionService.loadModel();
  }

  @override
  void dispose() {
    for (var entry in _workEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  // Calculate Total sum of all work entry amounts
  void _calculateTotalEstimate() {
    double total = 0;
    for (var entry in _workEntries) {
      total += double.tryParse(entry.amountController.text) ?? 0.0;
    }
    setState(() {
      _estimatedAmountController.text = total > 0 ? total.toStringAsFixed(2) : "";
    });
  }

  // Pick an image for a specific work item — with detection gate
  Future<void> _pickWorkImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      final approved = await _runDetectionGate(image.path);
      if (approved) {
        setState(() => _workEntries[index].localImagePath = image.path);
      }
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapPickerScreen(mapboxApiKey: _mapboxApiKey)),
    );
    if (result != null && result is Map) {
      setState(() {
        _mapLocationController.text = "${result['lat'].toStringAsFixed(6)}, ${result['lng'].toStringAsFixed(6)}";
        if (result['place'] != null) _placeController.text = result['place'];
        if (result['district'] != null) {
          _districtController.text = result['district'];
          _autoDistrictController?.text = result['district'];
        }
        if (result['state'] != null) _stateController.text = result['state'];
        _talukController.clear();
        _autoTalukController?.clear();
      });
    }
  }

  // Site photo picker — with detection gate for EACH image
  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await _picker.pickMultiImage(imageQuality: 70);
        if (images.isEmpty) return;

        // Validate each image individually
        int approved = 0;
        int rejected = 0;
        for (int i = 0; i < images.length; i++) {
          final imgPath = images[i].path;
          final isApproved = await _runDetectionGate(imgPath);
          if (isApproved) {
            setState(() => _selectedImages.add(imgPath));
            approved++;
          } else {
            rejected++;
          }
        }

        // Show summary if multiple images were picked
        if (images.length > 1 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$approved approved, $rejected rejected out of ${images.length} images'),
            backgroundColor: rejected == 0 ? const Color(0xFF2D6A4F) : const Color(0xFFE65100),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        // Camera: single image
        final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
        if (image != null) {
          final isApproved = await _runDetectionGate(image.path);
          if (isApproved) {
            setState(() => _selectedImages.add(image.path));
          }
        }
      }
    } catch (e) {
      _showWarning('Failed to pick image: $e');
    }
  }

  // ── DETECTION GATE ─────────────────────────────────────────
  // Runs detection on an image and shows results dialog.
  // Returns true if approved, false if rejected.
  Future<bool> _runDetectionGate(String imagePath) async {
    // Show scanning overlay
    setState(() => _isDetecting = true);

    try {
      final result = await _detectionService.detectFromFile(File(imagePath));
      setState(() => _isDetecting = false);

      if (!mounted) return false;

      // Store result for badge display
      _detectionResults[imagePath] = result;

      // Show detection result dialog
      final approved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DetectionResultDialog(
          imagePath: imagePath,
          result: result,
        ),
      );

      return approved ?? false;
    } catch (e) {
      setState(() => _isDetecting = false);
      _showWarning('Detection failed: $e');
      return false;
    }
  }

  bool _validateCurrentPage() {
    if (_currentPage == 0) {
      final String dist = _autoDistrictController?.text.trim() ?? _districtController.text.trim();
      final String taluk = _autoTalukController?.text.trim() ?? _talukController.text.trim();
      if (_placeController.text.isEmpty) return _showWarning('Place name is required');
      if (dist.isEmpty) return _showWarning('District is required');
      if (taluk.isEmpty) return _showWarning('Taluk is required');
      if (_mapLocationController.text.isEmpty) return _showWarning('Pick a location on map');
      if (_selectedDate == null) return _showWarning('Select a visit date');
      return true;
    }
    
    if (_currentPage == 1) {
      for (int i = 0; i < _workEntries.length; i++) {
        if (_workEntries[i].nameController.text.trim().isEmpty) {
          return _showWarning('Work Name is required for entry #${i+1}');
        }
        if (_workEntries[i].descriptionController.text.trim().isEmpty) {
          return _showWarning('Work Description is required for entry #${i+1}');
        }
      }
      return true;
    }

    if (_currentPage == 2) {
      if (_localPersonNameController.text.isEmpty) return _showWarning('Local person name is required');
      if (_localPersonPhoneController.text.isEmpty) return _showWarning('Local person phone is required');
      if (_selectedImages.length < 5) return _showWarning('At least 5 site images are required');
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

  // --- HELPER: GET 4 LETTER PREFIX ---
  String _getPrefixCode(String value) {
    String cleanVal = value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleanVal.length >= 4) {
      return cleanVal.substring(0, 4);
    }
    return cleanVal; // Return as is if it's shorter than 4 characters
  }

  Future<void> _createProject() async {
    if (!_validateCurrentPage()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final String rawId = const Uuid().v4();

      final String finalDist = _autoDistrictController?.text.trim() ?? _districtController.text.trim();
      final String finalPlace = _placeController.text.trim();
      final String finalTaluk = _autoTalukController?.text.trim() ?? _talukController.text.trim();

      // --- CUSTOM ID GENERATION LOGIC ---
      String distCode = _getPrefixCode(finalDist);
      String placeCode = _getPrefixCode(finalPlace);

      // Query to find how many projects already exist in this specific place to make it unique
      final existingProjectsQuery = await FirebaseFirestore.instance
          .collection('projects')
          .where('place', isEqualTo: finalPlace)
          .where('district', isEqualTo: finalDist)
          .get();

      int sequentialNumber = existingProjectsQuery.docs.length + 1;
      String uniqueNumCode = sequentialNumber.toString().padLeft(3, '0'); // e.g. 001, 002

      final String projectDisplayId = "${distCode}_${placeCode}_$uniqueNumCode";

      // 1. Upload Main Site Photos
      final List<String> mainUploadedUrls = [];
      for (final imgPath in _selectedImages) {
        final url = await CloudinaryService.uploadImage(imageFile: XFile(imgPath), userId: user.uid, projectId: projectDisplayId);
        if (url != null) mainUploadedUrls.add(url);
      }

      // 2. Upload Individual Work Images and Build Works List
      List<Map<String, dynamic>> worksList = [];
      for (var entry in _workEntries) {
        String workImgUrl = "";
        if (entry.localImagePath != null) {
          final url = await CloudinaryService.uploadImage(
            imageFile: XFile(entry.localImagePath!), 
            userId: user.uid, 
            projectId: "$projectDisplayId-WORK"
          );
          if (url != null) workImgUrl = url;
        }

        worksList.add({
          'workName': entry.nameController.text.trim(),
          'workDescription': entry.descriptionController.text.trim(),
          'amount': entry.amountController.text.trim(),
          'workImageUrl': workImgUrl,
        });
      }

      // 3. Save to Firestore
      await FirebaseFirestore.instance.collection('projects').doc(rawId).set({
        'projectId': projectDisplayId,
        'userId': user.uid,
        'place': finalPlace,
        'taluk': finalTaluk,
        'district': finalDist,
        'state': _stateController.text.trim(),
        'mapLocation': _mapLocationController.text.trim(),
        'visitDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
        
        'works': worksList, // Array of Work Maps
        
        'localPersonName': _localPersonNameController.text.trim(),
        'localPersonPhone': _localPersonPhoneController.text.trim(),
        'estimatedAmount': _estimatedAmountController.text.trim(),
        'imageUrls': mainUploadedUrls,
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

  // --- PAGE BUILDERS ---

  Widget _buildLocationPage() {
    return _buildFormContainer(
      child: Column(
        children: [
          _title('Location Info', 'Enter details of the site'),
          const SizedBox(height: 16),
          _plainTextField(_placeController, 'Site / Place Name'),
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
                child: IconButton(icon: const Icon(Icons.map_outlined, color: Colors.white), onPressed: _openMapPicker),
              ),
            ],
          ),
          InkWell(onTap: () => _selectDate(context), child: _dateField()),
        ],
      ),
    );
  }

  Widget _buildFeaturePage() {
    return _buildFormContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Select Features', 'Add multiple works for this project'),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _workEntries.length,
            itemBuilder: (context, index) => _buildWorkCard(index),
          ),
          const SizedBox(height: 10),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _workEntries.add(WorkEntry())),
              icon: const Icon(Icons.add),
              label: const Text("Add Another Work"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF5D4037),
                side: const BorderSide(color: Color(0xFF5D4037)),
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildWorkCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5E6CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Work #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D4037))),
              if (_workEntries.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => setState(() {
                    _workEntries[index].dispose();
                    _workEntries.removeAt(index);
                    _calculateTotalEstimate();
                  }),
                ),
            ],
          ),
          
          _plainTextField(_workEntries[index].nameController, 'Name of Work *'),
          _plainTextField(_workEntries[index].descriptionController, 'Description *', maxLines: 2),
          
          // 1. Amount on its own line (Full width)
          _plainTextField(
            _workEntries[index].amountController, 
            'Amount (Optional)', 
            keyboard: TextInputType.number,
            onChanged: (v) => _calculateTotalEstimate(),
          ),
          
          const SizedBox(height: 4),
          
          // 2. Label on the next line
          Text(
            'Add requirement in written form\n(Image) Optional', 
            style: GoogleFonts.poppins(
              fontSize: 12, 
              color: const Color(0xFF8D6E63),
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 3. Image upload icon after the label — with detection badge
          InkWell(
            onTap: _isDetecting ? null : () => _pickWorkImage(index),
            child: Stack(
              children: [
                Container(
                  height: 60, width: 60, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100, 
                    borderRadius: BorderRadius.circular(8), 
                    border: Border.all(
                      color: _workEntries[index].localImagePath != null &&
                             _detectionResults.containsKey(_workEntries[index].localImagePath)
                          ? const Color(0xFF2D6A4F)
                          : const Color(0xFFF5E6CA),
                      width: _workEntries[index].localImagePath != null &&
                             _detectionResults.containsKey(_workEntries[index].localImagePath)
                          ? 2 : 1,
                    ),
                  ),
                  child: _workEntries[index].localImagePath == null
                      ? const Icon(Icons.add_a_photo, size: 24, color: Colors.grey)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(7), 
                          child: Image.file(
                            File(_workEntries[index].localImagePath!), 
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
                // Detection checkmark badge
                if (_workEntries[index].localImagePath != null &&
                    _detectionResults.containsKey(_workEntries[index].localImagePath))
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D6A4F),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactPage() {
    return _buildFormContainer(
      child: Column(children: [
        _title('Contact Details', 'Local Person / Site Information'),
        const SizedBox(height: 16),
        _plainTextField(_localPersonNameController, 'Local Person Name'),
        _plainTextField(_localPersonPhoneController, 'Local Person Phone', keyboard: TextInputType.phone),
        _plainTextField(_estimatedAmountController, 'Total Estimated Cost', keyboard: TextInputType.number),
        const SizedBox(height: 20),
        _buildImageSection(),
      ]),
    );
  }

  // --- REUSABLE UI COMPONENTS ---

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

  Widget _plainTextField(TextEditingController c, String label, {TextInputType keyboard = TextInputType.text, bool readOnly = false, int maxLines = 1, void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c, 
        keyboardType: keyboard, 
        readOnly: readOnly,
        maxLines: maxLines,
        onChanged: onChanged,
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

  Widget _buildImageSection() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Site Photos', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold)),
          Text('(${_selectedImages.length} / 5 min)', style: TextStyle(color: _selectedImages.length < 5 ? Colors.red : Colors.green)),
        ]),
        const SizedBox(height: 4),
        Text('Each photo will be scanned for temple elements',
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF8D6E63))),
        const SizedBox(height: 12),

        // Scanning indicator
        if (_isDetecting)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF5D4037).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF5D4037))),
                const SizedBox(width: 14),
                Text('Scanning for temple elements...',
                    style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF5D4037), fontWeight: FontWeight.w500)),
              ],
            ),
          ),

        // Image thumbnails with detection badges
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (ctx, i) {
                final imgPath = _selectedImages[i];
                final detection = _detectionResults[imgPath];
                return Stack(children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: detection != null && detection.isApproved
                            ? const Color(0xFF2D6A4F)
                            : Colors.transparent,
                        width: 2,
                      ),
                      image: DecorationImage(
                        image: FileImage(File(imgPath)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Delete button
                  Positioned(top: 0, right: 8,
                    child: InkWell(
                      onTap: () => setState(() {
                        _selectedImages.removeAt(i);
                        _detectionResults.remove(imgPath);
                      }),
                      child: const CircleAvatar(radius: 10, backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 12, color: Colors.white)),
                    ),
                  ),
                  // Detection badge
                  if (detection != null)
                    Positioned(bottom: 0, left: 0, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6A4F).withOpacity(0.85),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          detection.bestClass != null
                              ? '${detection.bestClass} ${(detection.highestConfidence * 100).toStringAsFixed(0)}%'
                              : 'No detection',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ]);
              },
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: _isDetecting ? null : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt), label: const Text("Camera"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF5D4037).withOpacity(0.4)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: _isDetecting ? null : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library), label: const Text("Gallery"),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF5D4037), side: const BorderSide(color: Color(0xFF5D4037))))),
        ]),
      ],
    );
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

  Widget _buildDistrictAutocomplete() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        optionsBuilder: (v) => v.text.isEmpty ? const Iterable<String>.empty() : _tnDistricts.where((d) => d.toLowerCase().startsWith(v.text.toLowerCase())),
        onSelected: (s) => setState(() { _districtController.text = s; _autoDistrictController?.text = s; _talukController.clear(); }),
        fieldViewBuilder: (ctx, ctrl, focus, submit) { _autoDistrictController = ctrl; if (ctrl.text.isEmpty && _districtController.text.isNotEmpty) ctrl.text = _districtController.text; return _buildStyledTextField(ctrl, focus, 'District', submit); },
      ),
    );
  }

  Widget _buildTalukAutocomplete() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        optionsBuilder: (v) {
          final d = _autoDistrictController?.text ?? _districtController.text;
          if (d.isEmpty || v.text.isEmpty) return const Iterable<String>.empty();
          return (_districtTaluks[d] ?? []).where((t) => t.toLowerCase().startsWith(v.text.toLowerCase()));
        },
        onSelected: (s) => setState(() { _talukController.text = s; _autoTalukController?.text = s; }),
        fieldViewBuilder: (ctx, ctrl, focus, submit) { _autoTalukController = ctrl; if (ctrl.text.isEmpty && _talukController.text.isNotEmpty) ctrl.text = _talukController.text; return _buildStyledTextField(ctrl, focus, 'Taluk', submit, enabled: (_autoDistrictController?.text.isNotEmpty ?? false)); },
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController c, FocusNode f, String l, VoidCallback s, {bool enabled = true}) {
    return TextFormField(controller: c, focusNode: f, enabled: enabled, onFieldSubmitted: (v) => s(), decoration: InputDecoration(labelText: l, filled: true, fillColor: enabled ? Colors.white : Colors.grey.shade100, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF5E6CA))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5D4037))), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
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