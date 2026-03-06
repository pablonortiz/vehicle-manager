import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vehicle_photo.dart';
import '../../domain/models/document_photo.dart';
import '../../domain/models/maintenance.dart';
import '../../domain/models/fuel_charge.dart';

class PdfService {
  // Colores del tema (estilo Radio Nacional)
  static const _primaryColor = PdfColor.fromInt(0xFF1E88E5);
  static const _backgroundColor = PdfColor.fromInt(0xFF1A1A1A);
  static const _surfaceColor = PdfColor.fromInt(0xFF2D2D2D);
  static const _textColor = PdfColor.fromInt(0xFFE0E0E0);
  static const _textSecondary = PdfColor.fromInt(0xFF9E9E9E);
  static const _accentColor = PdfColor.fromInt(0xFF1E88E5);

  /// Genera el PDF completo del vehículo
  static Future<Uint8List> generateVehiclePdf({
    required Vehicle vehicle,
    required List<VehiclePhoto> photos,
    required List<DocumentPhoto> documentPhotos,
    required List<Maintenance> maintenances,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.robotoRegular(),
        bold: await PdfGoogleFonts.robotoBold(),
        italic: await PdfGoogleFonts.robotoItalic(),
      ),
    );

    // 1. Página de datos del vehículo
    pdf.addPage(_buildVehicleDataPage(vehicle));

    // 2. Fotos del vehículo (cada una en página separada)
    if (photos.isNotEmpty) {
      pdf.addPage(_buildSectionTitlePage('FOTOS DEL VEHÍCULO'));
      for (final photo in photos) {
        final imageData = await _downloadImage(photo.cloudinaryUrl);
        if (imageData != null) {
          pdf.addPage(_buildFullPageImage(imageData, photo.isPrimary ? '(Principal)' : null));
        }
      }
    }

    // 3. Documentación
    final cedulaVerde = documentPhotos.where((d) => d.documentType == DocumentType.cedulaVerde).toList();
    final cedulaAzul = documentPhotos.where((d) => d.documentType == DocumentType.cedulaAzul).toList();
    final titulo = documentPhotos.where((d) => d.documentType == DocumentType.titulo).toList();

    if (cedulaVerde.isNotEmpty) {
      pdf.addPage(_buildSectionTitlePage('CÉDULA VERDE'));
      for (final doc in cedulaVerde) {
        final imageData = await _downloadImage(doc.cloudinaryUrl);
        if (imageData != null) {
          pdf.addPage(_buildFullPageImage(imageData, null));
        }
      }
    }

    if (cedulaAzul.isNotEmpty) {
      pdf.addPage(_buildSectionTitlePage('CÉDULA AZUL'));
      for (final doc in cedulaAzul) {
        final imageData = await _downloadImage(doc.cloudinaryUrl);
        if (imageData != null) {
          pdf.addPage(_buildFullPageImage(imageData, null));
        }
      }
    }

    if (titulo.isNotEmpty) {
      pdf.addPage(_buildSectionTitlePage('TÍTULO'));
      for (final doc in titulo) {
        final imageData = await _downloadImage(doc.cloudinaryUrl);
        if (imageData != null) {
          pdf.addPage(_buildFullPageImage(imageData, null));
        }
      }
    }

    // 4. Mantenimientos
    if (maintenances.isNotEmpty) {
      pdf.addPage(_buildSectionTitlePage('MANTENIMIENTOS'));
      
      for (final maintenance in maintenances) {
        pdf.addPage(_buildMaintenanceDetailPage(maintenance));
        
        // Agregar adjuntos del mantenimiento
        for (final invoice in maintenance.invoices) {
          if (invoice.isImage) {
            final imageData = await _downloadImage(invoice.cloudinaryUrl);
            if (imageData != null) {
              pdf.addPage(_buildFullPageImage(
                imageData, 
                invoice.fileName ?? 'Factura',
              ));
            }
          } else if (invoice.isPdf) {
            // Para PDFs, mostrar una página indicando que es un PDF externo
            pdf.addPage(_buildPdfReferencePage(invoice.cloudinaryUrl, invoice.fileName));
          }
        }
      }
    }

