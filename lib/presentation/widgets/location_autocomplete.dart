import 'package:flutter/material.dart';

/// A generic autocomplete widget for location selection.
/// Used as base for city and lugar autocomplete fields.
class LocationAutocomplete<T> extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
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
    required this.labelText,
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

  void _filterSuggestions() {
    final query = widget.controller.text.toLowerCase();
    if (query.isEmpty) {
      _filteredSuggestions = widget.suggestions;
    } else {
      _filteredSuggestions = widget.suggestions.where((item) {
        final displayString = widget.displayStringForOption(item).toLowerCase();
        return displayString.contains(query);
      }).toList();
    }

    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredSuggestions.length,
                itemBuilder: (context, index) {
                  final item = _filteredSuggestions[index];
                  final displayString = widget.displayStringForOption(item);
                  return ListTile(
                    dense: true,
                    title: Text(displayString),
                    onTap: () {
                      widget.controller.text = displayString;
                      widget.onSelected?.call(item);
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                  );
                },
              ),
            ),
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: Icon(widget.prefixIcon),
          suffixIcon: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.showCheckmark
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
          border: const OutlineInputBorder(),
        ),
        validator: widget.validator,
      ),
    );
  }
}
