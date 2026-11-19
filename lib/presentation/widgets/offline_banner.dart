import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../providers/connectivity_provider.dart';

/// Envuelve la app entera (MaterialApp.builder) y, sin conexión, muestra la
/// barra de aviso debajo de la barra de estado. Ocupa lugar: empuja el
/// contenido hacia abajo en vez de taparlo. Es el único indicador offline.
class OfflineBanner extends ConsumerWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mientras resuelve se asume conexión, para no parpadear el banner.
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;

    // La estructura no cambia con la conexión (y la app va con key): así el
    // Navigator conserva su pila al aparecer o irse el banner.
    return Column(
      children: [
        if (!online) const _OfflineBar(),
        Expanded(
          key: const ValueKey('app'),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: !online,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.warningSoft,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s5,
            vertical: Space.s2,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: Sizes.iconSm,
                color: c.warning,
              ),
              const Gap(Space.s2),
              Expanded(
                child: Text(
                  'Sin conexión. Los cambios se guardan y se sincronizan al volver.',
                  style: AppText.caption.copyWith(color: c.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
