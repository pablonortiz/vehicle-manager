import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/constants/vehicle_constants.dart';
import '../../../core/utils/thousands_formatter.dart';
import '../../../domain/models/vehicle.dart';

/// Lo que se edita en el formulario de vehículo: los campos de texto y las
/// selecciones, con una foto de lo guardado para saber si hay cambios.
class VehicleFormData {
  final plate = TextEditingController();
  final brand = TextEditingController();
  final model = TextEditingController();
  final year = TextEditingController(text: '${DateTime.now().year}');
  final km = TextEditingController(text: '0');
  final insuranceCompany = TextEditingController();
  final city = TextEditingController();
  final lugar = TextEditingController();
  final responsibleName = TextEditingController();
  final responsiblePhone = TextEditingController();

  VehicleType type = VehicleType.car;
  Color paint = VehicleColors.options.first.color;
  FuelType fuelType = FuelType.nafta;
  VehicleStatus status = VehicleStatus.available;
  int provinceId = 1;
  String? cityId;
  String? lugarId;
  DateTime? vtvExpiry;
  DateTime? insuranceExpiry;

  late List<Object?> _saved;

  VehicleFormData() {
    _saved = _snapshot();
  }

  /// Carga un vehículo existente: lo cargado pasa a ser lo guardado.
  void load(Vehicle vehicle) {
    plate.text = vehicle.plate;
    brand.text = vehicle.brand;
    model.text = vehicle.model;
    year.text = '${vehicle.year}';
    km.text = formatWithDots('${vehicle.km}');
    insuranceCompany.text = vehicle.insuranceCompany ?? '';
    city.text = vehicle.city;
    lugar.text = vehicle.lugar ?? '';
    responsibleName.text = vehicle.responsibleName;
    responsiblePhone.text = vehicle.responsiblePhone;
    type = vehicle.type;
    paint = vehicle.color;
    fuelType = vehicle.fuelType;
    status = vehicle.status;
    provinceId = vehicle.provinceId;
    cityId = vehicle.cityId;
    lugarId = vehicle.lugarId;
    vtvExpiry = vehicle.vtvExpiry;
    insuranceExpiry = vehicle.insuranceExpiry;
    markSaved();
  }

  /// Comparado contra lo guardado: tocar un campo sin cambiarlo no cuenta.
  bool get isDirty => !listEquals(_snapshot(), _saved);

  void markSaved() => _saved = _snapshot();

  /// Otra provincia invalida la ciudad y el lugar elegidos.
  /// Los ids se sueltan antes de limpiar el texto: los listeners de los
  /// autocompletados ya ven la selección vacía.
  void selectProvince(int id) {
    if (id == provinceId) return;
    provinceId = id;
    cityId = null;
    lugarId = null;
    city.clear();
    lugar.clear();
  }

  /// La ciudad elegida cambió: el lugar era de la anterior.
  void selectCity(String? id) {
    cityId = id;
    lugarId = null;
    lugar.clear();
  }

  Vehicle toVehicle({String? id, String? cityId, String? lugarId}) {
    final insurer = insuranceCompany.text.trim();
    final lugarName = lugar.text.trim();
    return Vehicle(
      id: id,
      plate: plate.text.trim().toUpperCase(),
      type: type,
      brand: brand.text.trim(),
      model: model.text.trim(),
      year: int.tryParse(year.text) ?? DateTime.now().year,
      color: paint,
      km: int.tryParse(km.text.replaceAll('.', '')) ?? 0,
      vtvExpiry: vtvExpiry,
      insuranceCompany: insurer.isEmpty ? null : insurer,
      insuranceExpiry: insuranceExpiry,
      fuelType: fuelType,
      status: status,
      provinceId: provinceId,
      city: city.text.trim(),
      cityId: cityId,
      lugarId: lugarId,
      lugar: lugarName.isEmpty ? null : lugarName,
      responsibleName: responsibleName.text.trim(),
      responsiblePhone: responsiblePhone.text.trim(),
    );
  }

  List<TextEditingController> get _controllers => [
        plate,
        brand,
        model,
        year,
        km,
        insuranceCompany,
        city,
        lugar,
        responsibleName,
        responsiblePhone,
      ];

  List<Object?> _snapshot() => [
        for (final controller in _controllers) controller.text,
        type,
        paint.toARGB32(),
        fuelType,
        status,
        provinceId,
        vtvExpiry,
        insuranceExpiry,
      ];

  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
  }
}
