part of '../vehicle_form_screen.dart';

/// VTV y seguro: fechas opcionales, con "Quitar fecha" cuando hay una.
class _ExpirySection extends StatelessWidget {
  final VehicleFormData data;
  final VoidCallback onChanged;

  const _ExpirySection({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Vencimientos'),
        const Gap(Space.s2),
        AppDateField(
          label: 'Vencimiento de la VTV',
          value: data.vtvExpiry,
          onChanged: (date) {
            data.vtvExpiry = date;
            onChanged();
          },
          onCleared: () {
            data.vtvExpiry = null;
            onChanged();
          },
        ),
        const Gap(Space.s4),
        AppTextField(
          label: 'Compañía de seguro',
          controller: data.insuranceCompany,
          hint: 'Ej: La Segunda',
          icon: Icons.shield_rounded,
          textCapitalization: TextCapitalization.words,
        ),
        const Gap(Space.s4),
        AppDateField(
          label: 'Vencimiento del seguro',
          value: data.insuranceExpiry,
          onChanged: (date) {
            data.insuranceExpiry = date;
            onChanged();
          },
          onCleared: () {
            data.insuranceExpiry = null;
            onChanged();
          },
        ),
      ],
    );
  }
}
