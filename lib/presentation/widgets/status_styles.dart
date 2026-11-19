import 'package:flutter/material.dart';

import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_tone.dart';
import '../../domain/expiry_status.dart';

/// Tono e ícono de cada estado del vehículo (pill, filtros, stats).
extension VehicleStatusStyle on VehicleStatus {
  Tone get tone => switch (this) {
    VehicleStatus.available => Tone.success,
    VehicleStatus.inUse => Tone.info,
    VehicleStatus.inWorkshop => Tone.warning,
    VehicleStatus.outOfService => Tone.danger,
  };

  IconData get statusIcon => switch (this) {
    VehicleStatus.available => Icons.check_circle_rounded,
    VehicleStatus.inUse => Icons.key_rounded,
    VehicleStatus.inWorkshop => Icons.build_rounded,
    VehicleStatus.outOfService => Icons.block_rounded,
  };
}

/// Tono e ícono de un vencimiento: vencido siempre en `danger` con `error`.
extension ExpiryStatusStyle on ExpiryStatus {
  Tone get tone => switch (state) {
    ExpiryState.valid => Tone.success,
    ExpiryState.expiringSoon => Tone.warning,
    ExpiryState.expired => Tone.danger,
    ExpiryState.unknown => Tone.neutral,
  };

  IconData get icon => switch (state) {
    ExpiryState.valid => Icons.verified_rounded,
    ExpiryState.expiringSoon => Icons.schedule_rounded,
    ExpiryState.expired => Icons.error_rounded,
    ExpiryState.unknown => Icons.help_rounded,
  };
}
