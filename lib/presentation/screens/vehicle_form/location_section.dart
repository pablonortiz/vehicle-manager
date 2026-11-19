part of '../vehicle_form_screen.dart';

/// Provincia, ciudad y lugar. Una ciudad o un lugar que no existen se crean
/// al guardar.
class _LocationSection extends StatelessWidget {
  final VehicleFormData data;
  final GlobalKey<CityAutocompleteState> cityKey;
  final GlobalKey<LugarAutocompleteState> lugarKey;
  final VoidCallback onChanged;

  const _LocationSection({
    required this.data,
    required this.cityKey,
    required this.lugarKey,
    required this.onChanged,
  });

  /// Si el texto ya no coincide con la ciudad elegida, se suelta la selección.
  /// Sin ciudad elegida, el lugar necesita el texto nuevo ("Nuevo lugar
  /// para…").
  void _onCityTextChanged() {
    if (data.cityId == null) {
      onChanged();
      return;
    }
    if (!(cityKey.currentState?.hasMatchingCity ?? true)) {
      data.selectCity(null);
      onChanged();
    }
  }

  void _onLugarTextChanged() {
    if (data.lugarId == null) return;
    if (!(lugarKey.currentState?.hasMatchingLugar ?? true)) {
      data.lugarId = null;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Ubicación'),
        const Gap(Space.s2),
        AppDropdownField<int>(
          label: 'Provincia',
          required: true,
          initialValue: data.provinceId,
          icon: Icons.map_rounded,
          items: [
            for (final province in ArgentinaProvinces.all)
              DropdownMenuItem(value: province.id, child: Text(province.name)),
          ],
          onChanged: (provinceId) {
            data.selectProvince(provinceId);
            onChanged();
          },
        ),
        const Gap(Space.s4),
        CityAutocomplete(
          key: cityKey,
          controller: data.city,
          provinceId: data.provinceId,
          initialCityId: data.cityId,
          onCitySelected: (city) {
            data.selectCity(city.id);
            onChanged();
          },
          onCityTextChanged: (_) => _onCityTextChanged(),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresá la ciudad'
              : null,
        ),
        const Gap(Space.s4),
        LugarAutocomplete(
          key: lugarKey,
          controller: data.lugar,
          cityId: data.cityId,
          initialLugarId: data.lugarId,
          pendingCityText: data.cityId == null ? data.city.text : null,
          onLugarSelected: (lugar) {
            data.lugarId = lugar.id;
            onChanged();
          },
          onLugarTextChanged: (_) => _onLugarTextChanged(),
        ),
      ],
    );
  }
}
