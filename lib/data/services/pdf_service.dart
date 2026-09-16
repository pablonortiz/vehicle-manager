import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/provinces.dart';
import '../../core/utils/formatters.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_photo.dart';
import '../../domain/models/document_photo.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/fuel_charge.dart';
import '../../domain/models/vehicle_note.dart';
import 'fuel_stats.dart';
import 'pdf_image_downloader.dart';
import 'pdf_theme.dart';

class PdfService {
  // Paleta compartida (ver PdfTheme): fondo blanco, amigable para impresión.
  static const _primaryColor = PdfTheme.primary;
  static const _backgroundColor = PdfTheme.background;
  static const _surfaceColor = PdfTheme.surface;
  static const _textColor = PdfTheme.textPrimary;
  static const _textSecondary = PdfTheme.textSecondary;
  static const _accentColor = PdfTheme.primary;

  /// Genera el PDF completo del vehículo
  static Future<Uint8List> generateVehiclePdf({
    required Vehicle vehicle,
    required List<VehiclePhoto> photos,
    required List<DocumentPhoto> documentPhotos,
    required List<Maintenance> maintenances,
  }) async {
    final pdf = await _createDocument();

    // Recolectar y descargar (en paralelo) todas las imágenes antes de armar las páginas.
    final photoAttachments = _photoAttachments(photos);
    final docSections = _documentSections(documentPhotos);
    final maintenanceAttachments = _maintenanceAttachments(maintenances);
    await _resolveImageBytes([
      ...photoAttachments,
      for (final section in docSections) ...section.value,
      ...maintenanceAttachments.values.expand((e) => e),
    ]);

    // 1. Página de datos del vehículo
    pdf.addPage(_buildVehicleDataPage(vehicle));

    // 2. Fotos del vehículo (cada una en página separada)
    await _addDocumentSection(pdf, 'FOTOS DEL VEHÍCULO', photoAttachments);

    // 3. Documentación
    for (final section in docSections) {
      await _addDocumentSection(pdf, section.key, section.value);
    }

    // 4. Mantenimientos
    if (maintenances.isNotEmpty) {
      pdf.addPage(_buildSectionTitlePage('MANTENIMIENTOS'));

      for (final maintenance in maintenances) {
        pdf.addPage(_buildMaintenanceDetailPage(maintenance));

        // Agregar adjuntos del mantenimiento
        for (final attachment in maintenanceAttachments[maintenance]!) {
          await _addAttachment(pdf, attachment);
        }
      }
    }

    return pdf.save();
  }

  /// Adjuntos de las fotos del vehículo (foto principal marcada con caption).
  static List<_Attachment> _photoAttachments(List<VehiclePhoto> photos) {
    return photos
        .map((photo) => _Attachment(
              isPdf: photo.isPdf,
              url: photo.cloudinaryUrl,
              fileName: photo.fileName,
              caption: photo.isPrimary ? '(Principal)' : null,
            ))
        .toList();
  }

  /// Secciones de documentación en orden, cada una con su título y adjuntos.
  static List<MapEntry<String, List<_Attachment>>> _documentSections(
    List<DocumentPhoto> documentPhotos,
  ) {
    List<_Attachment> attachmentsFor(DocumentType type) => documentPhotos
        .where((d) => d.documentType == type)
        .map((doc) => _Attachment(
              isPdf: doc.isPdf,
              url: doc.cloudinaryUrl,
              fileName: doc.fileName,
            ))
        .toList();

    return [
      MapEntry('CÉDULA VERDE', attachmentsFor(DocumentType.cedulaVerde)),
      MapEntry('CÉDULA AZUL', attachmentsFor(DocumentType.cedulaAzul)),
      MapEntry('TÍTULO', attachmentsFor(DocumentType.titulo)),
      MapEntry('VTV', attachmentsFor(DocumentType.vtv)),
    ];
  }

  /// Adjuntos de cada mantenimiento (solo imágenes y PDF), en orden.
  static Map<Maintenance, List<_Attachment>> _maintenanceAttachments(
    List<Maintenance> maintenances,
  ) {
    return {
      for (final maintenance in maintenances)
        maintenance: maintenance.invoices
            .where((invoice) => invoice.isImage || invoice.isPdf)
            .map((invoice) => _Attachment(
                  isPdf: invoice.isPdf,
                  url: invoice.cloudinaryUrl,
                  fileName: invoice.fileName,
                  caption: invoice.isImage ? (invoice.fileName ?? 'Factura') : null,
                ))
            .toList(),
    };
  }

