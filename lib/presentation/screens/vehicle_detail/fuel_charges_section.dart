part of '../vehicle_detail_screen.dart';

/// Últimas cargas de combustible, con acceso a la pantalla de cargas. El
/// resumen mensual vive allá: acá "Sin cargas este mes" confundía cuando la
/// última carga era de otro mes.
class _FuelChargesSection extends ConsumerWidget {
  final String vehicleId;

  const _FuelChargesSection({required this.vehicleId});

  void _openCharges(BuildContext context) =>
      context.push('/vehicle/$vehicleId/fuel');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chargesAsync = ref.watch(recentFuelChargesProvider(vehicleId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Cargas de combustible',
          actionLabel: 'Ver todas',
          onAction: () => _openCharges(context),
        ),
        const Gap(Space.s2),
        chargesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => AppNotice.error(
            message: 'No se pudieron cargar las cargas.',
            onRetry: () => ref.invalidate(recentFuelChargesProvider(vehicleId)),
          ),
          data: (charges) => charges.isEmpty
              ? const _EmptyLine('Todavía no hay cargas.')
              : AppCard.list(
                  children: [
                    for (final charge in charges)
                      _RecentChargeRow(
                        charge: charge,
                        onTap: () => _openCharges(context),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecentChargeRow extends StatelessWidget {
  final FuelCharge charge;
  final VoidCallback onTap;

  const _RecentChargeRow({required this.charge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Space.s4, vertical: Space.s2),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: Radii.smAll,
                ),
                child: Icon(Icons.local_gas_station_rounded,
                    size: Sizes.iconMd, color: c.catFuel),
              ),
              const Gap(Space.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppFormats.liters(charge.liters),
                      style: AppText.label.tabular.copyWith(color: c.text),
                    ),
                    Text(
                      AppFormats.date(charge.date),
                      style: AppText.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                AppFormats.money(charge.price),
                style: AppText.label.tabular.copyWith(color: c.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
