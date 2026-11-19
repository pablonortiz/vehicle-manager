import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_tone.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/text_normalizer.dart';
import 'app_text_field.dart';

/// A generic autocomplete widget for location selection.
/// Used as base for city and lugar autocomplete fields.
class LocationAutocomplete<T> extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final IconData prefixIcon;
  final List<T> suggestions;
  final String Function(T) displayStringForOption;
  final void Function(T)? onSelected;
  final void Function(String)? onChanged;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool showCheckmark;
  final bool isLoading;
  final String? hintText;

  const LocationAutocomplete({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
    required this.prefixIcon,
    required this.suggestions,
    required this.displayStringForOption,
    this.onSelected,
    this.onChanged,
    this.enabled = true,
    this.validator,
    this.showCheckmark = false,
    this.isLoading = false,
    this.hintText,
  });

  @override
  State<LocationAutocomplete<T>> createState() => _LocationAutocompleteState<T>();
}

class _LocationAutocompleteState<T> extends State<LocationAutocomplete<T>> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<T> _filteredSuggestions = [];
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    _removeOverlay();
    super.dispose();
  }

  @override
  void didUpdateWidget(LocationAutocomplete<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions != widget.suggestions) {
      _filterSuggestions();
      if (_hasFocus && _filteredSuggestions.isNotEmpty) {
        _showOverlay();
      }
    }
  }

  void _onFocusChange() {
    _hasFocus = _focusNode.hasFocus;
    if (_hasFocus) {
      _revealRoomForSuggestions();
      _filterSuggestions();
      if (_filteredSuggestions.isNotEmpty) {
        _showOverlay();
      }
    } else {
      _removeOverlay();
    }
  }

  void _onTextChange() {
    _filterSuggestions();
    widget.onChanged?.call(widget.controller.text);

    if (_hasFocus && _filteredSuggestions.isNotEmpty) {
      _showOverlay();
    } else if (_filteredSuggestions.isEmpty) {
      _removeOverlay();
    }
  }

  /// Sube el campo hacia arriba de la vista: la lista se abre debajo y, si
  /// el campo queda pegado al teclado, la tapa. Corre cuando el teclado ya
  /// abrió: antes, el scroll que hace el campo para mostrar el cursor lo pisa.
  void _revealRoomForSuggestions() {
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || !_focusNode.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.1,
        duration: Motion.of(context, Motion.medium),
      );
    });
  }

  /// Sin distinguir mayúsculas ni acentos: "rio" encuentra "Río Cuarto".
  void _filterSuggestions() {
    final query = TextNormalizer.normalize(widget.controller.text.trim());
    if (query.isEmpty) {
      _filteredSuggestions = widget.suggestions;
    } else {
      _filteredSuggestions = widget.suggestions
          .where((item) => TextNormalizer.normalize(
                  widget.displayStringForOption(item))
              .contains(query))
          .toList();
    }

    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    // El campo, sin el label de arriba: la lista se abre pegada a él.
    final renderBox = _fieldKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + Space.s1),
          child: _SuggestionsPanel(
            itemCount: _filteredSuggestions.length,
            labelOf: (index) =>
                widget.displayStringForOption(_filteredSuggestions[index]),
            onTap: (index) {
              final item = _filteredSuggestions[index];
              widget.controller.text = widget.displayStringForOption(item);
              widget.onSelected?.call(item);
              _removeOverlay();
              _focusNode.unfocus();
            },
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(widget.label, required: widget.required),
        const Gap(Space.s2),
        CompositedTransformTarget(
          key: _fieldKey,
          link: _layerLink,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            // Ya enfocado (teclado cerrado con "atrás"), tocar lo reabre.
            onTap: _revealRoomForSuggestions,
            textCapitalization: TextCapitalization.words,
            style: AppText.bodyLg.copyWith(color: c.text),
            errorBuilder: (context, error) =>
                FieldMessage(error, tone: Tone.danger),
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(widget.prefixIcon, size: Sizes.iconMd),
              suffixIcon: widget.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(Space.s3),
                      child: SizedBox.square(
                        dimension: Sizes.iconMd,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : widget.showCheckmark
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: Sizes.iconMd,
                          color: c.success,
                          semanticLabel: 'Ya está cargado',
                        )
                      : null,
            ),
            validator: widget.validator,
          ),
        ),
      ],
    );
  }
}

/// Lista de sugerencias flotante: `surface-raised` con la sombra de overlay.
class _SuggestionsPanel extends StatelessWidget {
  final int itemCount;
  final String Function(int index) labelOf;
  final ValueChanged<int> onTap;

  const _SuggestionsPanel({
    required this.itemCount,
    required this.labelOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.mdAll,
        boxShadow: c.overlayShadow,
      ),
      child: Material(
        color: c.surfaceRaised,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.mdAll,
          side: BorderSide(color: c.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: Space.s1),
            shrinkWrap: true,
            itemCount: itemCount,
            itemBuilder: (context, index) => InkWell(
              onTap: () => onTap(index),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.touchMin),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Space.s4, vertical: Space.s3),
                  child: Text(
                    labelOf(index),
                    style: AppText.body.copyWith(color: c.text),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
