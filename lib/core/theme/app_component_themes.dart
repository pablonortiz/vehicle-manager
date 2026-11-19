import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Temas de los componentes de Material, armados solo con tokens. Los compone
/// `AppTheme`; ningún widget debería necesitar pasar `style:` en el call site.
abstract final class AppComponentThemes {
  static WidgetStateProperty<T> _bySelected<T>(T selected, T other) =>
      WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? selected : other);

  static SystemUiOverlayStyle overlayStyle(AppColors c, Brightness brightness) {
    final icons =
        brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons,
      statusBarBrightness: brightness,
      systemNavigationBarColor: c.surface,
      systemNavigationBarDividerColor: c.border,
      systemNavigationBarIconBrightness: icons,
    );
  }

  static TextTheme textTheme(AppColors c) => const TextTheme(
        displayLarge: AppText.display,
        displayMedium: AppText.display,
        displaySmall: AppText.display,
        headlineLarge: AppText.titleLg,
        headlineMedium: AppText.titleLg,
        headlineSmall: AppText.titleLg,
        titleLarge: AppText.titleMd,
        titleMedium: AppText.titleSm,
        titleSmall: AppText.label,
        bodyLarge: AppText.bodyLg,
        bodyMedium: AppText.body,
        bodySmall: AppText.caption,
        labelLarge: AppText.label,
        labelMedium: AppText.caption,
        labelSmall: AppText.overline,
      ).apply(bodyColor: c.text, displayColor: c.text);

  static AppBarTheme appBar(AppColors c, Brightness brightness) => AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.titleMd.copyWith(color: c.text),
        toolbarTextStyle: AppText.body.copyWith(color: c.text),
        iconTheme: IconThemeData(color: c.text, size: Sizes.iconLg),
        actionsIconTheme: IconThemeData(color: c.text, size: Sizes.iconLg),
        systemOverlayStyle: overlayStyle(c, brightness),
      );

  static NavigationBarThemeData navigationBar(AppColors c) =>
      NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: c.accentSoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: _bySelected(
          IconThemeData(color: c.accent, size: Sizes.iconLg),
          IconThemeData(color: c.textMuted, size: Sizes.iconLg),
        ),
        labelTextStyle: _bySelected(
          AppText.caption.copyWith(color: c.text, fontWeight: FontWeight.w600),
          AppText.caption.copyWith(color: c.textMuted),
        ),
      );

  static InputDecorationTheme inputDecoration(AppColors c) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: outline(c.borderStrong),
      enabledBorder: outline(c.borderStrong),
      focusedBorder: outline(c.accent, 2),
      errorBorder: outline(c.danger),
      focusedErrorBorder: outline(c.danger, 2),
      disabledBorder: outline(c.border),
      labelStyle: AppText.body.copyWith(color: c.textMuted),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.error)) {
          return AppText.body.copyWith(color: c.danger);
        }
        if (states.contains(WidgetState.focused)) {
          return AppText.body.copyWith(color: c.accent);
        }
        return AppText.body.copyWith(color: c.textMuted);
      }),
      hintStyle: AppText.bodyLg.copyWith(color: c.textMuted),
      helperStyle: AppText.caption.copyWith(color: c.textMuted),
      errorStyle: AppText.caption.copyWith(color: c.danger),
      counterStyle: AppText.caption.copyWith(color: c.textMuted),
      prefixIconColor: c.textMuted,
      suffixIconColor: c.textMuted,
      iconColor: c.textMuted,
    );
  }

  static FilledButtonThemeData filledButton(AppColors c) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.surfaceRaised,
          disabledForegroundColor: c.textMuted,
          elevation: 0,
          minimumSize: const Size(64, Sizes.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: Space.s5),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: AppText.label,
          iconSize: Sizes.iconMd,
        ),
      );

  /// Mientras haya `ElevatedButton` sin migrar, se ven como el primario.
  static ElevatedButtonThemeData elevatedButton(AppColors c) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.surfaceRaised,
          disabledForegroundColor: c.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, Sizes.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: Space.s5),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: AppText.label,
          iconSize: Sizes.iconMd,
        ),
      );

  static OutlinedButtonThemeData outlinedButton(AppColors c) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          disabledForegroundColor: c.textMuted,
          side: BorderSide(color: c.borderStrong, width: 1.5),
          minimumSize: const Size(64, Sizes.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: Space.s5),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: AppText.label,
          iconSize: Sizes.iconMd,
        ),
      );

  static TextButtonThemeData textButton(AppColors c) => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          disabledForegroundColor: c.textMuted,
          minimumSize: const Size(Sizes.touchMin, Sizes.touchMin),
          padding: const EdgeInsets.symmetric(horizontal: Space.s3),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: AppText.label,
          iconSize: Sizes.iconMd,
        ),
      );

  static IconButtonThemeData iconButton(AppColors c) => IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.text,
          disabledForegroundColor: c.textMuted,
          minimumSize: const Size(Sizes.touchMin, Sizes.touchMin),
          iconSize: Sizes.iconLg,
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
        ),
      );

  static FloatingActionButtonThemeData fab(AppColors c) =>
      FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        highlightElevation: 6,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        iconSize: Sizes.iconLg,
        extendedTextStyle: AppText.label,
        extendedPadding: const EdgeInsets.symmetric(horizontal: Space.s4),
        extendedIconLabelSpacing: Space.s2,
      );

  static CardThemeData card(AppColors c) => CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.lgAll,
          side: BorderSide(color: c.border),
        ),
      );

  static DialogThemeData dialog(AppColors c) => DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: c.shadow,
        barrierColor: c.scrim,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
        titleTextStyle: AppText.titleMd.copyWith(color: c.text),
        contentTextStyle: AppText.body.copyWith(color: c.textMuted),
      );

  static BottomSheetThemeData bottomSheet(AppColors c) => BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(borderRadius: Radii.xlTop),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(32, 4),
      );

  static ChipThemeData chip(AppColors c) => ChipThemeData(
        color: _bySelected<Color?>(c.accentSoft, Colors.transparent),
        side: WidgetStateBorderSide.resolveWith((states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? c.accent
                  : c.borderStrong,
            )),
        shape: const StadiumBorder(),
        labelStyle: AppText.label.copyWith(color: c.text),
        secondaryLabelStyle: AppText.label.copyWith(color: c.text),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: Space.s2),
        showCheckmark: false,
        checkmarkColor: c.accent,
        iconTheme: IconThemeData(color: c.textMuted, size: Sizes.iconMd),
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
      );

  static SegmentedButtonThemeData segmentedButton(AppColors c) =>
      SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: _bySelected(c.surface, c.surfaceRaised),
          foregroundColor: _bySelected(c.text, c.textMuted),
          side: WidgetStatePropertyAll(BorderSide(color: c.borderStrong)),
          shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: Radii.mdAll)),
          textStyle: const WidgetStatePropertyAll(AppText.label),
          minimumSize:
              const WidgetStatePropertyAll(Size(Sizes.touchMin, Sizes.touchMin)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: Space.s3)),
          iconSize: const WidgetStatePropertyAll(Sizes.iconMd),
        ),
      );

  static DatePickerThemeData datePicker(AppColors c) {
    final actionStyle = TextButton.styleFrom(
      foregroundColor: c.accent,
      textStyle: AppText.label,
      minimumSize: const Size(Sizes.touchMin, Sizes.touchMin),
    );
    return DatePickerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: c.shadow,
      shape: const RoundedRectangleBorder(borderRadius: Radii.xlAll),
      headerBackgroundColor: c.surface,
      headerForegroundColor: c.text,
      headerHeadlineStyle: AppText.titleLg,
      headerHelpStyle: AppText.overline,
      weekdayStyle: AppText.caption.copyWith(color: c.textMuted),
      dayStyle: AppText.body,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.onAccent;
        if (states.contains(WidgetState.disabled)) return c.textMuted;
        return c.text;
      }),
      dayBackgroundColor: _bySelected<Color?>(c.accent, Colors.transparent),
      todayForegroundColor: _bySelected(c.onAccent, c.accent),
      todayBackgroundColor: _bySelected<Color?>(c.accent, Colors.transparent),
      todayBorder: BorderSide(color: c.accent),
      yearStyle: AppText.bodyLg,
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return c.onAccent;
        if (states.contains(WidgetState.disabled)) return c.textMuted;
        return c.text;
      }),
      yearBackgroundColor: _bySelected<Color?>(c.accent, Colors.transparent),
      dividerColor: c.border,
      cancelButtonStyle: actionStyle,
      confirmButtonStyle: actionStyle,
    );
  }

  static SnackBarThemeData snackBar(AppColors c) => SnackBarThemeData(
        backgroundColor: c.surfaceRaised,
        contentTextStyle: AppText.body.copyWith(color: c.text),
        actionTextColor: c.accent,
        closeIconColor: c.textMuted,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: c.borderStrong),
        ),
      );

  static DividerThemeData divider(AppColors c) =>
      DividerThemeData(color: c.border, thickness: 1, space: 1);

  static ListTileThemeData listTile(AppColors c) =>
      ListTileThemeData(iconColor: c.textMuted, textColor: c.text);

  static CheckboxThemeData checkbox(AppColors c) => CheckboxThemeData(
        fillColor: _bySelected<Color?>(c.accent, Colors.transparent),
        checkColor: WidgetStatePropertyAll(c.onAccent),
        side: WidgetStateBorderSide.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? BorderSide(color: c.accent, width: 2)
                : BorderSide(color: c.borderStrong, width: 2)),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4))),
      );

  static RadioThemeData radio(AppColors c) =>
      RadioThemeData(fillColor: _bySelected(c.accent, c.borderStrong));

  static SwitchThemeData switchTheme(AppColors c) => SwitchThemeData(
        thumbColor: _bySelected(c.onAccent, c.textMuted),
        trackColor: _bySelected(c.accent, c.surfaceRaised),
        trackOutlineColor: _bySelected(Colors.transparent, c.borderStrong),
      );

  static ProgressIndicatorThemeData progressIndicator(AppColors c) =>
      ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceRaised,
        circularTrackColor: Colors.transparent,
      );

  static PopupMenuThemeData popupMenu(AppColors c) => PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: c.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: c.border),
        ),
        textStyle: AppText.body.copyWith(color: c.text),
      );

  static TooltipThemeData tooltip(AppColors c) => TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: Radii.smAll,
          border: Border.all(color: c.borderStrong),
        ),
        textStyle: AppText.caption.copyWith(color: c.text),
        padding: const EdgeInsets.symmetric(
            horizontal: Space.s2, vertical: Space.s1),
      );

  static TextSelectionThemeData textSelection(AppColors c) =>
      TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accentSoft,
        selectionHandleColor: c.accent,
      );
}
