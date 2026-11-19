part of '../vehicle_form_screen.dart';

/// Tipo, patente, marca, modelo, año, kilometraje, color, combustible y estado.
class _IdentificationSection extends StatelessWidget {
  final VehicleFormData data;
  final VoidCallback onChanged;

  const _IdentificationSection({required this.data, required this.onChanged});

  static String? _validatePlate(String? value) {
    final plate = value?.trim() ?? '';
    if (plate.isEmpty) return 'Ingresá la patente';
    if (plate.length < 6) return 'Revisá la patente: tiene al menos 6 caracteres';
    return null;
  }

  static String? _validateYear(String? value) {
    final maxYear = DateTime.now().year + 1;
    final year = int.tryParse(value ?? '');
    if (value == null || value.isEmpty) return 'Ingresá el año';
    if (year == null || year < 1900 || year > maxYear) {
      return 'Ingresá un año entre 1900 y $maxYear';
    }
    return null;
  }

  static FormFieldValidator<String> _required(String message) =>
      (value) => (value == null || value.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Identificación'),
        const Gap(Space.s2),
        const FieldLabel('Tipo'),
        const Gap(Space.s2),
        VehicleTypeSelector(
          selected: data.type,
          onSelected: (type) {
            data.type = type;
            onChanged();
          },
        ),
        const Gap(Space.s4),
        AppTextField(
          label: 'Patente',
          required: true,
          controller: data.plate,
          hint: 'AB123CD o ABC123',
          icon: Icons.pin_rounded,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            _UpperCaseFormatter(),
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            LengthLimitingTextInputFormatter(10),
          ],
          validator: _validatePlate,
        ),
        const Gap(Space.s4),
        AppTextField(
          label: 'Marca',
          required: true,
          controller: data.brand,
          hint: 'Ej: Toyota',
          textCapitalization: TextCapitalization.words,
          validator: _required('Ingresá la marca'),
        ),
        const Gap(Space.s4),
        AppTextField(
          label: 'Modelo',
          required: true,
          controller: data.model,
          hint: 'Ej: Hilux SRV 2.8',
          textCapitalization: TextCapitalization.words,
          validator: _required('Ingresá el modelo'),
        ),
        const Gap(Space.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Año',
                required: true,
                controller: data.year,
                hint: '${DateTime.now().year}',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: _validateYear,
              ),
            ),
            const Gap(Space.s3),
            Expanded(
              child: AppTextField(
                label: 'Kilometraje',
                controller: data.km,
                hint: '0',
                suffixText: 'km',
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorFormatter()],
              ),
            ),
          ],
        ),
        const Gap(Space.s4),
        Row(
          children: [
            const Expanded(child: FieldLabel('Color')),
            Text(
              VehicleColors.getByColor(data.paint).name,
              style: AppText.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
        const Gap(Space.s1),
        PaintColorSelector(
          selected: data.paint,
          onSelected: (paint) {
            data.paint = paint;
            onChanged();
          },
        ),
        const Gap(Space.s4),
        AppDropdownField<FuelType>(
          label: 'Combustible',
          initialValue: data.fuelType,
          icon: Icons.local_gas_station_rounded,
          items: [
            for (final fuel in FuelType.values)
              DropdownMenuItem(value: fuel, child: Text(fuel.label)),
          ],
          onChanged: (fuel) {
            data.fuelType = fuel;
            onChanged();
          },
        ),
        const Gap(Space.s4),
        const FieldLabel('Estado'),
        const Gap(Space.s2),
        _StatusChoice(
          selected: data.status,
          onSelected: (status) {
            data.status = status;
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Los cuatro estados a la vista, con el ícono y el tono del pill.
class _StatusChoice extends StatelessWidget {
  final VehicleStatus selected;
  final ValueChanged<VehicleStatus> onSelected;

  const _StatusChoice({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: Space.s2,
      runSpacing: Space.s2,
      children: [
        for (final status in VehicleStatus.values)
          ChoiceChip(
            avatar: Icon(status.statusIcon, color: status.tone.foreground(c)),
            label: Text(status.label),
            selected: status == selected,
            onSelected: (_) => onSelected(status),
          ),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
