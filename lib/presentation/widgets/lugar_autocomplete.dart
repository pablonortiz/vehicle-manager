import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/lugar.dart';
import '../../core/utils/text_normalizer.dart';
import '../providers/location_provider.dart';
import 'location_autocomplete.dart';

/// Lugar autocomplete widget that integrates with the location provider.
/// Auto-creates new lugares when the user enters a name not in the suggestions.
/// Enabled when a city is selected OR when pendingCityText is provided (for new cities).
class LugarAutocomplete extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String? cityId;
  final String? initialLugarId;
  final void Function(Lugar lugar)? onLugarSelected;
  final void Function(String lugarName)? onLugarTextChanged;
  final bool enabled;
  final String? Function(String?)? validator;
  /// When creating a new city, pass the city text here to enable the lugar field
  final String? pendingCityText;

  const LugarAutocomplete({
    super.key,
    required this.controller,
    this.cityId,
    this.initialLugarId,
    this.onLugarSelected,
    this.onLugarTextChanged,
    this.enabled = true,
    this.validator,
    this.pendingCityText,
  });

  @override
  ConsumerState<LugarAutocomplete> createState() => LugarAutocompleteState();
}

class LugarAutocompleteState extends ConsumerState<LugarAutocomplete> {
  Lugar? _selectedLugar;
  bool _matchesExisting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_checkMatch);

    // Load initial lugar if provided
    if (widget.initialLugarId != null) {
      _loadInitialLugar();
    }
  }

  @override
  void didUpdateWidget(LugarAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If city changed, clear the selection
    if (oldWidget.cityId != widget.cityId) {
      setState(() {
        _selectedLugar = null;
        _matchesExisting = false;
      });
    }
  }

  Future<void> _loadInitialLugar() async {
    final lugarAsync = await ref.read(lugarByIdProvider(widget.initialLugarId!).future);
    if (lugarAsync != null && mounted) {
      setState(() {
        _selectedLugar = lugarAsync;
        _matchesExisting = true;
      });
    }
  }

  void _checkMatch() {
    if (widget.cityId == null) {
      setState(() {
        _matchesExisting = false;
        _selectedLugar = null;
      });
      return;
    }

    final lugaresAsync = ref.read(lugaresByCityProvider(widget.cityId!));
    lugaresAsync.whenData((lugares) {
      final currentText = widget.controller.text;
      final normalizedInput = TextNormalizer.normalize(currentText);

      final matchingLugar = lugares.cast<Lugar?>().firstWhere(
        (lugar) => lugar!.nameNormalized == normalizedInput,
        orElse: () => null,
      );

      if (mounted) {
        setState(() {
          _matchesExisting = matchingLugar != null;
          if (matchingLugar != null) {
            _selectedLugar = matchingLugar;
          }
        });
      }
    });

    widget.onLugarTextChanged?.call(widget.controller.text);
  }

  void _onLugarSelected(Lugar lugar) {
    setState(() {
      _selectedLugar = lugar;
      _matchesExisting = true;
    });
    widget.onLugarSelected?.call(lugar);
  }

  @override
  Widget build(BuildContext context) {
    // Enable if we have a cityId OR if we have pending city text (new city being created)
    final hasPendingCity = widget.pendingCityText != null && widget.pendingCityText!.trim().isNotEmpty;
    final isEnabled = widget.enabled && (widget.cityId != null || hasPendingCity);

    if (widget.cityId == null && !hasPendingCity) {
      return LocationAutocomplete<Lugar>(
        controller: widget.controller,
        labelText: 'Lugar (opcional)',
        prefixIcon: Icons.place,
        suggestions: const [],
        displayStringForOption: (lugar) => lugar.name,
        enabled: false,
        validator: widget.validator,
      );
    }

    // If we have a pending city (new city being created), show empty suggestions
    // The lugar will be created after the city is created
    if (widget.cityId == null && hasPendingCity) {
      return LocationAutocomplete<Lugar>(
        controller: widget.controller,
        labelText: 'Lugar (opcional)',
        prefixIcon: Icons.place,
        suggestions: const [],
        displayStringForOption: (lugar) => lugar.name,
        enabled: isEnabled,
        validator: widget.validator,
        onChanged: (text) => widget.onLugarTextChanged?.call(text),
        showCheckmark: false,
        hintText: 'Nuevo lugar para "${widget.pendingCityText}"',
      );
    }

    final lugaresAsync = ref.watch(lugaresByCityProvider(widget.cityId!));

    return lugaresAsync.when(
      loading: () => LocationAutocomplete<Lugar>(
        controller: widget.controller,
        labelText: 'Lugar (opcional)',
        prefixIcon: Icons.place,
        suggestions: const [],
        displayStringForOption: (lugar) => lugar.name,
        enabled: isEnabled,
        validator: widget.validator,
        isLoading: true,
      ),
      error: (error, stack) => LocationAutocomplete<Lugar>(
        controller: widget.controller,
        labelText: 'Lugar (opcional)',
        prefixIcon: Icons.place,
        suggestions: const [],
        displayStringForOption: (lugar) => lugar.name,
        enabled: isEnabled,
        validator: widget.validator,
      ),
      data: (lugares) => LocationAutocomplete<Lugar>(
        controller: widget.controller,
        labelText: 'Lugar (opcional)',
        prefixIcon: Icons.place,
        suggestions: lugares,
        displayStringForOption: (lugar) => lugar.name,
        onSelected: _onLugarSelected,
        onChanged: (text) => widget.onLugarTextChanged?.call(text),
        enabled: isEnabled,
        validator: widget.validator,
        showCheckmark: _matchesExisting,
      ),
    );
  }

  /// Gets the selected lugar or creates a new one based on text input.
  /// Call this when saving the form.
  Future<Lugar?> getOrCreateLugar() async {
    if (widget.cityId == null) return null;

    final text = widget.controller.text.trim();
    if (text.isEmpty) return null;

    if (_selectedLugar != null && _matchesExisting) {
      return _selectedLugar;
    }

    final repository = ref.read(locationRepositoryProvider);
    return await repository.getOrCreateLugar(widget.cityId!, text);
  }

  /// Returns the currently selected lugar (may be null if text doesn't match or no city)
  Lugar? get selectedLugar => _matchesExisting ? _selectedLugar : null;

  /// Returns whether the current text matches an existing lugar
  bool get hasMatchingLugar => _matchesExisting;
}
