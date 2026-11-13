import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../brand/brand.dart';
import 'formatting.dart';

const _green = PdfColor.fromInt(0xFF0B3B17);
const _forest = PdfColor.fromInt(0xFF1B5E2F);
const _gold = PdfColor.fromInt(0xFFC9A227);
const _cream = PdfColor.fromInt(0xFFF6EBDC);
const _ivory = PdfColor.fromInt(0xFFFFF8EE);
const _ink = PdfColor.fromInt(0xFF0A1F10);
const _muted = PdfColor.fromInt(0xFF5C6B60);

class PdfColumn {
  const PdfColumn(this.header, this.key, {this.numeric = false, this.width});

  final String header;
  final String key;
  final bool numeric;
  final double? width;
}

/// Builds a consistently branded PDF document for receipts, invoices,
/// payslips, statements and report exports.
class BrandPdf {
  const BrandPdf._();

  static Future<Uint8List> document({
    required String title,
    required String documentNumber,
    required String branchName,
    String? subtitle,
    String? partyLabel,
    String? partyName,
    String? footer,
    List<(String, String)> details = const [],
    List<PdfColumn> columns = const [],
    List<Map<String, dynamic>> rows = const [],
    List<(String, String)> totals = const [],
    String? note,
  }) async {
    final logoData = await rootBundle.load(Brand.logoAsset);
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final issued = DateTime.now();
    final doc = pw.Document(
      title: '$title $documentNumber',
      author: Brand.appName,
      creator: Brand.appName,
      subject: subtitle ?? title,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 30),
        header: (context) => _header(logo, branchName),
        footer: (context) => _footer(context, footer),
        build: (context) => [
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title.toUpperCase(),
                      style: pw.TextStyle(
                        color: _green,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      subtitle ?? 'Official business document',
                      style: const pw.TextStyle(color: _muted, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    documentNumber,
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    formatDate(issued),
                    style: const pw.TextStyle(color: _muted, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(height: 2, color: _gold),
          pw.SizedBox(height: 14),
          if (details.isNotEmpty || partyName != null)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (details.isNotEmpty)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        for (final detail in details)
                          _detail(detail.$1, detail.$2),
                      ],
                    ),
                  ),
                if (partyName != null)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _cream,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            partyLabel ?? 'Party',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: _muted,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            partyName,
                            style: pw.TextStyle(
                              fontSize: 11,
                              color: _ink,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          if (columns.isNotEmpty && rows.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headers: [for (final column in columns) column.header],
              data: [
                for (final row in rows)
                  [
                    for (final column in columns)
                      _cell(row[column.key], numeric: column.numeric),
                  ],
              ],
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColor.fromInt(0xFFE8DDCD),
                ),
                bottom: pw.BorderSide(color: _gold, width: 0.8),
              ),
              headerDecoration: const pw.BoxDecoration(color: _green),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5, color: _ink),
              cellAlignments: {
                for (var index = 0; index < columns.length; index++)
                  index: columns[index].numeric
                      ? pw.Alignment.centerRight
                      : pw.Alignment.centerLeft,
              },
              columnWidths: {
                for (var index = 0; index < columns.length; index++)
                  if (columns[index].width != null)
                    index: pw.FixedColumnWidth(columns[index].width!),
              },
              headerAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              headerPadding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
            ),
          ],
          if (totals.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 240,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: _ivory,
                    border: pw.Border.all(
                      color: const PdfColor.fromInt(0xFFE8DDCD),
                    ),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      for (var index = 0; index < totals.length; index++)
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  totals[index].$1,
                                  style: pw.TextStyle(
                                    fontSize: index == totals.length - 1
                                        ? 10
                                        : 9,
                                    color: _muted,
                                    fontWeight: index == totals.length - 1
                                        ? pw.FontWeight.bold
                                        : pw.FontWeight.normal,
                                  ),
                                ),
                              ),
                              pw.Text(
                                totals[index].$2,
                                style: pw.TextStyle(
                                  fontSize: index == totals.length - 1 ? 11 : 9,
                                  color: index == totals.length - 1
                                      ? _green
                                      : _ink,
                                  fontWeight: index == totals.length - 1
                                      ? pw.FontWeight.bold
                                      : pw.FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (note != null && note.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _cream,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                note,
                style: const pw.TextStyle(fontSize: 8.5, color: _ink),
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            'Thank you for choosing ${Brand.appName}.',
            style: pw.TextStyle(
              color: _forest,
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _header(pw.MemoryImage logo, String branchName) => pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 54,
            height: 54,
            decoration: pw.BoxDecoration(
              color: _cream,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  Brand.appName,
                  style: pw.TextStyle(
                    color: _green,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  Brand.slogan,
                  style: pw.TextStyle(
                    color: _gold,
                    fontSize: 8.5,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  branchName,
                  style: const pw.TextStyle(color: _muted, fontSize: 8.5),
                ),
              ],
            ),
          ),
          pw.Text(
            'BAKERY • SHOP • PROPERTY',
            style: pw.TextStyle(
              color: _forest,
              fontSize: 7,
              letterSpacing: 0.8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 1, color: _forest),
    ],
  );

  static pw.Widget _footer(pw.Context context, String? footer) => pw.Column(
    children: [
      pw.Container(height: 0.8, color: _gold),
      pw.SizedBox(height: 4),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              footer?.trim().isNotEmpty == true
                  ? footer!
                  : '${Brand.appName} • ${Brand.slogan}',
              style: const pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ],
      ),
    ],
  );

  static pw.Widget _detail(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 82,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8.5,
              color: _muted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9, color: _ink),
          ),
        ),
      ],
    ),
  );

  static String _cell(Object? value, {required bool numeric}) {
    if (value == null) return '';
    if (numeric) return formatMoney(value);
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is Map || value is List) return '';
    return value.toString();
  }

  /// Shares the PDF via the platform share sheet. Returns a saved file path on
  /// desktop platforms without share-sheet support.
  static Future<String?> share({
    required String fileName,
    required Uint8List bytes,
    String? subject,
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    try {
      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: 'application/pdf', name: '$safe.pdf'),
      ], subject: subject ?? Brand.appName);
      return null;
    } catch (_) {
      return null;
    }
  }
}
