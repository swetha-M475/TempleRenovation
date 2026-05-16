import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/budget_api_service.dart';
import 'budget_report_screen.dart';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});
  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  File? _selectedImage;
  final _sqftController      = TextEditingController();

  final _districtController  = TextEditingController();   // ← manual district
  bool  _isLoading           = false;
  String _errorMessage       = '';
  final ImagePicker _picker  = ImagePicker();

  static const Color bgTop    = Color(0xFFFFFDF5);
  static const Color bgBottom = Color(0xFFF5E6CA);
  static const Color primary  = Color(0xFF5D4037);
  static const Color cardBg   = Color(0xFFEFE6D5);
  static const Color textDark = Color(0xFF3E2723);
  static const Color textMid  = Color(0xFF8D6E63);

  // Tamil Nadu districts list for dropdown suggestions
  static const List<String> _tnDistricts = [
    'Ariyalur','Chengalpattu','Chennai','Coimbatore','Cuddalore',
    'Dharmapuri','Dindigul','Erode','Kallakurichi','Kancheepuram',
    'Kanyakumari','Karur','Krishnagiri','Madurai','Mayiladuthurai',
    'Nagapattinam','Namakkal','Nilgiris','Perambalur','Pudukkottai',
    'Ramanathapuram','Ranipet','Salem','Sivaganga','Tenkasi',
    'Thanjavur','Theni','Thoothukudi','Tiruchirappalli','Tirunelveli',
    'Tirupathur','Tiruppur','Tiruvallur','Tiruvannamalai','Tiruvarur',
    'Vellore','Villupuram','Virudhunagar',
  ];

  @override
  void dispose() {
    _sqftController.dispose();

    _districtController.dispose();
    super.dispose();
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgTop, borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Add Damage Photo',
              style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 6),
          Text('Choose source to upload photo',
              style: GoogleFonts.poppins(fontSize: 13, color: textMid)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _pickerOption(icon: Icons.camera_alt_rounded, label: 'Camera',
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            _pickerOption(icon: Icons.photo_library_rounded, label: 'Gallery',
                onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ]),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _pickerOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130, padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary.withOpacity(0.2))),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: primary, size: 28)),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textDark, fontSize: 14)),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _submitReport() async {
    // ── Validations ────────────────────────────────────────────
    if (_selectedImage == null)              { _showSnack('Please add a damage photo'); return; }
    if (_districtController.text.trim().isEmpty) { _showSnack('Please enter the district'); return; }
    if (_sqftController.text.trim().isEmpty) { _showSnack('Please enter the damage area in sqft'); return; }


    final sqftValue = double.tryParse(_sqftController.text.trim());
    if (sqftValue == null)                   { _showSnack('Please enter a valid number for sqft'); return; }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final result = await BudgetApiService.analyzeDamage(
        imageFile:       _selectedImage!,
        sqft:            sqftValue,
        district:        _districtController.text.trim(),
      );

      // ── Check if backend flagged image as invalid ──────────
      final damageAnalysis = result['damage_analysis'] as Map<String, dynamic>? ?? {};
      final isInvalid = damageAnalysis['IS_INVALID_IMAGE'] == true ||
          (damageAnalysis['DAMAGE_TYPE'] ?? '').toString().toLowerCase().contains('invalid') ||
          (damageAnalysis['DAMAGE_TYPE'] ?? '').toString().toLowerCase().contains('not a statue') ||
          (damageAnalysis['DAMAGE_TYPE'] ?? '').toString().toLowerCase().contains('unrelated');

      if (isInvalid && mounted) {
        _showInvalidImageDialog(damageAnalysis['DESCRIPTION'] ?? 'This image does not appear to be a heritage statue or temple. Please upload a relevant photo.');
        return;
      }

      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => BudgetReportScreen(reportData: result)));
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      _showSnack('Error: ${e.toString()}');
      print('API ERROR: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Invalid image popup ────────────────────────────────────────────
  void _showInvalidImageDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.image_not_supported_rounded,
                  color: Colors.orange.shade700, size: 44),
            ),
            const SizedBox(height: 18),
            Text('Invalid Image',
                style: GoogleFonts.cinzel(
                    fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 10),
            Text(reason,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: textMid, height: 1.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    'Please upload a clear photo of the damaged heritage statue or temple.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.orange.shade800))),
              ]),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _selectedImage = null); // clear wrong image
                },
                icon: const Icon(Icons.upload_rounded, color: Colors.white),
                label: Text('Upload Correct Photo',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: primary, elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: primary, duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [bgTop, bgBottom]),
        ),
        child: SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_back_ios_rounded, color: primary, size: 18)),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Report Damage',
                    style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                Text('AI will generate budget automatically',
                    style: GoogleFonts.poppins(fontSize: 11, color: textMid)),
              ]),
            ]),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Photo ────────────────────────────────────────
                _label('Damage Photo', required: true),
                const SizedBox(height: 10),
                _photoCard(),
                const SizedBox(height: 20),

                // ── District — manual input with suggestions ─────
                _label('District', required: true),
                const SizedBox(height: 4),
                Text('Enter your Tamil Nadu district',
                    style: GoogleFonts.poppins(fontSize: 12, color: textMid)),
                const SizedBox(height: 10),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue val) {
                    if (val.text.isEmpty) return const Iterable<String>.empty();
                    return _tnDistricts.where((d) =>
                        d.toLowerCase().contains(val.text.toLowerCase()));
                  },
                  onSelected: (String selection) {
                    _districtController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    controller.text = _districtController.text;
                    controller.addListener(() => _districtController.text = controller.text);
                    final border = OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF5D4037), width: 1.5),
                    );
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF3E2723),
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: const Color(0xFF5D4037),
                      decoration: InputDecoration(
                        hintText: 'e.g. Coimbatore',
                        hintStyle: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13),
                        prefixIcon: const Icon(Icons.location_city_rounded,
                            color: Color(0xFF5D4037), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: border,
                        enabledBorder: border,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF3E2723), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.location_on_rounded,
                                    color: Color(0xFF5D4037), size: 16),
                                title: Text(option,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF3E2723),
                                      fontWeight: FontWeight.w500,
                                    )),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ── Sqft ─────────────────────────────────────────
                _label('Damage Area (sqft)', required: true),
                const SizedBox(height: 10),
                TextField(
                  controller: _sqftController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF3E2723),
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFF5D4037),
                  decoration: InputDecoration(
                    hintText: 'e.g. 25',
                    hintStyle: const TextStyle(color: Color(0xFF8D6E63), fontSize: 14),
                    suffixText: 'sqft',
                    suffixStyle: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13),
                    prefixIcon: const Icon(Icons.straighten_rounded,
                        color: Color(0xFF5D4037), size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF5D4037), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF5D4037), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF3E2723), width: 2.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 20),

                const SizedBox(height: 16),

                // ── Error card ───────────────────────────────────
                if (_errorMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                        const SizedBox(width: 6),
                        Text('Connection Error',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700,
                                color: Colors.red.shade700, fontSize: 13)),
                      ]),
                      const SizedBox(height: 6),
                      Text(_errorMessage,
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade800)),
                      const SizedBox(height: 8),
                      Text('Make sure:\n• Backend is running (uvicorn main:app --host 0.0.0.0 --reload)\n• Phone & PC on same WiFi\n• IP is correct in budget_api_service.dart',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade700)),
                    ]),
                  ),

                const SizedBox(height: 20),
                _submitButton(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ])),
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(children: [
      Text(text, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
      if (required) Text(' *',
          style: TextStyle(color: Colors.red.shade400, fontSize: 14, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _styledTextField({
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required IconData icon,
    String? suffix,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF5D4037), width: 1.5),
    );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF3E2723),
        fontWeight: FontWeight.w500,
      ),
      cursorColor: const Color(0xFF5D4037),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13),
        prefixIcon: Padding(
          padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
          child: Align(
            alignment: maxLines > 1 ? Alignment.topCenter : Alignment.center,
            child: Icon(icon, color: const Color(0xFF5D4037), size: 20),
          ),
        ),
        suffixText: suffix,
        suffixStyle: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3E2723), width: 2),
        ),
        errorBorder: border,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _photoCard() {
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        height: 200, width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _selectedImage != null ? primary : primary.withOpacity(0.4),
              width: _selectedImage != null ? 2 : 1.5),
        ),
        child: _selectedImage != null
            ? Stack(fit: StackFit.expand, children: [
                ClipRRect(borderRadius: BorderRadius.circular(15),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover)),
                Positioned(bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: primary.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.edit_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text('Change', style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    )),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.add_a_photo_rounded, color: primary, size: 30)),
                const SizedBox(height: 14),
                Text('Tap to add damage photo',
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600, color: textDark)),
                const SizedBox(height: 4),
                Text('Camera or Gallery',
                    style: GoogleFonts.poppins(fontSize: 12, color: textMid)),
              ]),
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        icon: _isLoading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
        label: Text(_isLoading ? 'Analyzing damage...' : 'Analyze & Generate Budget',
            style: GoogleFonts.poppins(
                fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
            backgroundColor: primary, disabledBackgroundColor: primary.withOpacity(0.5),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _isLoading ? null : _submitReport,
      ),
    );
  }
}