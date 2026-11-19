import 'package:flutter/material.dart';

import '../../core/theme/app_tone.dart';
import 'empty_state.dart';

/// Error de carga de una pantalla: "No se pudo…" y "Reintentar", nunca la
/// excepción técnica.
class ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryView({
    super.key,
    this.message = 'No se pudieron cargar los datos',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.error_rounded,
        title: message,
        message: 'Revisá la conexión y probá de nuevo.',
        actionLabel: 'Reintentar',
        onAction: onRetry,
        primaryAction: false,
        tone: Tone.danger,
      ),
    );
  }
}
