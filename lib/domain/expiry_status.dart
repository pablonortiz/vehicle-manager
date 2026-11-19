enum ExpiryState { valid, expiringSoon, expired, unknown }

/// Situación de un vencimiento (VTV, seguro) respecto de hoy, por días de
/// calendario. Vence "pasada la fecha": el mismo día todavía está vigente.
class ExpiryStatus {
  /// Ventana de aviso: con esta cantidad de días o menos, "por vencer".
  static const warningDays = 30;

  final ExpiryState state;

  /// Días hasta la fecha; negativo si ya pasó. 0 si no hay fecha.
  final int days;

  const ExpiryStatus._(this.state, this.days);

  factory ExpiryStatus.of(DateTime? expiry, {DateTime? today}) {
    if (expiry == null) return const ExpiryStatus._(ExpiryState.unknown, 0);
    final now = today ?? DateTime.now();
    final days = DateTime.utc(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    final state = days < 0
        ? ExpiryState.expired
        : days <= warningDays
        ? ExpiryState.expiringSoon
        : ExpiryState.valid;
    return ExpiryStatus._(state, days);
  }

  bool get isExpired => state == ExpiryState.expired;
  bool get isExpiringSoon => state == ExpiryState.expiringSoon;

  /// Vencido o por vencer: pide atención.
  bool get needsAttention => isExpired || isExpiringSoon;

  /// Texto del pill: "Vigente", "Vence en 5 días", "Vencido hace 3 días".
  String get label {
    switch (state) {
      case ExpiryState.valid:
        return 'Vigente';
      case ExpiryState.expiringSoon:
        if (days == 0) return 'Vence hoy';
        return days == 1 ? 'Vence mañana' : 'Vence en $days días';
      case ExpiryState.expired:
        final ago = -days;
        return ago == 1 ? 'Vencido hace 1 día' : 'Vencido hace $ago días';
      case ExpiryState.unknown:
        return 'Sin fecha';
    }
  }

  /// Frase verbal para anteponerle el documento: "VTV venció hace 3 días",
  /// "Seguro vence en 5 días". El verbo evita la concordancia de género.
  String get phrase {
    switch (state) {
      case ExpiryState.valid:
        return 'vigente';
      case ExpiryState.expiringSoon:
        if (days == 0) return 'vence hoy';
        return days == 1 ? 'vence mañana' : 'vence en $days días';
      case ExpiryState.expired:
        final ago = -days;
        return ago == 1 ? 'venció ayer' : 'venció hace $ago días';
      case ExpiryState.unknown:
        return 'sin fecha';
    }
  }
}
