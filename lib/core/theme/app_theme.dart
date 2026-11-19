import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_component_themes.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// `ThemeData` oscuro (principal) y claro, armados solo con los tokens del
/// design system (`docs/design-system/`).
class AppTheme {
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: _colorScheme(c, brightness),
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.surface,
      fontFamily: AppFonts.body,
      textTheme: AppComponentThemes.textTheme(c),
      iconTheme: IconThemeData(color: c.textMuted, size: Sizes.iconLg),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [c],
      appBarTheme: AppComponentThemes.appBar(c, brightness),
      navigationBarTheme: AppComponentThemes.navigationBar(c),
      inputDecorationTheme: AppComponentThemes.inputDecoration(c),
      filledButtonTheme: AppComponentThemes.filledButton(c),
      elevatedButtonTheme: AppComponentThemes.elevatedButton(c),
      outlinedButtonTheme: AppComponentThemes.outlinedButton(c),
      textButtonTheme: AppComponentThemes.textButton(c),
      iconButtonTheme: AppComponentThemes.iconButton(c),
      floatingActionButtonTheme: AppComponentThemes.fab(c),
      cardTheme: AppComponentThemes.card(c),
      dialogTheme: AppComponentThemes.dialog(c),
      bottomSheetTheme: AppComponentThemes.bottomSheet(c),
      chipTheme: AppComponentThemes.chip(c),
      segmentedButtonTheme: AppComponentThemes.segmentedButton(c),
      datePickerTheme: AppComponentThemes.datePicker(c),
      snackBarTheme: AppComponentThemes.snackBar(c),
      dividerTheme: AppComponentThemes.divider(c),
      listTileTheme: AppComponentThemes.listTile(c),
      checkboxTheme: AppComponentThemes.checkbox(c),
      radioTheme: AppComponentThemes.radio(c),
      switchTheme: AppComponentThemes.switchTheme(c),
      progressIndicatorTheme: AppComponentThemes.progressIndicator(c),
      popupMenuTheme: AppComponentThemes.popupMenu(c),
      tooltipTheme: AppComponentThemes.tooltip(c),
      textSelectionTheme: AppComponentThemes.textSelection(c),
    );
  }

  static ColorScheme _colorScheme(AppColors c, Brightness brightness) =>
      ColorScheme(
        brightness: brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        primaryContainer: c.accentSoft,
        onPrimaryContainer: c.text,
        secondary: c.accent,
        onSecondary: c.onAccent,
        secondaryContainer: c.accentSoft,
        onSecondaryContainer: c.text,
        tertiary: c.accent,
        onTertiary: c.onAccent,
        tertiaryContainer: c.accentSoft,
        onTertiaryContainer: c.text,
        error: c.danger,
        onError: c.onDanger,
        errorContainer: c.dangerSoft,
        onErrorContainer: c.text,
        surface: c.bg,
        onSurface: c.text,
        onSurfaceVariant: c.textMuted,
        surfaceDim: c.bg,
        surfaceBright: c.surfaceRaised,
        surfaceContainerLowest: c.bg,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surfaceRaised,
        surfaceContainerHighest: c.surfaceRaised,
        outline: c.borderStrong,
        outlineVariant: c.border,
        shadow: c.shadow,
        scrim: c.scrim,
        inverseSurface: c.text,
        onInverseSurface: c.bg,
        inversePrimary: c.accent,
        surfaceTint: Colors.transparent,
      );
}