    return pdf.save();
  }

  /// Página con todos los datos del vehículo
  static pw.Page _buildVehicleDataPage(Vehicle vehicle) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final provinceName = ArgentinaProvinces.getById(vehicle.provinceId).name;
    
    return pw.Page(
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
                if (vehicle.insuranceExpiry != null)
                  _buildInfoRow(
                    'Venc. Seguro',
                    dateFormat.format(vehicle.insuranceExpiry!),
                    isAlert: vehicle.isInsuranceExpired || vehicle.isInsuranceExpiringSoon,
                  ),
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
            ],
          ),
        );
      },
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

  /// Obtiene el color según el estado del vehículo
  static PdfColor _getStatusColor(VehicleStatus status) {
    switch (status) {
      case VehicleStatus.available:
        return PdfColor.fromInt(0xFF4CAF50);
      case VehicleStatus.inUse:
        return PdfColor.fromInt(0xFF2196F3);
      case VehicleStatus.inWorkshop:
        return PdfColor.fromInt(0xFFFF9800);
      case VehicleStatus.outOfService:
        return PdfColor.fromInt(0xFFF44336);
    }
  }

  /// Descarga una imagen desde URL
  static Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      // Si falla la descarga, retornar null
    }
    return null;
  }

  /// Genera el PDF de reporte de combustible
  static Future<Uint8List> generateFuelReportPdf({
    required Vehicle vehicle,
    required List<FuelCharge> fuelCharges,
    required DateTime startDate,
    required DateTime endDate,
    required bool ascending,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.robotoRegular(),
        bold: await PdfGoogleFonts.robotoBold(),
        italic: await PdfGoogleFonts.robotoItalic(),
      ),
    );

    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );
    final numberFormat = NumberFormat('#,###');
    final provinceName = ArgentinaProvinces.getById(vehicle.provinceId).name;

    // Sort charges
    final sortedCharges = List<FuelCharge>.from(fuelCharges);
    sortedCharges.sort((a, b) => ascending
        ? a.date.compareTo(b.date)
        : b.date.compareTo(a.date));

    // Calculate summary stats
    final totalLiters = sortedCharges.fold<double>(0, (sum, c) => sum + c.liters);
    final totalPrice = sortedCharges.fold<double>(0, (sum, c) => sum + c.price);
    final avgPricePerLiter = totalLiters > 0 ? totalPrice / totalLiters : 0.0;
    final avgLitersPerCharge = sortedCharges.isNotEmpty ? totalLiters / sortedCharges.length : 0.0;

    // Calculate average km between charges (only if odometer data exists)
    String? avgKmBetweenCharges;
    final chargesWithOdometer = sortedCharges.where((c) => c.odometer != null).toList();
    chargesWithOdometer.sort((a, b) => a.date.compareTo(b.date));
    if (chargesWithOdometer.length >= 2) {
      final totalKm = chargesWithOdometer.last.odometer! - chargesWithOdometer.first.odometer!;
      final avgKm = totalKm / (chargesWithOdometer.length - 1);
      avgKmBetweenCharges = '${numberFormat.format(avgKm.round())} km';
    }

    // Page 1: Header + Vehicle Info + Summary Stats
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
                  _buildInfoRow('Total de cargas', sortedCharges.length.toString()),
                  _buildInfoRow('Litros totales', '${totalLiters.toStringAsFixed(1)} L'),
                  _buildInfoRow('Gasto total', currencyFormat.format(totalPrice)),
                  _buildInfoRow('Precio promedio por litro', '${currencyFormat.format(avgPricePerLiter)}/L'),
                  _buildInfoRow('Promedio de litros por carga', '${avgLitersPerCharge.toStringAsFixed(1)} L'),
                  if (avgKmBetweenCharges != null)
                    _buildInfoRow('Promedio de km entre cargas', avgKmBetweenCharges),
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

    // Following pages: Fuel charges table
    if (sortedCharges.isNotEmpty) {
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
                              color: PdfColor.fromInt(0xFF3A3A3A),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: pw.Row(
                          children: [
                            _tableCell(dateFormat.format(charge.date), 70),
                            _tableCell('${charge.liters.toStringAsFixed(1)} L', 55),
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

  /// Comparte o guarda el PDF
  static Future<void> sharePdf(Uint8List pdfBytes, String vehiclePlate) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'vehiculo_$vehiclePlate.pdf',
    );
  }

  /// Muestra vista previa e imprime
  static Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (_) => pdfBytes);
  }
}
