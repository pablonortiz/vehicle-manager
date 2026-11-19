import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum VehicleType {
  car,
  pickup,
  truck,
  motorcycle,
}

extension VehicleTypeExtension on VehicleType {
  String get label {
    switch (this) {
      case VehicleType.car:
        return 'Auto';
      case VehicleType.pickup:
        return 'Camioneta';
      case VehicleType.truck:
        return 'Camión';
      case VehicleType.motorcycle:
        return 'Moto';
    }
  }

  /// Plural para conteos y títulos: "Autos", "Camionetas".
  String get pluralLabel {
    switch (this) {
      case VehicleType.car:
        return 'Autos';
      case VehicleType.pickup:
        return 'Camionetas';
      case VehicleType.truck:
        return 'Camiones';
      case VehicleType.motorcycle:
        return 'Motos';
    }
  }

  String get iconAsset {
    switch (this) {
      case VehicleType.car:
        return 'assets/icons/car.svg';
      case VehicleType.pickup:
        return 'assets/icons/pickup.svg';
      case VehicleType.truck:
        return 'assets/icons/truck.svg';
      case VehicleType.motorcycle:
        return 'assets/icons/motorcycle.svg';
    }
  }
}

enum VehicleStatus {
  available,
  inUse,
  inWorkshop,
  outOfService,
}

extension VehicleStatusExtension on VehicleStatus {
  String get label {
    switch (this) {
      case VehicleStatus.available:
        return 'Disponible';
      case VehicleStatus.inUse:
        return 'En uso';
      case VehicleStatus.inWorkshop:
        return 'En taller';
      case VehicleStatus.outOfService:
        return 'Fuera de servicio';
    }
  }

  /// Plural para conteos y títulos: "Disponibles", "Fuera de servicio".
  String get pluralLabel {
    switch (this) {
      case VehicleStatus.available:
        return 'Disponibles';
      case VehicleStatus.inUse:
        return 'En uso';
      case VehicleStatus.inWorkshop:
        return 'En taller';
      case VehicleStatus.outOfService:
        return 'Fuera de servicio';
    }
  }
}

enum FuelType {
  nafta,
  diesel,
  gnc,
  electrico,
  hibrido,
}

extension FuelTypeExtension on FuelType {
  String get label {
    switch (this) {
      case FuelType.nafta:
        return 'Nafta';
      case FuelType.diesel:
        return 'Diesel';
      case FuelType.gnc:
        return 'GNC';
      case FuelType.electrico:
        return 'Eléctrico';
      case FuelType.hibrido:
        return 'Híbrido';
    }
  }
}

// Colores predefinidos para vehículos
class VehicleColors {
  static const List<VehicleColorOption> options = [
    VehicleColorOption(name: 'Blanco', color: PaintColors.blanco),
    VehicleColorOption(name: 'Negro', color: PaintColors.negro),
    VehicleColorOption(name: 'Gris plata', color: PaintColors.grisPlata),
    VehicleColorOption(name: 'Gris oscuro', color: PaintColors.grisOscuro),
    VehicleColorOption(name: 'Rojo', color: PaintColors.rojo),
    VehicleColorOption(name: 'Azul', color: PaintColors.azul),
    VehicleColorOption(name: 'Azul marino', color: PaintColors.azulMarino),
    VehicleColorOption(name: 'Verde', color: PaintColors.verde),
    VehicleColorOption(name: 'Amarillo', color: PaintColors.amarillo),
    VehicleColorOption(name: 'Naranja', color: PaintColors.naranja),
    VehicleColorOption(name: 'Marrón', color: PaintColors.marron),
    VehicleColorOption(name: 'Beige', color: PaintColors.beige),
  ];

  static VehicleColorOption getByColor(Color color) {
    return options.firstWhere(
      (o) => o.color.toARGB32() == color.toARGB32(),
      orElse: () => options.first,
    );
  }
}

class VehicleColorOption {
  final String name;
  final Color color;

  const VehicleColorOption({
    required this.name,
    required this.color,
  });
}
