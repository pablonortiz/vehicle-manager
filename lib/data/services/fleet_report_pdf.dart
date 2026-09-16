import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/utils/formatters.dart';
import '../../domain/fleet_summary.dart';
import '../../domain/models/vehicle.dart';
import 'pdf_theme.dart';

/// Listado de la flota en PDF (A4 horizontal): encabezado con el alcance,
/// resumen por estado, tipo y provincia, y una tabla con los datos de cada
/// vehículo ordenada por provincia > ciudad > patente. A diferencia de la
/// ficha individual no marca vencimientos: es un listado, no un tablero de
/// alertas.
class FleetReportPdf {
  FleetReportPdf._();

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat("dd/MM/yyyy 'a las' HH:mm");
  static const _missing = '—';
  static const _maxProvincesInSummary = 4;
  static const _summaryCardHeight = 108.0;

  static Future<Uint8List> generate({
    required List<Vehicle> vehicles,
    required FleetReportScope scope,
    DateTime? generatedAt,
  }) async {
    final now = generatedAt ?? DateTime.now();
    final summary = FleetSummary.from(vehicles);
    final pdf = await PdfTheme.createDocument(title: 'Listado de vehículos');

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 22),
        ),
        maxPages: 400,
        footer: (context) => _footer(context, now),
        build: (context) => [
          _header(scope, summary, now),
          pw.SizedBox(height: 14),
          _summaryRow(summary, scope),
          pw.SizedBox(height: 18),
          if (summary.total == 0)
            _emptyNotice()
          else
            _table(summary.sortedVehicles),
        ],
      ),
    );
    return pdf.save();
  }

  // ---------------------------------------------------------------- Header

  static pw.Widget _header(
      FleetReportScope scope, FleetSummary summary, DateTime now) {
    final status = scope.status;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 5,
          height: 46,
          decoration: pw.BoxDecoration(
            color: PdfTheme.primary,
            borderRadius: pw.BorderRadius.circular(3),
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Text(
                  'LISTADO DE VEHÍCULOS',
                  style: pw.TextStyle(
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfTheme.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
                if (status != null) ...[
                  pw.SizedBox(width: 10),
                  _statusPill(status),
                ],
              ]),
              pw.SizedBox(height: 3),
              pw.Text(
                scope.subtitle,
                style: const pw.TextStyle(
                    fontSize: 10.5, color: PdfTheme.textSecondary),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              _vehiclesCount(summary.total),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfTheme.primary,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Generado el ${_dateTimeFormat.format(now)}',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfTheme.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _statusPill(VehicleStatus status) {
    final color = PdfTheme.statusColor(status);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: PdfTheme.tint(color, 0.15),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        _dot(color),
        pw.SizedBox(width: 5),
        pw.Text(
          status.pluralLabel,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfTheme.textPrimary,
          ),
        ),
      ]),
    );
  }

  static String _vehiclesCount(int count) =>
      count == 1 ? '1 vehículo' : '$count vehículos';

  // --------------------------------------------------------------- Summary

  // Estados y tipos se listan completos (con ceros): que no haya ninguno en
  // taller también es información. Provincias solo las que tienen vehículos.
  // Con el listado ya acotado a un estado, la tarjeta "Por estado" sobra.
  static pw.Widget _summaryRow(FleetSummary summary, FleetReportScope scope) {
    final cards = [
      _totalCard(summary.total),
      if (scope.status == null)
        _breakdownCard('POR ESTADO', [
          for (final status in VehicleStatus.values)
            _breakdownLine(
              status.pluralLabel,
              summary.byStatus[status] ?? 0,
              dot: PdfTheme.statusColor(status),
            ),
        ]),
      _breakdownCard('POR TIPO', [
        for (final type in VehicleType.values)
          _breakdownLine(type.pluralLabel, summary.byType[type] ?? 0),
      ]),
      _breakdownCard('POR PROVINCIA', _provinceLines(summary.byProvince)),
    ];
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) pw.SizedBox(width: 10),
          pw.Expanded(child: cards[i]),
        ],
      ],
    );
  }

  static List<pw.Widget> _provinceLines(List<ProvinceGroup> groups) {
    final byCountDesc = [...groups]
      ..sort((group, other) => other.count.compareTo(group.count));
    final shown = byCountDesc.take(_maxProvincesInSummary).toList();
    final hidden = byCountDesc.length - shown.length;
    return [
      for (final group in shown)
        _breakdownLine(group.province.name, group.count),
      if (hidden > 0)
        _mutedLine(
            hidden == 1 ? '+1 provincia más' : '+$hidden provincias más'),
    ];
  }

  static pw.Widget _card(String title, pw.Widget body) => pw.Container(
        height: _summaryCardHeight,
        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: pw.BoxDecoration(
          color: PdfTheme.surface,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfTheme.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 6),
            body,
          ],
        ),
      );

  static pw.Widget _totalCard(int total) => _card(
        'TOTAL',
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '$total',
              style: pw.TextStyle(
                fontSize: 30,
                fontWeight: pw.FontWeight.bold,
                color: PdfTheme.primary,
              ),
            ),
            pw.Text(
              total == 1 ? 'vehículo en el listado' : 'vehículos en el listado',
              style: const pw.TextStyle(
                  fontSize: 8.5, color: PdfTheme.textSecondary),
            ),
          ],
        ),
      );

  static pw.Widget _breakdownCard(String title, List<pw.Widget> lines) =>
      _card(title, lines.isEmpty ? _mutedLine('Sin datos') : pw.Column(children: lines));

  static pw.Widget _breakdownLine(String label, int count, {PdfColor? dot}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3.5),
        child: pw.Row(children: [
          if (dot != null) ...[_dot(dot), pw.SizedBox(width: 5)],
          pw.Expanded(
            child: pw.Text(
              label,
              maxLines: 1,
              style: const pw.TextStyle(
                  fontSize: 8.5, color: PdfTheme.textPrimary),
            ),
          ),
          pw.Text(
            '$count',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.textPrimary,
            ),
          ),
        ]),
      );

  static pw.Widget _mutedLine(String text) => pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8, color: PdfTheme.textSecondary),
      );

  static pw.Widget _dot(PdfColor color) => pw.Container(
        width: 5,
        height: 5,
        decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
      );

  // ----------------------------------------------------------------- Table

  static pw.Widget _table(List<Vehicle> vehicles) => pw.Table(
        columnWidths: const {
          0: pw.FixedColumnWidth(62), // Patente
          1: pw.FlexColumnWidth(2.2), // Vehículo
          2: pw.FixedColumnWidth(56), // Tipo
          3: pw.FixedColumnWidth(80), // Estado
          4: pw.FlexColumnWidth(2.0), // Ubicación
          5: pw.FlexColumnWidth(1.8), // Responsable
          6: pw.FixedColumnWidth(58), // Combustible
          7: pw.FixedColumnWidth(58), // Km
          8: pw.FixedColumnWidth(58), // VTV
          9: pw.FlexColumnWidth(1.3), // Seguro
        },
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        tableWidth: pw.TableWidth.max,
        children: [
          _headerRow(),
          for (var i = 0; i < vehicles.length; i++)
            _vehicleRow(vehicles[i], striped: i.isOdd),
        ],
      );

  static pw.TableRow _headerRow() => pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(
          color: PdfTheme.primary,
          borderRadius: pw.BorderRadius.only(
            topLeft: pw.Radius.circular(6),
            topRight: pw.Radius.circular(6),
          ),
        ),
        children: [
          _headerCell('Patente'),
          _headerCell('Vehículo'),
          _headerCell('Tipo'),
          _headerCell('Estado'),
          _headerCell('Ubicación'),
          _headerCell('Responsable'),
          _headerCell('Combustible'),
          _headerCell('Km', align: pw.TextAlign.right),
          _headerCell('VTV'),
          _headerCell('Seguro'),
        ],
      );

  static pw.TableRow _vehicleRow(Vehicle vehicle, {required bool striped}) {
    final province = ArgentinaProvinces.getById(vehicle.provinceId);
    final lugar = vehicle.lugar;
    final location = lugar == null || lugar.isEmpty
        ? province.name
        : '${province.name} · $lugar';
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: striped ? PdfTheme.surface : PdfTheme.background,
        border: const pw.Border(
          bottom: pw.BorderSide(color: PdfTheme.divider, width: 0.5),
        ),
      ),
      children: [
        _cell(pw.Text(
          vehicle.plate.trim().isEmpty ? _missing : vehicle.plate,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfTheme.primary,
            letterSpacing: 0.6,
          ),
        )),
        _twoLineCell(vehicle.displayName, _yearAndColor(vehicle)),
        _textCell(vehicle.type.label),
        _statusCell(vehicle.status),
        _twoLineCell(vehicle.city, location),
        _twoLineCell(vehicle.responsibleName, vehicle.responsiblePhone),
        _textCell(vehicle.fuelType.label),
        _textCell(AppFormats.integer(vehicle.km), align: pw.TextAlign.right),
        _textCell(_date(vehicle.vtvExpiry)),
        _twoLineCell(_date(vehicle.insuranceExpiry), vehicle.insuranceCompany),
      ],
    );
  }

  static pw.Widget _cell(pw.Widget child, {double vertical = 5}) => pw.Padding(
        padding: pw.EdgeInsets.symmetric(horizontal: 6, vertical: vertical),
        child: child,
      );

  static pw.Widget _headerCell(String text,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      _cell(
        pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
        vertical: 7,
      );

  static pw.Widget _textCell(String text,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      _cell(pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 8.5, color: PdfTheme.textPrimary),
      ));

  static pw.Widget _twoLineCell(String primary, String? secondary) => _cell(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              primary,
              style: const pw.TextStyle(
                  fontSize: 8.5, color: PdfTheme.textPrimary),
            ),
            if (secondary != null && secondary.isNotEmpty) ...[
              pw.SizedBox(height: 1.5),
              pw.Text(
                secondary,
                style: const pw.TextStyle(
                    fontSize: 7.5, color: PdfTheme.textSecondary),
              ),
            ],
          ],
        ),
      );

  static pw.Widget _statusCell(VehicleStatus status) => _cell(
        pw.Row(children: [
          _dot(PdfTheme.statusColor(status)),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              status.label,
              style: const pw.TextStyle(
                  fontSize: 8.5, color: PdfTheme.textPrimary),
            ),
          ),
        ]),
      );

  static String _date(DateTime? date) =>
      date == null ? _missing : _dateFormat.format(date);

  /// "2020 · Blanco"; sin el año cuando no está cargado (0).
  static String _yearAndColor(Vehicle vehicle) {
    final colorName = VehicleColors.getByColor(vehicle.color).name;
    return vehicle.year > 0 ? '${vehicle.year} · $colorName' : colorName;
  }

  static pw.Widget _emptyNotice() => pw.Container(
        padding: const pw.EdgeInsets.all(24),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: PdfTheme.surface,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          'No hay vehículos para el filtro seleccionado',
          style:
              const pw.TextStyle(fontSize: 10, color: PdfTheme.textSecondary),
        ),
      );

  // ---------------------------------------------------------------- Footer

  static pw.Widget _footer(pw.Context context, DateTime now) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: PdfTheme.divider, width: 0.5),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generado el ${_dateTimeFormat.format(now)}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfTheme.textSecondary),
            ),
            pw.Text(
              'Gestor de Vehículos',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfTheme.primary,
              ),
            ),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfTheme.textSecondary),
            ),
          ],
        ),
      );
}
