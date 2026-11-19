import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Tono semántico de un estado: color del ícono o texto y su fondo suave.
enum Tone { neutral, info, success, warning, danger }

extension ToneColors on Tone {
  Color foreground(AppColors c) => switch (this) {
    Tone.neutral => c.textMuted,
    Tone.info => c.accent,
    Tone.success => c.success,
    Tone.warning => c.warning,
    Tone.danger => c.danger,
  };

  Color background(AppColors c) => switch (this) {
    Tone.neutral => c.surfaceRaised,
    Tone.info => c.accentSoft,
    Tone.success => c.successSoft,
    Tone.warning => c.warningSoft,
    Tone.danger => c.dangerSoft,
  };
}
