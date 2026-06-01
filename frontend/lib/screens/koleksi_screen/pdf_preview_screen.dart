import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../models/observation.dart';
import '../../utils/constants.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String divisi;
  final String exporterNama;

  const PdfPreviewScreen({
    super.key,
    required this.divisi,
    required this.exporterNama,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  bool _isLoading = true;
  List<Observation> _observations = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final client = Supabase.instance.client;
      var query = client
          .from('data_observasi')
          .select('''
            id,
            id_petugas,
            id_kegiatan,
            nama_spesies,
            nama_lokal,
            kategori_takson,
            latitude,
            longitude,
            foto_url,
            catatan_habitat,
            waktu_pengamatan,
            status_approval,
            id_kordinator,
            catatan_revisi,
            waktu_verifikasi,
            created_at,
            updated_at,
            jumlah_individu,
            aktivitas_termati,
            profiles!id_petugas ( nama_lengkap )
          ''');

      if (widget.divisi != 'Semua Divisi') {
        query = query.eq('kategori_takson', widget.divisi);
      }

      final response = await query.order('waktu_pengamatan', ascending: false);

      final fetched = (response as List)
          .map((json) => Observation.fromSupabase(json as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _observations = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document(
      title: 'Laporan Observasi E-Hutan - ${widget.divisi}',
      author: 'E-Hutan App',
    );

    // 1. Load Fonts
    final chivoData = await rootBundle.load('lib/assets/font/Chivo-VariableFont_wght.ttf');
    final chivoFont = pw.Font.ttf(chivoData);

    final vollkornItalicData = await rootBundle.load('lib/assets/font/Vollkorn-Italic-VariableFont_wght.ttf');
    final vollkornItalicFont = pw.Font.ttf(vollkornItalicData);

    // 2. Load UKF Logo
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('lib/assets/logoUKF.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error loading logo asset: $e');
    }

    // 3. Preload all observation images from network
    final imageBytesMap = <String, Uint8List?>{};
    await Future.wait(_observations.map((obs) async {
      final url = resolveSupabaseFotoUrl(obs.fotoUrl);
      if (url != null && url.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
          if (res.statusCode == 200) {
            imageBytesMap[obs.id] = res.bodyBytes;
          }
        } catch (e) {
          debugPrint('Error downloading image for ${obs.id}: $e');
        }
      }
    }));

    // 4. Build Multi-Page Document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format.copyWith(
          marginTop: 40,
          marginBottom: 40,
          marginLeft: 40,
          marginRight: 40,
        ),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logoImage, width: 40, height: 40),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'UNIT KONSERVASI KEHUTANAN (UKF)',
                            style: pw.TextStyle(
                              font: chivoFont,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                          pw.Text(
                            'Laporan Observasi Lapangan - E-Hutan',
                            style: pw.TextStyle(
                              font: chivoFont,
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Divisi: ${widget.divisi}',
                        style: pw.TextStyle(
                          font: chivoFont,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                      pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                        style: pw.TextStyle(
                          font: chivoFont,
                          fontSize: 8,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.green800),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Unit Konservasi Kehutanan (UKF) • E-Hutan Laporan',
                    style: pw.TextStyle(
                      font: chivoFont,
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                    style: pw.TextStyle(
                      font: chivoFont,
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          if (_observations.isEmpty) {
            return [
              pw.SizedBox(height: 50),
              pw.Center(
                child: pw.Text(
                  'Tidak ada data observasi yang ditemukan.',
                  style: pw.TextStyle(
                    font: chivoFont,
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ];
          }

          return [
            // Metadata ringkas laporan di baris atas
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Pengekspor: ${widget.exporterNama}',
                    style: pw.TextStyle(font: chivoFont, fontSize: 9, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'Jumlah Data: ${_observations.length} Observasi',
                    style: pw.TextStyle(
                      font: chivoFont,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),
            ),

            // Iterasi observations
            ..._observations.map((obs) {
              final imgBytes = imageBytesMap[obs.id];
              final dateStr = DateFormat('dd MMM yyyy HH:mm').format(obs.waktuPengamatan);

              // Tentukan warna status
              PdfColor statusColor = PdfColors.orange700;
              PdfColor statusBgColor = PdfColor.fromHex('#FFF3E0');
              String statusLabel = 'MENUNGGU VERIFIKASI';
              if (obs.statusApproval == 'TERVERIFIKASI') {
                statusColor = PdfColors.green700;
                statusBgColor = PdfColor.fromHex('#E8F5E9');
                statusLabel = 'TERVERIFIKASI';
              } else if (obs.statusApproval == 'PERLU_DIREVISI') {
                statusColor = PdfColors.red700;
                statusBgColor = PdfColor.fromHex('#FFEBEE');
                statusLabel = 'PERLU DIREVISI';
              }

              return pw.Inseparable(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 12),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    ),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Kolom Kiri: Foto
                      pw.Container(
                        width: 120,
                        height: 120,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                        ),
                        alignment: pw.Alignment.center,
                        child: imgBytes != null
                            ? pw.ClipRRect(
                                horizontalRadius: 6,
                                verticalRadius: 6,
                                child: pw.Image(
                                  pw.MemoryImage(imgBytes),
                                  width: 120,
                                  height: 120,
                                  fit: pw.BoxFit.cover,
                                ),
                              )
                            : pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  'Gambar\nOffline / Error',
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(font: chivoFont, fontSize: 8, color: PdfColors.grey500),
                                ),
                              ),
                      ),
                      pw.SizedBox(width: 16),
                      // Kolom Kanan: Detail Informasi
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Nama Spesies & Lokal
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        obs.namaSpesies,
                                        style: pw.TextStyle(
                                          font: vollkornItalicFont,
                                          fontSize: 13,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.green900,
                                        ),
                                      ),
                                      pw.SizedBox(height: 2),
                                      pw.Text(
                                        'Nama Lokal: ${obs.namaLokal ?? '-'}',
                                        style: pw.TextStyle(
                                          font: chivoFont,
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.grey800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Badge Status Approval
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: statusBgColor,
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                    border: pw.Border.all(color: statusColor, width: 0.5),
                                  ),
                                  child: pw.Text(
                                    statusLabel,
                                    style: pw.TextStyle(
                                      font: chivoFont,
                                      fontSize: 6.5,
                                      fontWeight: pw.FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 6),
                            pw.Divider(thickness: 0.5, color: PdfColors.grey200),
                            pw.SizedBox(height: 4),

                            // Telemetri data dalam grid-like layout
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 5,
                                  child: _buildInfoRow(chivoFont, 'Divisi/Takson:', obs.kategoriTakson),
                                ),
                                pw.Expanded(
                                  flex: 4,
                                  child: _buildInfoRow(chivoFont, 'Jumlah:', '${obs.jumlahIndividu ?? 1} individu'),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 3),
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 5,
                                  child: _buildInfoRow(chivoFont, 'Waktu Pengamatan:', dateStr),
                                ),
                                pw.Expanded(
                                  flex: 4,
                                  child: _buildInfoRow(chivoFont, 'Koordinat:', '[${obs.latitude.toStringAsFixed(5)}, ${obs.longitude.toStringAsFixed(5)}]'),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 3),
                            _buildInfoRow(chivoFont, 'Aktivitas Teramati:', obs.aktivitasTermati ?? '-'),
                            pw.SizedBox(height: 3),
                            _buildInfoRow(chivoFont, 'Catatan Habitat:', obs.catatanHabitat ?? '-'),

                            // Tambahan pelapor jika ada
                            if (obs.reporterNama != null) ...[
                              pw.SizedBox(height: 3),
                              _buildInfoRow(chivoFont, 'Petugas Lapangan:', obs.reporterNama!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildInfoRow(pw.Font font, String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label ',
            style: pw.TextStyle(
              font: font,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              font: font,
              fontSize: 8.5,
              color: PdfColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A2400)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PREVIEW PDF: ${widget.divisi.toUpperCase()}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Color(0xFF1A2400),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Mengunduh data & memproses PDF...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          'Gagal mengambil data dari server:\n$_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _fetchData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : PdfPreview(
                  build: (format) => _generatePdf(format),
                  maxPageWidth: 700,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  pdfFileName: 'Laporan_Observasi_${widget.divisi.replaceAll(' ', '_')}.pdf',
                  loadingWidget: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
    );
  }
}
