import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Aviso al pie de un sheet (ícono + mensaje): anticipa el efecto de la acción
/// o, en tono de advertencia, por qué no se puede continuar.
class SheetNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isWarning;

  const SheetNotice({
    super.key,
    required this.icon,
    required this.message,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWarning
              ? AppTheme.warning.withValues(alpha: 0.5)
              : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isWarning ? AppTheme.warning : AppTheme.accentPrimary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
