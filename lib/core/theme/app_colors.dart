import 'package:flutter/material.dart';

/// Paleta semántica del design system (`docs/design-system/tokens.json`).
/// Se lee del contexto con `context.colors`, así sigue al tema activo.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color brand;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color onDanger;
  final Color catMaintenance;
  final Color catMaintenanceSoft;
  final Color whatsapp;
  final Color onWhatsapp;
  final Color scrim;
  final Color shadow;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.brand,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.onDanger,
    required this.catMaintenance,
    required this.catMaintenanceSoft,
    required this.whatsapp,
    required this.onWhatsapp,
    required this.scrim,
    required this.shadow,
  });

  static const dark = AppColors(
    bg: Color(0xFF0A1628),
    surface: Color(0xFF122035),
    surfaceRaised: Color(0xFF1A2D47),
    border: Color(0xFF2A4060),
    borderStrong: Color(0xFF6283A6),
    text: Color(0xFFF0F4F8),
    textMuted: Color(0xFF9DB5CC),
    accent: Color(0xFF75AADB),
    onAccent: Color(0xFF0A1628),
    accentSoft: Color(0xFF1B3555),
    brand: Color(0xFF75AADB),
    success: Color(0xFF4CC38A),
    successSoft: Color(0xFF143A34),
    warning: Color(0xFFF2B34C),
    warningSoft: Color(0xFF3D3222),
    danger: Color(0xFFFF7B6E),
    dangerSoft: Color(0xFF45232C),
    onDanger: Color(0xFF2A0A0D),
    catMaintenance: Color(0xFFB9A2F0),
    catMaintenanceSoft: Color(0xFF2C2A55),
    whatsapp: Color(0xFF25D366),
    onWhatsapp: Color(0xFF0A1628),
    scrim: Color(0x99040A14),
    shadow: Color(0x73000000),
  );

  static const light = AppColors(
    bg: Color(0xFFF2F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFE8EEF5),
    border: Color(0xFFD2DBE6),
    borderStrong: Color(0xFF6F87A3),
    text: Color(0xFF0F1E33),
    textMuted: Color(0xFF48607A),
    accent: Color(0xFF1C69A8),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFDCEBF8),
    brand: Color(0xFF75AADB),
    success: Color(0xFF14744A),
    successSoft: Color(0xFFDAF1E5),
    warning: Color(0xFF8A5A00),
    warningSoft: Color(0xFFFBECC8),
    danger: Color(0xFFB8322A),
    dangerSoft: Color(0xFFFBE1DE),
    onDanger: Color(0xFFFFFFFF),
    catMaintenance: Color(0xFF5B3FB5),
    catMaintenanceSoft: Color(0xFFE7E1FA),
    whatsapp: Color(0xFF25D366),
    onWhatsapp: Color(0xFF0A1628),
    scrim: Color(0x730F1E33),
    shadow: Color(0x2E0F1E33),
  );

  Color get statusAvailable => success;
  Color get statusInUse => accent;
  Color get statusWorkshop => warning;
  Color get statusOut => danger;
  Color get catFuel => accent;

  /// `shadow-overlay`: única sombra, solo para lo que flota (FAB, menús,
  /// overlay de autocompletado, snackbar y diálogo).
  List<BoxShadow> get overlayShadow => [
        BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8)),
      ];

  /// Los tokens son fijos por tema: no hay variantes que derivar.
  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color from, Color to) => Color.lerp(from, to, t)!;
    return AppColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentSoft: mix(accentSoft, other.accentSoft),
      brand: mix(brand, other.brand),
      success: mix(success, other.success),
      successSoft: mix(successSoft, other.successSoft),
      warning: mix(warning, other.warning),
      warningSoft: mix(warningSoft, other.warningSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      onDanger: mix(onDanger, other.onDanger),
      catMaintenance: mix(catMaintenance, other.catMaintenance),
      catMaintenanceSoft: mix(catMaintenanceSoft, other.catMaintenanceSoft),
      whatsapp: mix(whatsapp, other.whatsapp),
      onWhatsapp: mix(onWhatsapp, other.onWhatsapp),
      scrim: mix(scrim, other.scrim),
      shadow: mix(shadow, other.shadow),
    );
  }
}

/// Colores físicos de los vehículos (`paint-*`): son datos, no semántica.
/// Solo se muestran como muestra circular con anillo, igual en ambos temas.
abstract final class PaintColors {
  static const blanco = Color(0xFFFFFFFF);
  static const negro = Color(0xFF1A1A1A);
  static const grisPlata = Color(0xFFC0C0C0);
  static const grisOscuro = Color(0xFF4A4A4A);
  static const rojo = Color(0xFFDC2626);
  static const azul = Color(0xFF2563EB);
  static const azulMarino = Color(0xFF1E3A5F);
  static const verde = Color(0xFF16A34A);
  static const amarillo = Color(0xFFEAB308);
  static const naranja = Color(0xFFEA580C);
  static const marron = Color(0xFF78350F);
  static const beige = Color(0xFFD4C5A9);
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}
