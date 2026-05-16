import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class BudgetReportScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  const BudgetReportScreen({super.key, required this.reportData});
  @override
  State<BudgetReportScreen> createState() => _BudgetReportScreenState();
}

class _BudgetReportScreenState extends State<BudgetReportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _isGeneratingPdf = false;

  static const Color bgTop    = Color(0xFFFFFDF5);
  static const Color bgBottom = Color(0xFFF5E6CA);
  static const Color primary  = Color(0xFF5D4037);
  static const Color cardBg   = Color(0xFFEFE6D5);
  static const Color textDark = Color(0xFF3E2723);
  static const Color textMid  = Color(0xFF8D6E63);
  static const Color success  = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  Map<String, dynamic> get damage    => widget.reportData['damage_analysis']  as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get breakdown => widget.reportData['budget_breakdown']  as Map<String, dynamic>? ?? {};
  String get summary   => widget.reportData['work_summary']    ?? '';
  int    get total     => widget.reportData['total_sanction']  ?? 0;
  String get district  => widget.reportData['district']        ?? '';
  double get sqft      => (widget.reportData['sqft'] ?? 0).toDouble();

  Color _severityColor(String s) {
    switch (s.toLowerCase()) {
      case 'minor':    return Colors.green.shade700;
      case 'moderate': return Colors.orange.shade800;
      case 'severe':   return Colors.red.shade800;
      default:         return textMid;
    }
  }

  // ── PDF Generation ────────────────────────────────────────────────
  Future<void> _downloadPdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = pw.Document();

      // Build breakdown rows
      final breakdownEntries = breakdown.entries.toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [

            // ── Header ───────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFF5D4037),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SHIVPUNARVA',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                  pw.SizedBox(height: 4),
                  pw.Text('Heritage Statue Preservation — Budget Quotation',
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── Quotation meta ───────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFEFE6D5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('District', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(district,
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF3E2723))),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Damage Area', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text('${sqft.toInt()} sqft',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF3E2723))),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Date', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(_todayDate(),
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF3E2723))),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── Damage Analysis ──────────────────────────────────
            pw.Text('DAMAGE ANALYSIS',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF5D4037))),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFEFE6D5)),
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _pdfRow('Damage Type',  damage['DAMAGE_TYPE']  ?? '-'),
                _pdfRow('Severity',     damage['SEVERITY']     ?? '-'),
                _pdfRow('Material',     damage['MATERIAL']     ?? '-'),
                _pdfRow('Affected Area',damage['AFFECTED_AREA']?? '-'),
                pw.SizedBox(height: 6),
                pw.Text(damage['DESCRIPTION'] ?? '',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ]),
            ),
            pw.SizedBox(height: 20),

            // ── Work Summary ─────────────────────────────────────
            pw.Text('WORK SUMMARY',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF5D4037))),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: const PdfColor.fromInt(0xFFEFE6D5)),
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(summary,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
                  textAlign: pw.TextAlign.justify),
            ),
            pw.SizedBox(height: 20),

            // ── Budget Breakdown Table ───────────────────────────
            pw.Text('BUDGET BREAKDOWN',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF5D4037))),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFEFE6D5)),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF5D4037)),
                  children: [
                    _tableHeader('Work Item'),
                    _tableHeader('Calculation'),
                    _tableHeader('Amount (Rs)'),
                  ],
                ),
                // Data rows
                ...breakdownEntries.asMap().entries.map((entry) {
                  final i    = entry.key;
                  final item = entry.value;
                  final data = item.value as Map<String, dynamic>;
                  final bg   = i.isEven
                      ? const PdfColor.fromInt(0xFFFFFDF5)
                      : PdfColors.white;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _tableCell(item.key),
                      _tableCell(data['calculation'] ?? ''),
                      _tableCell('Rs ${data['cost']}', bold: true),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),

            // ── Total ────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFF2E7D32),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL SANCTION AMOUNT',
                      style: pw.TextStyle(fontSize: 14,
                          fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('Rs $total',
                      style: pw.TextStyle(fontSize: 18,
                          fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // ── Footer ───────────────────────────────────────────
            pw.Divider(color: const PdfColor.fromInt(0xFFEFE6D5)),
            pw.SizedBox(height: 8),
            pw.Text('This budget quotation is generated by ShivPunarva AI System.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text('For official sanctioning, please submit this to the concerned authority.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      );

      // Save to Downloads folder
      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ShivPunarva_Budget_${district}_${_todayDate().replaceAll('/', '-')}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Open the PDF
      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('PDF saved: ${file.path.split('/').last}',
                style: GoogleFonts.poppins(fontSize: 12))),
          ]),
          backgroundColor: success, behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF Error: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      print('PDF error: $e');
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  // PDF helper widgets
  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(children: [
        pw.SizedBox(width: 100,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
        pw.Text(': ',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF3E2723))),
      ]),
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );
  }

  pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: const PdfColor.fromInt(0xFF3E2723))),
    );
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgTop,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
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
                  Text('Budget Report',
                      style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: textDark)),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF8D6E63)),
                    const SizedBox(width: 4),
                    Text('$district District',
                        style: GoogleFonts.poppins(fontSize: 12, color: textMid)),
                  ]),
                ]),
              ]),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Total Amount Banner
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: success.withOpacity(0.3),
                          blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.account_balance_wallet_rounded,
                              color: Colors.white, size: 28)),
                      const SizedBox(width: 16),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Total Sanction Amount',
                            style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.85), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Rs $total',
                            style: GoogleFonts.cinzel(
                                color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Damage Analysis Card
                  _card(
                    title: 'Damage Analysis',
                    icon: Icons.search_rounded,
                    iconColor: Colors.orange.shade800,
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: _chip('Type',     damage['DAMAGE_TYPE'] ?? '-', primary)),
                        const SizedBox(width: 10),
                        Expanded(child: _chip('Severity', damage['SEVERITY']    ?? '-',
                            _severityColor(damage['SEVERITY'] ?? ''))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _chip('Material', damage['MATERIAL']     ?? '-', const Color(0xFF5D4037))),
                        const SizedBox(width: 10),
                        Expanded(child: _chip('Area',     damage['AFFECTED_AREA']?? '-', const Color(0xFF1565C0))),
                      ]),
                      if ((damage['DESCRIPTION'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFFFDF5),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(damage['DESCRIPTION'] ?? '',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: textMid, height: 1.5))),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Work Summary Card
                  _card(
                    title: 'Work Summary',
                    icon: Icons.description_rounded,
                    iconColor: const Color(0xFF1565C0),
                    child: Text(summary,
                        style: GoogleFonts.poppins(fontSize: 14, color: textMid, height: 1.6)),
                  ),
                  const SizedBox(height: 16),

                  // Budget Breakdown Card
                  _card(
                    title: 'Budget Breakdown',
                    icon: Icons.receipt_long_rounded,
                    iconColor: success,
                    child: Column(children: [
                      ...breakdown.entries.toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final item  = entry.value;
                        final data  = item.value as Map<String, dynamic>;
                        final isLast = index == breakdown.length - 1;
                        return Column(children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 6, height: 6,
                                  margin: const EdgeInsets.only(top: 6, right: 10),
                                  decoration: BoxDecoration(
                                      color: primary, shape: BoxShape.circle)),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.key, style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600, color: textDark, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(data['calculation'] ?? '',
                                      style: GoogleFonts.poppins(fontSize: 12, color: textMid)),
                                ],
                              )),
                              Text('Rs ${data['cost']}',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700, color: textDark, fontSize: 15)),
                            ]),
                          ),
                          if (!isLast) const Divider(height: 1, color: Color(0xFFE8DDD0)),
                        ]);
                      }),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: success.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: success.withOpacity(0.2))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Total Sanction', style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800, fontSize: 16, color: textDark)),
                          Text('Rs $total', style: GoogleFonts.cinzel(
                              fontWeight: FontWeight.bold, fontSize: 18, color: success)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),

                  // ── Download PDF Button ───────────────────────
                  SizedBox(
                    width: double.infinity, height: 58,
                    child: ElevatedButton.icon(
                      onPressed: _isGeneratingPdf ? null : _downloadPdf,
                      icon: _isGeneratingPdf
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf_rounded,
                              color: Colors.white, size: 24),
                      label: Text(
                        _isGeneratingPdf ? 'Generating PDF...' : 'Download Budget as PDF',
                        style: GoogleFonts.poppins(
                            fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          disabledBackgroundColor:
                              const Color(0xFF1565C0).withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ])),
        ),
      ),
    );
  }

  Widget _card({required String title, required IconData icon,
      required Color iconColor, required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8DDD0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.cinzel(
              fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(value.toUpperCase(), style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}