  /// Adjuntos de las fotos de cada nota (imágenes y PDF), en orden.
  static Map<VehicleNote, List<_Attachment>> _noteAttachments(
    List<VehicleNote> notes,
  ) {
    return {
      for (final note in notes)
        note: note.photos
            .map((photo) => _Attachment(
                  isPdf: photo.isPdf,
                  url: photo.cloudinaryUrl,
                  fileName: photo.fileName,
                ))
            .toList(),
    };
  }

  /// Páginas con todos los datos del vehículo (usa MultiPage para paginación automática)
  static pw.MultiPage _buildVehicleDataPage(Vehicle vehicle) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final provinceName = ArgentinaProvinces.getById(vehicle.provinceId).name;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      buildBackground: (context) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(
          decoration: const pw.BoxDecoration(color: _backgroundColor),
        ),
      ),
    );

    return pw.MultiPage(
      pageTheme: pageTheme,
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _surfaceColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado: ${dateFormat.format(DateTime.now())}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: _textSecondary,
              ),
            ),
            pw.Text(
              'Gestor de Vehículos',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _accentColor,
              ),
            ),
          ],
        ),
      ),
      build: (context) => [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(
            color: _surfaceColor,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: _primaryColor, width: 2),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: _primaryColor,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  '🚗',
                  style: const pw.TextStyle(fontSize: 24),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      vehicle.plate,
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    pw.Text(
                      '${vehicle.brand} ${vehicle.model} (${vehicle.year})',
                      style: const pw.TextStyle(
                        fontSize: 16,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: _getStatusColor(vehicle.status),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  vehicle.status.label,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 24),

        // Información General
        _buildSection('INFORMACIÓN GENERAL', [
          _buildInfoRow('Tipo', vehicle.type.label),
          _buildInfoRow('Marca', vehicle.brand),
          _buildInfoRow('Modelo', vehicle.model),
          _buildInfoRow('Año', vehicle.year.toString()),
          _buildInfoRow('Kilometraje', '${NumberFormat('#,###').format(vehicle.km)} km'),
          _buildInfoRow('Combustible', vehicle.fuelType.label),
          _buildColorRow(vehicle.color),
        ]),
        pw.SizedBox(height: 16),

        // Ubicación
        _buildSection('UBICACIÓN', [
          _buildInfoRow('Provincia', provinceName),
          _buildInfoRow('Ciudad', vehicle.city),
          if (vehicle.lugar != null && vehicle.lugar!.isNotEmpty)
            _buildInfoRow('Lugar', vehicle.lugar!),
        ]),
        pw.SizedBox(height: 16),

        // Responsable
        _buildSection('RESPONSABLE', [
          _buildInfoRow('Nombre', vehicle.responsibleName),
          _buildInfoRow('Teléfono', vehicle.responsiblePhone),
        ]),
        pw.SizedBox(height: 16),

        // Documentación
        _buildSection('DOCUMENTACIÓN', [
          _buildInfoRow(
            'VTV',
            vehicle.vtvExpiry != null
                ? 'Vence: ${dateFormat.format(vehicle.vtvExpiry!)}'
                : 'No registrado',
            isAlert: vehicle.isVtvExpired || vehicle.isVtvExpiringSoon,
          ),
          _buildInfoRow(
            'Seguro',
            vehicle.insuranceCompany ?? 'No registrado',
          ),
          _buildInfoRow(
            'Venc. Seguro',
            vehicle.insuranceExpiry != null
                ? dateFormat.format(vehicle.insuranceExpiry!)
                : 'No registrado',
            isAlert: vehicle.isInsuranceExpired || vehicle.isInsuranceExpiringSoon,
          ),
        ]),
      ],
    );
  }

  /// Página de título de sección
  static pw.Page _buildSectionTitlePage(String title) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Container(
          decoration: const pw.BoxDecoration(color: _backgroundColor),
          child: pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 60, vertical: 30),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _primaryColor, width: 4),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 42,
                  fontWeight: pw.FontWeight.bold,
                  color: _textColor,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Página con imagen a pantalla completa
  static pw.Page _buildFullPageImage(Uint8List imageData, String? caption) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) {
        return pw.Container(
          decoration: const pw.BoxDecoration(color: _backgroundColor),
          child: pw.Column(
            children: [
              pw.Expanded(
                child: pw.Center(
                  child: pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(
                      pw.MemoryImage(imageData),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              ),
              if (caption != null) ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: pw.BorderRadius.circular(20),
                  ),
                  child: pw.Text(
                    caption,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: _textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Página con detalle de mantenimiento
  static pw.Page _buildMaintenanceDetailPage(Maintenance maintenance) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Container(
          decoration: const pw.BoxDecoration(color: _backgroundColor),
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header de mantenimiento
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: _primaryColor, width: 2),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: _primaryColor,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        '🔧',
                        style: const pw.TextStyle(fontSize: 20),
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'MANTENIMIENTO',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          pw.Text(
                            dateFormat.format(maintenance.date),
                            style: const pw.TextStyle(
                              fontSize: 14,
                              color: _accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (maintenance.invoices.isNotEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: _accentColor,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          '${maintenance.invoices.length} adjunto(s)',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              
              // Detalle
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DETALLE',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _accentColor,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      maintenance.detail,
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: _textColor,
                        lineSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Página con detalle de nota
  static pw.Page _buildNoteDetailPage(VehicleNote note, DateFormat dateFormat) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Container(
          decoration: const pw.BoxDecoration(color: _backgroundColor),
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header de nota
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: _primaryColor, width: 2),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: _primaryColor,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        '\u{1F4DD}',
                        style: const pw.TextStyle(fontSize: 20),
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'NOTA',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: _textColor,
                            ),
                          ),
                          pw.Text(
                            dateFormat.format(note.createdAt),
                            style: const pw.TextStyle(
                              fontSize: 14,
                              color: _accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (note.photos.isNotEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: _accentColor,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          '${note.photos.length} foto(s)',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Detalle
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DETALLE',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _accentColor,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      note.detail,
                      style: const pw.TextStyle(
                        fontSize: 14,
                        color: _textColor,
                        lineSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Página de referencia a PDF externo
  static pw.Page _buildPdfReferencePage(String url, String? fileName) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Container(
          decoration: const pw.BoxDecoration(color: _backgroundColor),
          padding: const pw.EdgeInsets.all(40),
          child: pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(40),
              decoration: pw.BoxDecoration(
                color: _surfaceColor,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: _primaryColor, width: 2),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE53935),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Text(
                      'PDF',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    fileName ?? 'Documento PDF',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Este documento es un PDF adjunto.',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Puede accederlo en:',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      url,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: _accentColor,
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Página de referencia a imagen que no se pudo descargar
  static pw.Page _buildImageReferencePage(String url, String? fileName) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) {
        return pw.Container(
          decoration: const pw.BoxDecoration(color: _backgroundColor),
          padding: const pw.EdgeInsets.all(40),
          child: pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(40),
              decoration: pw.BoxDecoration(
                color: _surfaceColor,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: _primaryColor, width: 2),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFF9800),
                      borderRadius: pw.BorderRadius.circular(12),
                    ),
                    child: pw.Text(
                      'IMG',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    fileName ?? 'Imagen adjunta',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'No se pudo descargar la imagen.',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Puede accederla en:',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text(
                      url,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: _accentColor,
                      ),
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye una sección con título y filas
  static pw.Widget _buildSection(String title, List<pw.Widget> rows) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _surfaceColor,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const pw.BoxDecoration(
              color: _accentColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(12),
                topRight: pw.Radius.circular(12),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(children: rows),
          ),
        ],
      ),
    );
  }

  /// Construye una fila de información
  static pw.Widget _buildInfoRow(String label, String value, {bool isAlert = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 11,
                color: _textSecondary,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: isAlert ? PdfColor.fromInt(0xFFFF9800) : _textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una fila con cuadrado de color + nombre del color
  static pw.Widget _buildColorRow(Color flutterColor) {
    final colorName = VehicleColors.getByColor(flutterColor).name;
    final pdfColor = PdfColor.fromInt(flutterColor.toARGB32());
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              'Color',
              style: const pw.TextStyle(
                fontSize: 11,
                color: _textSecondary,
              ),
            ),
          ),
          pw.Container(
            width: 14,
            height: 14,
            decoration: pw.BoxDecoration(
              color: pdfColor,
              borderRadius: pw.BorderRadius.circular(3),
              border: pw.Border.all(color: _textSecondary, width: 0.5),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            colorName,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _getStatusColor(VehicleStatus status) =>
      PdfTheme.statusColor(status);

  static Future<pw.Document> _createDocument() => PdfTheme.createDocument();

  /// Descarga un PDF desde una URL y retorna los bytes. Wrapper para los callers
  /// externos (preview); la implementación vive en PdfImageDownloader.
  static Future<Uint8List?> downloadPdfBytes(String url) =>
      PdfImageDownloader.downloadPdfBytes(url);

  /// Agrega páginas de un PDF adjunto al documento generado
  static Future<void> _addPdfAttachmentPages(
    pw.Document pdf,
    String cloudinaryUrl,
    String? fileName,
  ) async {
    final pages = await PdfImageDownloader.downloadAndRasterizePdf(cloudinaryUrl);
    if (pages.isNotEmpty) {
      for (int i = 0; i < pages.length; i++) {
        final caption = pages.length > 1
            ? '${fileName ?? 'PDF'} - Pág. ${i + 1}/${pages.length}'
            : fileName;
        pdf.addPage(_buildFullPageImage(pages[i], caption));
      }
    } else {
      // Fallback si no se pudo rasterizar
      pdf.addPage(_buildPdfReferencePage(cloudinaryUrl, fileName));
    }
  }

  /// Adjunto (imagen o PDF) a renderizar en el documento generado.
  /// Para imágenes, [imageBytes] se resuelve por adelantado (descarga en paralelo).
  static const int _downloadBatchSize = 5;

  /// Descarga en paralelo (en lotes) los bytes de imagen de los adjuntos
  /// que no son PDF, dejándolos listos para construir las páginas en orden.
  static Future<void> _resolveImageBytes(List<_Attachment> attachments) async {
    final imageAttachments = attachments.where((a) => !a.isPdf).toList();
    for (int i = 0; i < imageAttachments.length; i += _downloadBatchSize) {
      final batch = imageAttachments.skip(i).take(_downloadBatchSize).toList();
      final results = await Future.wait(
        batch.map((a) => PdfImageDownloader.downloadImage(a.url)),
      );
      for (int j = 0; j < batch.length; j++) {
        batch[j].imageBytes = results[j];
      }
    }
  }

  /// Agrega un adjunto al documento, en orden. Los PDF se rasterizan acá;
  /// las imágenes usan los bytes ya descargados en [_resolveImageBytes].
  static Future<void> _addAttachment(pw.Document pdf, _Attachment attachment) async {
    if (attachment.isPdf) {
      await _addPdfAttachmentPages(pdf, attachment.url, attachment.fileName);
    } else if (attachment.imageBytes != null) {
      pdf.addPage(_buildFullPageImage(attachment.imageBytes!, attachment.caption));
    } else {
      // La descarga de la imagen falló (timeout/404/red): dejamos una página
      // placeholder para que el adjunto no desaparezca del reporte sin aviso.
      pdf.addPage(_buildImageReferencePage(attachment.url, attachment.fileName));
    }
  }

  /// Agrega una sección de documentación (título + adjuntos en orden).
  static Future<void> _addDocumentSection(
    pw.Document pdf,
    String title,
    List<_Attachment> attachments,
  ) async {
    if (attachments.isEmpty) return;
    pdf.addPage(_buildSectionTitlePage(title));
    for (final attachment in attachments) {
      await _addAttachment(pdf, attachment);
    }
  }

  /// Agrega la página resumen del reporte de combustible.
  static void _addFuelSummaryPage(
    pw.Document pdf,
    Vehicle vehicle,
    FuelStats stats,
    DateTime startDate,
    DateTime endDate,
    bool ascending, {
    required bool includeVehicleInfo,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );
    final numberFormat = NumberFormat('#,###');
    final provinceName = ArgentinaProvinces.getById(vehicle.provinceId).name;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            decoration: const pw.BoxDecoration(color: _backgroundColor),
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: pw.BorderRadius.circular(12),
                    border: pw.Border.all(color: _primaryColor, width: 2),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: _primaryColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Text(
                          '\u{26FD}',
                          style: const pw.TextStyle(fontSize: 24),
                        ),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'REPORTE DE COMBUSTIBLE',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: _textColor,
                              ),
                            ),
                            pw.Text(
                              '${vehicle.plate} - ${vehicle.brand} ${vehicle.model}',
                              style: const pw.TextStyle(
                                fontSize: 14,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                if (includeVehicleInfo) ...[
                  // Vehicle info
                  _buildSection('DATOS DEL VEHICULO', [
                    _buildInfoRow('Modelo', '${vehicle.brand} ${vehicle.model}'),
                    _buildInfoRow('Ano', vehicle.year.toString()),
                    _buildInfoRow('Patente', vehicle.plate),
                    _buildInfoRow('Combustible', vehicle.fuelType.label),
                    _buildInfoRow('Kilometraje', '${numberFormat.format(vehicle.km)} km'),
                    _buildInfoRow('Ubicacion', '$provinceName - ${vehicle.city}${vehicle.lugar != null && vehicle.lugar!.isNotEmpty ? ' - ${vehicle.lugar}' : ''}'),
                  ]),
                  pw.SizedBox(height: 16),
                ],

                // Period
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    'Periodo: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}    |    Orden: ${ascending ? "Mas antigua a mas reciente" : "Mas reciente a mas antigua"}',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 16),

                // Summary stats
                _buildSection('RESUMEN DEL PERIODO', [
                  _buildInfoRow('Total de cargas', stats.sortedCharges.length.toString()),
                  _buildInfoRow('Litros totales', AppFormats.liters(stats.totalLiters)),
                  _buildInfoRow('Gasto total', currencyFormat.format(stats.totalPrice)),
                  _buildInfoRow('Precio promedio por litro', '${currencyFormat.format(stats.avgPricePerLiter)}/L'),
                  _buildInfoRow('Promedio de litros por carga', AppFormats.liters(stats.avgLitersPerCharge)),
                  if (stats.avgKmBetweenCharges != null)
                    _buildInfoRow('Promedio de km entre cargas', stats.avgKmBetweenCharges!),
                ]),

                pw.Spacer(),

                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: _surfaceColor,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Generado: ${dateFormat.format(DateTime.now())}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: _textSecondary,
                        ),
                      ),
                      pw.Text(
                        'Gestor de Vehiculos',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Agrega las páginas de la tabla de cargas de combustible.
  static void _addFuelTablePages(pw.Document pdf, FuelStats stats) {
    final sortedCharges = stats.sortedCharges;
    if (sortedCharges.isEmpty) return;

    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );
    final numberFormat = NumberFormat('#,###');

    const int chargesPerPage = 18;
    for (int i = 0; i < sortedCharges.length; i += chargesPerPage) {
      final pageCharges = sortedCharges.skip(i).take(chargesPerPage).toList();
      final isFirstTablePage = i == 0;
      final pageNum = (i ~/ chargesPerPage) + 1;
      final totalPages = (sortedCharges.length / chargesPerPage).ceil();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Container(
              decoration: const pw.BoxDecoration(color: _backgroundColor),
              padding: const pw.EdgeInsets.all(30),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (isFirstTablePage)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 16),
                      child: pw.Text(
                        'DETALLE DE CARGAS',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: _accentColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  // Table header
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: const pw.BoxDecoration(
                      color: _accentColor,
                      borderRadius: pw.BorderRadius.only(
                        topLeft: pw.Radius.circular(8),
                        topRight: pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        _tableHeader('Fecha', 70),
                        _tableHeader('Litros', 55),
                        _tableHeader('Total', 65),
                        _tableHeader('\$/L', 55),
                        _tableHeader('Odometro', 65),
                        pw.Expanded(
                          child: pw.Text(
                            'Notas',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table rows
                  ...pageCharges.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final charge = entry.value;
                    final isEven = idx % 2 == 0;
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: isEven ? _surfaceColor : _backgroundColor,
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColor.fromInt(0xFFE0E0E0),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: pw.Row(
                        children: [
                          _tableCell(dateFormat.format(charge.date), 70),
                          _tableCell(AppFormats.liters(charge.liters), 55),
                          _tableCell(currencyFormat.format(charge.price), 65),
                          _tableCell('${currencyFormat.format(charge.calculatedPricePerLiter)}/L', 55),
                          _tableCell(
                            charge.odometer != null
                                ? '${numberFormat.format(charge.odometer)} km'
                                : '-',
                            65,
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              charge.notes ?? '-',
                              style: const pw.TextStyle(
                                fontSize: 8,
                                color: _textSecondary,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  // Bottom border
                  pw.Container(
                    height: 2,
                    decoration: pw.BoxDecoration(
                      color: _accentColor,
                      borderRadius: const pw.BorderRadius.only(
                        bottomLeft: pw.Radius.circular(8),
                        bottomRight: pw.Radius.circular(8),
                      ),
                    ),
                  ),
                  pw.Spacer(),
                  // Page number
                  pw.Center(
                    child: pw.Text(
                      'Pagina $pageNum de $totalPages',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  /// Genera el PDF de reporte de combustible
  static Future<Uint8List> generateFuelReportPdf({
    required Vehicle vehicle,
    required List<FuelCharge> fuelCharges,
    required DateTime startDate,
    required DateTime endDate,
    required bool ascending,
  }) async {
    final pdf = await _createDocument();

    final stats = FuelStats.from(fuelCharges, ascending);

    // Page 1: Header + Vehicle Info + Summary Stats
    _addFuelSummaryPage(
      pdf,
      vehicle,
      stats,
      startDate,
      endDate,
      ascending,
      includeVehicleInfo: true,
    );

    // Following pages: Fuel charges table
    _addFuelTablePages(pdf, stats);

    return pdf.save();
  }

  static pw.Widget _tableHeader(String text, double width) {
    return pw.SizedBox(
      width: width,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String text, double width) {
    return pw.SizedBox(
      width: width,
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 9,
          color: _textColor,
        ),
      ),
    );
  }

  /// Genera el PDF combinado (vehículo + combustible)
  static Future<Uint8List> generateCombinedPdf({
    required Vehicle vehicle,
    required List<VehiclePhoto> photos,
    required List<DocumentPhoto> documentPhotos,
    required List<Maintenance> maintenances,
    required List<VehicleNote> notes,
    required List<FuelCharge> fuelCharges,
    required DateTime startDate,
    required DateTime endDate,
    required bool ascending,
  }) async {
    final pdf = await _createDocument();

    final dateFormat = DateFormat('dd/MM/yyyy');

    // ===== PARTE 1: DATOS DEL VEHÍCULO =====
    // Recolectar y descargar (en paralelo) todas las imágenes antes de armar las páginas.
    final photoAttachments = _photoAttachments(photos);
    final docSections = _documentSections(documentPhotos);
    final maintenanceAttachments = _maintenanceAttachments(maintenances);
    final noteAttachments = _noteAttachments(notes);
    await _resolveImageBytes([
      ...photoAttachments,
      for (final section in docSections) ...section.value,
      ...maintenanceAttachments.values.expand((e) => e),
      ...noteAttachments.values.expand((e) => e),
    ]);

    pdf.addPage(_buildVehicleDataPage(vehicle));

    // Fotos del vehículo
    await _addDocumentSection(pdf, 'FOTOS DEL VEHÍCULO', photoAttachments);

    // Documentación (incluye VTV)
    for (final section in docSections) {
      await _addDocumentSection(pdf, section.key, section.value);
    }

    // Mantenimientos
    if (maintenances.isNotEmpty) {
      pdf.addPage(_buildSectionTitlePage('MANTENIMIENTOS'));
      for (final maintenance in maintenances) {
        pdf.addPage(_buildMaintenanceDetailPage(maintenance));
        for (final attachment in maintenanceAttachments[maintenance]!) {
          await _addAttachment(pdf, attachment);
        }
      }
    }

    // Notas
    if (notes.isNotEmpty) {
      pdf.addPage(_buildSectionTitlePage('NOTAS'));
      for (final note in notes) {
        pdf.addPage(_buildNoteDetailPage(note, dateFormat));
        for (final attachment in noteAttachments[note]!) {
          await _addAttachment(pdf, attachment);
        }
      }
    }

    // ===== PARTE 2: REPORTE DE COMBUSTIBLE =====
    final stats = FuelStats.from(fuelCharges, ascending);

    // Fuel summary page
    _addFuelSummaryPage(
      pdf,
      vehicle,
      stats,
      startDate,
      endDate,
      ascending,
      includeVehicleInfo: false,
    );

    // Fuel charges table pages
    _addFuelTablePages(pdf, stats);

    return pdf.save();
  }

  /// Descarga y rasteriza un PDF externo a imágenes PNG (para preview en la app)
  static Future<List<Uint8List>> rasterizePdfFromUrl(String url, {double dpi = 200}) async {
    return PdfImageDownloader.downloadAndRasterizePdf(url, dpi: dpi);
  }
}

/// Adjunto (imagen o PDF) a renderizar en el PDF generado.
/// Para imágenes, [imageBytes] se descarga por adelantado y en paralelo.
class _Attachment {
  final bool isPdf;
  final String url;
  final String? fileName;
  final String? caption;
  Uint8List? imageBytes;

  _Attachment({
    required this.isPdf,
    required this.url,
    required this.fileName,
    this.caption,
  });
}

