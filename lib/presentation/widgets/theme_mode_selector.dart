import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_mode_provider.dart';

/// Control segmentado para elegir el tema de la app: Sistema, Claro u Oscuro.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('Sistema'),
            icon: Icon(Icons.brightness_auto_rounded),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('Claro'),
            icon: Icon(Icons.light_mode_rounded),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('Oscuro'),
            icon: Icon(Icons.dark_mode_rounded),
          ),
        ],
        selected: {themeMode},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            ref.read(themeModeProvider.notifier).select(selection.first),
      ),
    );
  }
}
