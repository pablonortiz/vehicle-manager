import 'package:intl/intl.dart';
import '../core/constants/provinces.dart';
import '../core/constants/vehicle_constants.dart';
import 'models/vehicle.dart';

/// Qué vehículos entran al listado exportado: un estado puntual (o todos) y,
/// opcionalmente, la ubicación filtrada en pantalla.
class FleetReportScope {
  final VehicleStatus? status;
  final String? locationLabel;

  const FleetReportScope({this.status, this.locationLabel});

  static final _fileDate = DateFormat('yyyyMMdd');

  /// "Flota completa" / "Vehículos fuera de servicio".
  String get title {
    final status = this.status;
    if (status == null) return 'Flota completa';
    return 'Vehículos ${status.pluralLabel.toLowerCase()}';
  }

  /// Título más la ubicación acotada: "Vehículos disponibles · Buenos Aires >
  /// La Plata". Acotado a una ubicación, "Flota completa" sería contradictorio.
  String get subtitle {
    final location = locationLabel;
    if (location == null) return title;
    final base = status == null ? 'Todos los vehículos' : title;
    return '$base · $location';
  }

  /// Sin extensión: "listado_vehiculos_fuera_de_servicio_20260915".
  String fileName(DateTime now) {
    final status = this.status;
    final statusSlug = status == null
        ? ''
        : '_${status.pluralLabel.toLowerCase().replaceAll(' ', '_')}';
    return 'listado_vehiculos${statusSlug}_${_fileDate.format(now)}';
  }
}

/// Vehículos de una provincia, ordenados por ciudad y patente.
class ProvinceGroup {
  final Province province;
  final List<Vehicle> vehicles;

  const ProvinceGroup(this.province, this.vehicles);

  int get count => vehicles.length;
}

/// Agregados de un conjunto de vehículos para el listado: totales por estado,
/// tipo y provincia, y los vehículos ordenados por provincia > ciudad > patente.
/// Puro y testeable.
class FleetSummary {
  final int total;
  final Map<VehicleStatus, int> byStatus;
  final Map<VehicleType, int> byType;
  final List<ProvinceGroup> byProvince;

  const FleetSummary._({
    required this.total,
    required this.byStatus,
    required this.byType,
    required this.byProvince,
  });

  factory FleetSummary.from(List<Vehicle> vehicles) => FleetSummary._(
        total: vehicles.length,
        byStatus: countByStatus(vehicles),
        byType: countByType(vehicles),
        byProvince: _groupByProvince(vehicles),
      );

  /// Todos los vehículos en el orden de la tabla: provincia > ciudad > patente.
  List<Vehicle> get sortedVehicles =>
      byProvince.expand((group) => group.vehicles).toList();

  /// Conteo por estado; solo los estados con al menos un vehículo.
  static Map<VehicleStatus, int> countByStatus(List<Vehicle> vehicles) =>
      _countBy(vehicles, (vehicle) => vehicle.status);

  /// Conteo por tipo; solo los tipos con al menos un vehículo.
  static Map<VehicleType, int> countByType(List<Vehicle> vehicles) =>
      _countBy(vehicles, (vehicle) => vehicle.type);

  static Map<K, int> _countBy<K>(
      List<Vehicle> vehicles, K Function(Vehicle) keyOf) {
    final counts = <K, int>{};
    for (final vehicle in vehicles) {
      counts.update(keyOf(vehicle), (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  // El id de provincia sigue el orden alfabético de ArgentinaProvinces.all,
  // que ya resuelve los acentos ("Córdoba" antes que "Corrientes").
  static List<ProvinceGroup> _groupByProvince(List<Vehicle> vehicles) {
    final byProvinceId = <int, List<Vehicle>>{};
    for (final vehicle in vehicles) {
      byProvinceId.putIfAbsent(vehicle.provinceId, () => []).add(vehicle);
    }
    final provinceIds = byProvinceId.keys.toList()..sort();
    return [
      for (final provinceId in provinceIds)
        ProvinceGroup(
          ArgentinaProvinces.getById(provinceId),
          byProvinceId[provinceId]!..sort(_byCityThenPlate),
        ),
    ];
  }

  static int _byCityThenPlate(Vehicle vehicle, Vehicle other) {
    final byCity =
        vehicle.city.toLowerCase().compareTo(other.city.toLowerCase());
    return byCity != 0 ? byCity : vehicle.plate.compareTo(other.plate);
  }
}
