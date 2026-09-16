import 'package:flutter/material.dart';

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

  Color get color {
    switch (this) {
      case VehicleStatus.available:
        return const Color(0xFF3FB950);
      case VehicleStatus.inUse:
        return const Color(0xFF58A6FF);
      case VehicleStatus.inWorkshop:
        return const Color(0xFFD29922);
      case VehicleStatus.outOfService:
        return const Color(0xFFF85149);
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleStatus.available:
        return Icons.check_circle;
      case VehicleStatus.inUse:
        return Icons.directions_car;
      case VehicleStatus.inWorkshop:
        return Icons.build;
      case VehicleStatus.outOfService:
        return Icons.cancel;
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

  IconData get icon {
    switch (this) {
      case FuelType.nafta:
        return Icons.local_gas_station;
      case FuelType.diesel:
        return Icons.local_gas_station;
      case FuelType.gnc:
        return Icons.propane_tank;
      case FuelType.electrico:
        return Icons.electric_bolt;
      case FuelType.hibrido:
        return Icons.eco;
    }
  }
}

// Colores predefinidos para vehículos
class VehicleColors {
  static const List<VehicleColorOption> options = [
    VehicleColorOption(name: 'Blanco', color: Color(0xFFFFFFFF)),
    VehicleColorOption(name: 'Negro', color: Color(0xFF1A1A1A)),
    VehicleColorOption(name: 'Gris Plata', color: Color(0xFFC0C0C0)),
    VehicleColorOption(name: 'Gris Oscuro', color: Color(0xFF4A4A4A)),
    VehicleColorOption(name: 'Rojo', color: Color(0xFFDC2626)),
    VehicleColorOption(name: 'Azul', color: Color(0xFF2563EB)),
    VehicleColorOption(name: 'Azul Marino', color: Color(0xFF1E3A5F)),
    VehicleColorOption(name: 'Verde', color: Color(0xFF16A34A)),
    VehicleColorOption(name: 'Amarillo', color: Color(0xFFEAB308)),
    VehicleColorOption(name: 'Naranja', color: Color(0xFFEA580C)),
    VehicleColorOption(name: 'Marrón', color: Color(0xFF78350F)),
    VehicleColorOption(name: 'Beige', color: Color(0xFFD4C5A9)),
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
