part of '../vehicle_detail_screen.dart';

enum _PdfReport { vehicle, fuel, combined }

/// Período y orden de las cargas para los reportes con combustible.
class _ReportConfig {
  final DateTime start;
  final DateTime end;
  final bool ascending;

  const _ReportConfig({
    required this.start,
    required this.end,
    required this.ascending,
  });

  /// Fin del período inclusive: hasta el último segundo del día.
  DateTime get endOfDay => DateTime(end.year, end.month, end.day, 23, 59, 59);
}

/// Exportar PDF del vehículo: elegir el reporte y, si incluye combustible, el
/// período y el orden de las cargas.
Future<void> _showPdfOptions(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
  List<VehiclePhoto> photos,
  List<DocumentPhoto> documentPhotos,
  List<Maintenance> maintenances,
  List<VehicleNote> notes,
) async {
  final report = await showAppOptionsSheet<_PdfReport>(
    context,
    title: 'Exportar PDF',
    options: const [
      AppSheetOption(
        value: _PdfReport.vehicle,
        icon: Icons.directions_car_rounded,
        label: 'Datos del vehículo',
        description: 'Información general, fotos, papeles y mantenimientos',
      ),
      AppSheetOption(
        value: _PdfReport.fuel,
        icon: Icons.local_gas_station_rounded,
        label: 'Registro de combustible',
        description: 'Resumen y detalle de las cargas de un período',
      ),
      AppSheetOption(
        value: _PdfReport.combined,
        icon: Icons.summarize_rounded,
        label: 'Reporte completo',
        description: 'Datos del vehículo y registro de combustible',
      ),
    ],
  );
  if (report == null || !context.mounted) return;

  if (report == _PdfReport.vehicle) {
    await runPdfExport(
      context,
      progressTitle: 'Generando el PDF…',
      progressSubtitle: 'Descargando las fotos y armando el documento',
      fileName: 'vehiculo_${vehicle.plate}',
      successMessage: 'PDF listo',
      errorMessage: 'No se pudo generar el PDF. Revisá la conexión.',
      generate: () => PdfService.generateVehiclePdf(
        vehicle: vehicle,
        photos: photos,
        documentPhotos: documentPhotos,
        maintenances: maintenances,
      ),
    );
    return;
  }

  final combined = report == _PdfReport.combined;
  final config = await showAppSheet<_ReportConfig>(
    context,
    builder: (_) => _ReportConfigSheet(
      title: combined ? 'Reporte completo' : 'Registro de combustible',
    ),
  );
  if (config == null || !context.mounted) return;

  Future<List<FuelCharge>> loadCharges() => ref
      .read(fuelChargeRepositoryProvider)
      .getFuelChargesByDateRange(vehicle.id!, config.start, config.endOfDay);

  await runPdfExport(
    context,
    progressTitle: 'Generando el reporte…',
    progressSubtitle: combined
        ? 'Juntando los datos del vehículo y las cargas'
        : 'Juntando las cargas del período',
    fileName: combined
        ? 'vehiculo_${vehicle.plate}_completo'
        : 'vehiculo_${vehicle.plate}_combustible',
    successMessage: 'Reporte listo',
    errorMessage: 'No se pudo generar el reporte. Revisá la conexión.',
    generate: () async {
      final fuelCharges = await loadCharges();
      if (!combined) {
        return PdfService.generateFuelReportPdf(
          vehicle: vehicle,
          fuelCharges: fuelCharges,
          startDate: config.start,
          endDate: config.end,
          ascending: config.ascending,
        );
      }
      return PdfService.generateCombinedPdf(
        vehicle: vehicle,
        photos: photos,
        documentPhotos: documentPhotos,
        maintenances: maintenances,
        notes: notes,
        fuelCharges: fuelCharges,
        startDate: config.start,
        endDate: config.end,
        ascending: config.ascending,
      );
    },
  );
}

enum _PeriodChoice { thisYear, custom }

/// Período (este año o fechas elegidas) y orden de las cargas.
class _ReportConfigSheet extends StatefulWidget {
  final String title;

  const _ReportConfigSheet({required this.title});

  @override
  State<_ReportConfigSheet> createState() => _ReportConfigSheetState();
}

class _ReportConfigSheetState extends State<_ReportConfigSheet> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  _PeriodChoice _period = _PeriodChoice.thisYear;
  DateTimeRange? _customRange;
  bool _ascending = true;

  DateTimeRange get _range =>
      _period == _PeriodChoice.custom && _customRange != null
          ? _customRange!
          : DateTimeRange(start: DateTime(_today.year), end: _today);

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _today,
      initialDateRange: _range,
      helpText: 'Elegí el período',
      saveText: 'Aceptar',
      cancelText: 'Cancelar',
      fieldStartLabelText: 'Desde',
      fieldEndLabelText: 'Hasta',
    );
    if (!mounted) return;
    setState(() {
      if (picked != null) _customRange = picked;
      _period = _customRange == null ? _PeriodChoice.thisYear : _PeriodChoice.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final range = _range;
    return AppSheet(
      title: widget.title,
      footer: SizedBox(
        width: double.infinity,
        height: Sizes.controlH,
        child: FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            _ReportConfig(start: range.start, end: range.end, ascending: _ascending),
          ),
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: const Text('Generar PDF'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Período de las cargas'),
          const Gap(Space.s2),
          SegmentedButton<_PeriodChoice>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _PeriodChoice.thisYear,
                label: Text('Año ${_today.year}'),
              ),
              const ButtonSegment(
                value: _PeriodChoice.custom,
                label: Text('Elegir fechas'),
              ),
            ],
            selected: {_period},
            onSelectionChanged: (selection) {
              if (selection.first == _PeriodChoice.custom) {
                _pickRange();
              } else {
                setState(() => _period = _PeriodChoice.thisYear);
              }
            },
          ),
          const Gap(Space.s2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${AppFormats.date(range.start)} – ${AppFormats.date(range.end)}',
                  style: AppText.body.tabular.copyWith(color: c.textMuted),
                ),
              ),
              if (_period == _PeriodChoice.custom)
                TextButton(onPressed: _pickRange, child: const Text('Cambiar')),
            ],
          ),
          const Gap(Space.s5),
          const FieldLabel('Orden de las cargas'),
          const Gap(Space.s2),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, label: Text('Más antigua primero')),
              ButtonSegment(value: false, label: Text('Más reciente primero')),
            ],
            selected: {_ascending},
            onSelectionChanged: (selection) =>
                setState(() => _ascending = selection.first),
          ),
        ],
      ),
    );
  }
}
