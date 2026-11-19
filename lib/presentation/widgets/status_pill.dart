import 'package:flutter/material.dart';

import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/expiry_status.dart';
import 'status_styles.dart';

/// Estado comunicado con ícono + palabra + color; nunca con color solo.
class StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Tone tone;

  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.tone = Tone.neutral,
  });

  StatusPill.vehicle(VehicleStatus status, {Key? key})
    : this(
        key: key,
        label: status.label,
        icon: status.statusIcon,
        tone: status.tone,
      );

  /// Vencimiento de VTV o seguro: "Vigente", "Vence en N días", "Vencido…".
  factory StatusPill.expiry(DateTime? expiry, {Key? key}) {
    final status = ExpiryStatus.of(expiry);
    return StatusPill(
      key: key,
      label: status.label,
      icon: status.icon,
      tone: status.tone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = tone.foreground(c);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.only(left: Space.s2, right: 10),
      decoration: BoxDecoration(
        color: tone.background(c),
        borderRadius: Radii.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.iconSm, color: foreground),
          const Gap(Space.s1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
