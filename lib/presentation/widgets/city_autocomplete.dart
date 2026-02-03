import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/city.dart';
import '../../core/utils/text_normalizer.dart';
import '../providers/location_provider.dart';
import 'location_autocomplete.dart';

/// City autocomplete widget that integrates with the location provider.
/// Auto-creates new cities when the user enters a name not in the suggestions.
class CityAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final int provinceId;
  final String? initialCityId;
  final void Function(City city)? onCitySelected;
  final void Function(String cityName)? onCityTextChanged;
  final bool enabled;
  final String? Function(String?)? validator;

  const CityAutocomplete({
    super.key,
    required this.controller,
    required this.provinceId,
    this.initialCityId,
    this.onCitySelected,
    this.onCityTextChanged,
    this.enabled = true,
    this.validator,
  });

  @override
  ConsumerState<CityAutocomplete> createState() => CityAutocompleteState();
}

class CityAutocompleteState extends ConsumerState<CityAutocomplete> {
  City? _selectedCity;
  bool _matchesExisting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_checkMatch);

    // Load initial city if provided
    if (widget.initialCityId != null) {
      _loadInitialCity();
    }
  }

  Future<void> _loadInitialCity() async {
    final cityAsync = await ref.read(cityByIdProvider(widget.initialCityId!).future);
    if (cityAsync != null && mounted) {
      setState(() {
        _selectedCity = cityAsync;
        _matchesExisting = true;
      });
    }
  }

  void _checkMatch() {
    final citiesAsync = ref.read(citiesByProvinceProvider(widget.provinceId));
    citiesAsync.whenData((cities) {
      final currentText = widget.controller.text;
      final normalizedInput = TextNormalizer.normalize(currentText);

      final matchingCity = cities.cast<City?>().firstWhere(
        (city) => city!.nameNormalized == normalizedInput,
        orElse: () => null,
      );

      if (mounted) {
        setState(() {
          _matchesExisting = matchingCity != null;
          if (matchingCity != null) {
            _selectedCity = matchingCity;
          }
        });
      }
    });

    widget.onCityTextChanged?.call(widget.controller.text);
  }

  void _onCitySelected(City city) {
    setState(() {
      _selectedCity = city;
      _matchesExisting = true;
    });
    widget.onCitySelected?.call(city);
  }

  @override
  Widget build(BuildContext context) {
    final citiesAsync = ref.watch(citiesByProvinceProvider(widget.provinceId));

    return citiesAsync.when(
      loading: () => LocationAutocomplete<City>(
        controller: widget.controller,
        labelText: 'Ciudad *',
        prefixIcon: Icons.location_city,
        suggestions: const [],
        displayStringForOption: (city) => city.name,
        enabled: widget.enabled,
        validator: widget.validator,
        isLoading: true,
      ),
      error: (error, stack) => LocationAutocomplete<City>(
        controller: widget.controller,
        labelText: 'Ciudad *',
        prefixIcon: Icons.location_city,
        suggestions: const [],
        displayStringForOption: (city) => city.name,
        enabled: widget.enabled,
        validator: widget.validator,
      ),
      data: (cities) => LocationAutocomplete<City>(
        controller: widget.controller,
        labelText: 'Ciudad *',
        prefixIcon: Icons.location_city,
        suggestions: cities,
        displayStringForOption: (city) => city.name,
        onSelected: _onCitySelected,
        onChanged: (text) => widget.onCityTextChanged?.call(text),
        enabled: widget.enabled,
        validator: widget.validator,
        showCheckmark: _matchesExisting,
      ),
    );
  }

  /// Gets the selected city or creates a new one based on text input.
  /// Call this when saving the form.
  Future<City?> getOrCreateCity() async {
    if (_selectedCity != null && _matchesExisting) {
      return _selectedCity;
    }

    final text = widget.controller.text.trim();
    if (text.isEmpty) return null;

    final repository = ref.read(locationRepositoryProvider);
    return await repository.getOrCreateCity(widget.provinceId, text);
  }

  /// Returns the currently selected city (may be null if text doesn't match)
  City? get selectedCity => _matchesExisting ? _selectedCity : null;

  /// Returns whether the current text matches an existing city
  bool get hasMatchingCity => _matchesExisting;
}
