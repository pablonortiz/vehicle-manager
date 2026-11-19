import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/constants/vehicle_constants.dart';
import 'package:gestor_vehiculos/core/theme/app_colors.dart';
import 'package:gestor_vehiculos/domain/models/vehicle.dart';
import 'package:gestor_vehiculos/presentation/screens/vehicle_form/vehicle_form_data.dart';

Vehicle makeVehicle() => Vehicle(
      id: 'v1',
      plate: 'AE472KP',
      type: VehicleType.pickup,
      brand: 'Toyota',
      model: 'Hilux',
      year: 2021,
      color: PaintColors.negro,
      km: 84300,
      insuranceCompany: 'Nación Seguros',
      vtvExpiry: DateTime(2026, 12, 12),
      fuelType: FuelType.diesel,
      status: VehicleStatus.inUse,
      provinceId: 6,
      city: 'Córdoba',
      cityId: 'c1',
      lugar: 'Base norte',
      lugarId: 'l1',
      responsibleName: 'Juan Pérez',
      responsiblePhone: '3515550101',
    );

void main() {
  test('recién creado o recién cargado no tiene cambios', () {
    final emptyForm = VehicleFormData();
    expect(emptyForm.isDirty, isFalse);

    final loadedForm = VehicleFormData()..load(makeVehicle());
    expect(loadedForm.isDirty, isFalse);
    expect(loadedForm.km.text, '84.300');
  });

  test('cambiar un texto o una selección marca cambios; volver atrás no', () {
    final form = VehicleFormData()..load(makeVehicle());

    form.brand.text = 'Toyota ';
    expect(form.isDirty, isTrue);
    form.brand.text = 'Toyota';
    expect(form.isDirty, isFalse);

    form.status = VehicleStatus.available;
    expect(form.isDirty, isTrue);
    form.status = VehicleStatus.inUse;
    expect(form.isDirty, isFalse);

    form.vtvExpiry = null;
    expect(form.isDirty, isTrue);
  });

  test('otra provincia limpia ciudad y lugar; la misma no toca nada', () {
    final form = VehicleFormData()..load(makeVehicle());
    form.selectProvince(6);
    expect(form.city.text, 'Córdoba');
    expect(form.cityId, 'c1');

    form.selectProvince(2);
    expect(form.city.text, isEmpty);
    expect(form.lugar.text, isEmpty);
    expect(form.cityId, isNull);
    expect(form.lugarId, isNull);
  });

  test('toVehicle normaliza patente, km y opcionales vacíos', () {
    final form = VehicleFormData()..load(makeVehicle());
    form.plate.text = ' ab123cd ';
    form.km.text = '1.250.000';
    form.insuranceCompany.text = '  ';
    form.lugar.text = '';

    final vehicle = form.toVehicle(id: 'v1', cityId: 'c1', lugarId: null);
    expect(vehicle.plate, 'AB123CD');
    expect(vehicle.km, 1250000);
    expect(vehicle.insuranceCompany, isNull);
    expect(vehicle.lugar, isNull);
    expect(vehicle.color, PaintColors.negro);
  });

  test('markSaved toma lo actual como guardado', () {
    final form = VehicleFormData()..load(makeVehicle());
    form.model.text = 'Hilux SRV';
    expect(form.isDirty, isTrue);
    form.markSaved();
    expect(form.isDirty, isFalse);
  });
}
