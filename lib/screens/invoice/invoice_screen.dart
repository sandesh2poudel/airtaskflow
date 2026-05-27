// lib/screens/invoice/invoice_screen.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../widgets/glass_card.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});
  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _clientCtrl  = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _totalCtrl   = TextEditingController();
  final _pay1Ctrl    = TextEditingController();
  final _pay2Ctrl    = TextEditingController();
  final _notesCtrl   = TextEditingController();
  String _invoiceDate = DateHelper.today();
  String _dueDate     = '';
  bool   _previewing  = false;
  bool   _exporting   = false;

  @override
  void dispose() {
    _clientCtrl.dispose(); _emailCtrl.dispose(); _companyCtrl.dispose();
    _descCtrl.dispose(); _totalCtrl.dispose(); _pay1Ctrl.dispose();
    _pay2Ctrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  // ── PDF Generation ────────────────────────────────────────────
  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final total   = double.tryParse(_totalCtrl.text) ?? 0;
      final pay1    = double.tryParse(_pay1Ctrl.text)  ?? 0;
      final pay2    = double.tryParse(_pay2Ctrl.text)  ?? 0;
      final balance = total - pay1 - pay2;
      final invoiceNum =
          'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final pdf = pw.Document();

      // ── Colours ──────────────────────────────────────────────
      const headerBlue   = PdfColor.fromInt(0xFF4F46E5); // accent
      const headerPurple = PdfColor.fromInt(0xFF7C3AED); // accent2
      const darkText     = PdfColor.fromInt(0xFF111827);
      const mutedText    = PdfColor.fromInt(0xFF6B7280);
      const borderColor  = PdfColor.fromInt(0xFFE5E7EB);
      const bgLight      = PdfColor.fromInt(0xFFF9FAFB);
      const white        = PdfColors.white;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Header gradient bar ───────────────────────
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 40, vertical: 32),
                  decoration: const pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [headerBlue, headerPurple],
                      begin: pw.Alignment.centerLeft,
                      end: pw.Alignment.centerRight,
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Company info
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nexra Digital LLC',
                              style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: white)),
                          pw.SizedBox(height: 4),
                          pw.Text('Digital Marketing Service',
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColor(1, 1, 1, 0.7))),
                          pw.SizedBox(height: 4),
                          pw.Text('www.nexradigitalllc.com.info',
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColor(1, 1, 1, 0.7))),
                        ],
                      ),
                      // Invoice info
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('INVOICE',
                              style: pw.TextStyle(
                                  fontSize: 28,
                                  fontWeight: pw.FontWeight.bold,
                                  color: white,
                                  letterSpacing: 2)),
                          pw.SizedBox(height: 4),
                          pw.Text(invoiceNum,
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColor(1, 1, 1, 0.7))),
                          pw.SizedBox(height: 4),
                          pw.Text('Date: $_invoiceDate',
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColor(1, 1, 1, 0.7))),
                          if (_dueDate.isNotEmpty)
                            pw.Text('Due: $_dueDate',
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    color: PdfColor(1, 1, 1, 0.7))),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Body ─────────────────────────────────────
                pw.Padding(
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [

                      // Bill To
                      pw.Text('BILL TO',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: mutedText,
                              letterSpacing: 1.5)),
                      pw.SizedBox(height: 8),
                      pw.Text(_clientCtrl.text,
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: darkText)),
                      if (_companyCtrl.text.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(_companyCtrl.text,
                            style: pw.TextStyle(
                                fontSize: 13, color: mutedText)),
                      ],
                      if (_emailCtrl.text.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(_emailCtrl.text,
                            style: pw.TextStyle(
                                fontSize: 11, color: mutedText)),
                      ],

                      pw.SizedBox(height: 28),

                      // Description table
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: borderColor),
                          borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Column(
                          children: [
                            // Table header
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: const pw.BoxDecoration(
                                color: bgLight,
                                borderRadius: pw.BorderRadius.only(
                                  topLeft: pw.Radius.circular(6),
                                  topRight: pw.Radius.circular(6),
                                ),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Expanded(
                                    flex: 3,
                                    child: pw.Text('DESCRIPTION',
                                        style: pw.TextStyle(
                                            fontSize: 10,
                                            fontWeight: pw.FontWeight.bold,
                                            color: mutedText,
                                            letterSpacing: 1)),
                                  ),
                                  pw.Text('AMOUNT (AUD)',
                                      style: pw.TextStyle(
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                          color: mutedText,
                                          letterSpacing: 1)),
                                ],
                              ),
                            ),
                            // Table row
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(16),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Expanded(
                                    flex: 3,
                                    child: pw.Text(_descCtrl.text,
                                        style: pw.TextStyle(
                                            fontSize: 13, color: darkText)),
                                  ),
                                  pw.Text(
                                      '\$${total.toStringAsFixed(2)}',
                                      style: pw.TextStyle(
                                          fontSize: 13,
                                          fontWeight: pw.FontWeight.bold,
                                          color: darkText)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 16),

                      // Payment summary — right aligned
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.SizedBox(
                          width: 260,
                          child: pw.Column(
                            children: [
                              if (pay1 > 0)
                                _pdfPayRow('1st Installment', pay1,
                                    false, darkText, mutedText),
                              if (pay2 > 0)
                                _pdfPayRow('2nd Installment', pay2,
                                    false, darkText, mutedText),
                              pw.Divider(color: borderColor, thickness: 1),
                              _pdfPayRow('Total Amount', total,
                                  false, darkText, mutedText),
                              _pdfPayRow('Amount Received', pay1 + pay2,
                                  false, darkText, mutedText),
                              pw.Divider(
                                  color: headerBlue, thickness: 1.5),
                              _pdfPayRow('BALANCE DUE', balance,
                                  true, headerBlue, headerBlue),
                            ],
                          ),
                        ),
                      ),

                      // Notes
                      if (_notesCtrl.text.isNotEmpty) ...[
                        pw.SizedBox(height: 24),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(14),
                          decoration: pw.BoxDecoration(
                            color: bgLight,
                            border: pw.Border.all(color: borderColor),
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(6)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('NOTES',
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: mutedText,
                                      letterSpacing: 1)),
                              pw.SizedBox(height: 6),
                              pw.Text(_notesCtrl.text,
                                  style: pw.TextStyle(
                                      fontSize: 12, color: mutedText)),
                            ],
                          ),
                        ),
                      ],

                      pw.SizedBox(height: 32),

                      // Footer
                      pw.Center(
                        child: pw.Text(
                          'Thank you for your business!',
                          style: pw.TextStyle(
                              fontSize: 13,
                              color: mutedText,
                              fontStyle: pw.FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // ── Print / Save / Share ──────────────────────────────────
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice-$invoiceNum.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.red,
        ));
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  // ── PDF pay row helper ────────────────────────────────────────
  pw.Widget _pdfPayRow(String label, double amount, bool highlight,
      PdfColor labelColor, PdfColor valueColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: highlight
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: labelColor)),
          pw.Text('\$${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: valueColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invoice Generator',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText)),
                      Text('Generate professional invoices for clients',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkText2
                                  : AppColors.lightText2)),
                    ]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!_previewing) _buildForm(isDark) else _buildPreview(isDark),
        ],
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Client Details', Icons.person_outline, isDark),
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _field('Client Name *', _clientCtrl, isDark, minWidth: 200),
                  _field('Company / Institution', _companyCtrl, isDark,
                      minWidth: 200),
                  _field('Email Address', _emailCtrl, isDark, minWidth: 200),
                ]),
                const SizedBox(height: 20),
                _sectionTitle(
                    'Invoice Details', Icons.receipt_outlined, isDark),
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _field('Description / Task *', _descCtrl, isDark,
                      minWidth: 300, maxLines: 2),
                  _field('Total Amount (AUD) *', _totalCtrl, isDark,
                      keyboardType: TextInputType.number),
                  _field('1st Payment (AUD)', _pay1Ctrl, isDark,
                      keyboardType: TextInputType.number),
                  _field('2nd Payment (AUD)', _pay2Ctrl, isDark,
                      keyboardType: TextInputType.number),
                  SizedBox(
                    width: 160,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Invoice Date', isDark),
                          const SizedBox(height: 4),
                          _datePicker('Invoice Date', _invoiceDate,
                                  (v) => setState(() => _invoiceDate = v), isDark),
                        ]),
                  ),
                  SizedBox(
                    width: 160,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Due Date', isDark),
                          const SizedBox(height: 4),
                          _datePicker('Due Date', _dueDate,
                                  (v) => setState(() => _dueDate = v), isDark),
                        ]),
                  ),
                  _field('Additional Notes', _notesCtrl, isDark,
                      minWidth: 350, maxLines: 2),
                ]),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_clientCtrl.text.trim().isEmpty ||
                            _totalCtrl.text.trim().isEmpty ||
                            _descCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Client name, description and total are required')));
                          return;
                        }
                        setState(() => _previewing = true);
                      },
                      icon: const Icon(Icons.preview_outlined,
                          size: 16, color: Colors.white),
                      label: const Text('Preview Invoice',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 240,
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            topAccentColor: AppColors.accent2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice Tips',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText)),
                const SizedBox(height: 12),
                ...[
                  '📋 Fill all required fields marked with *',
                  '💰 Split payments work best for large deals',
                  '📅 Set a clear due date to avoid delays',
                  '📤 Export as PDF to send to clients',
                  '🔒 Only admins can generate invoices',
                ].map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tip.substring(0, 2),
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(tip.substring(2).trim(),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkText2
                                      : AppColors.lightText2,
                                  height: 1.4))),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(bool isDark) {
    final total      = double.tryParse(_totalCtrl.text) ?? 0;
    final pay1       = double.tryParse(_pay1Ctrl.text)  ?? 0;
    final pay2       = double.tryParse(_pay2Ctrl.text)  ?? 0;
    final balance    = total - pay1 - pay2;
    final invoiceNum =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return Column(
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _previewing = false),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Form'),
            ),
            const SizedBox(width: 12),
            // ← CHANGED: now calls _exportPdf() instead of snackbar
            ElevatedButton.icon(
              onPressed: _exporting ? null : _exportPdf,
              icon: _exporting
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf,
                  size: 16, color: Colors.white),
              label: Text(_exporting ? 'Exporting...' : 'Export PDF',
                  style: const TextStyle(color: Colors.white)),
              style:
              ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(maxWidth: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accent2]),
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nexra Digital LLC',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1)),
                          const Text('Digital Marketing Service',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                          const SizedBox(height: 8),
                          const Text('www.nexradigitalllc.com.info',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('INVOICE',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 2)),
                        Text(invoiceNum,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontFamily: 'monospace')),
                        const SizedBox(height: 4),
                        Text('Date: $_invoiceDate',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                        if (_dueDate.isNotEmpty)
                          Text('Due: $_dueDate',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BILL TO',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText3,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text(_clientCtrl.text,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBg)),
                    if (_companyCtrl.text.isNotEmpty)
                      Text(_companyCtrl.text,
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.darkText3)),
                    if (_emailCtrl.text.isNotEmpty)
                      Text(_emailCtrl.text,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.darkText3)),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.lightBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: AppColors.lightSurface2,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(8)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                    flex: 3,
                                    child: Text('DESCRIPTION',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkText3,
                                            letterSpacing: 1))),
                                Expanded(
                                    child: Text('AMOUNT (AUD)',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkText3,
                                            letterSpacing: 1))),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    flex: 3,
                                    child: Text(_descCtrl.text,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.darkBg))),
                                Expanded(
                                    child: Text(
                                        '\$${total.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkBg,
                                            fontFamily: 'monospace'))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 280,
                        child: Column(
                          children: [
                            if (pay1 > 0)
                              _payRow('1st Installment', pay1, false),
                            if (pay2 > 0)
                              _payRow('2nd Installment', pay2, false),
                            Container(
                                height: 1,
                                color: AppColors.lightBorder,
                                margin:
                                const EdgeInsets.symmetric(vertical: 8)),
                            _payRow('Total Amount', total, false),
                            _payRow('Amount Received', pay1 + pay2, false),
                            Container(
                                height: 1,
                                color: AppColors.accent,
                                margin:
                                const EdgeInsets.symmetric(vertical: 8)),
                            _payRow('BALANCE DUE', balance, true),
                          ],
                        ),
                      ),
                    ),
                    if (_notesCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.lightBorder),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NOTES',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkText3,
                                      letterSpacing: 1)),
                              const SizedBox(height: 6),
                              Text(_notesCtrl.text,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.darkText2)),
                            ]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Center(
                      child: Text('Thank you for your business!',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.darkText3,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _payRow(String label, double amount, bool highlight) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                  highlight ? FontWeight.w700 : FontWeight.normal,
                  color: highlight ? AppColors.accent : AppColors.darkText2)),
          Text('\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                  highlight ? FontWeight.w800 : FontWeight.w600,
                  color: highlight ? AppColors.accent : AppColors.darkBg,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _datePicker(String hint, String currentValue,
      Function(String) onChanged, bool isDark) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(DateHelper.format(picked));
      },
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurface2
              : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
              isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today,
              size: 14, color: AppColors.darkText3),
          const SizedBox(width: 8),
          Text(
              currentValue.isEmpty ? hint : currentValue,
              style: TextStyle(
                  fontSize: 13,
                  color: currentValue.isEmpty
                      ? AppColors.darkText3
                      : (isDark
                      ? AppColors.darkText
                      : AppColors.lightText))),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, bool isDark) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.accent),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color:
              isDark ? AppColors.darkText : AppColors.lightText)),
    ]);
  }

  Widget _label(String text, bool isDark) => Text(text,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkText2 : AppColors.lightText2));

  Widget _field(String label, TextEditingController ctrl, bool isDark,
      {int maxLines = 1,
        double minWidth = 160,
        TextInputType? keyboardType}) {
    return SizedBox(
      width: minWidth,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, isDark),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkText : AppColors.lightText),
          decoration: const InputDecoration(
              contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        ),
      ]),
    );
  }
}