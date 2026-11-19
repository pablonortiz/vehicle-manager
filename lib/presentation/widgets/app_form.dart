import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Form que valida en vivo recién después del primer intento de guardar (antes
/// no marca errores mientras se escribe) y que, si algo falla, lleva la vista
/// al primer campo con error.
class AppForm extends StatefulWidget {
  final Widget child;

  const AppForm({super.key, required this.child});

  @override
  State<AppForm> createState() => AppFormState();
}

class AppFormState extends State<AppForm> {
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  /// Valida todos los campos montados. Si alguno falla, desde ahí los errores
  /// se actualizan mientras se corrige, y la vista va al de más arriba.
  bool validateAndReveal() {
    final invalidFields = _formKey.currentState!.validateGranularly();
    if (invalidFields.isEmpty) return true;
    if (!_submitted) setState(() => _submitted = true);
    final topmost = invalidFields.reduce(
        (field, other) => _topOf(field) <= _topOf(other) ? field : other);
    Scrollable.ensureVisible(
      topmost.context,
      duration: Motion.medium,
      alignment: 0.2,
    );
    return false;
  }

  static double _topOf(FormFieldState<Object?> field) {
    final box = field.context.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero).dy ?? double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: widget.child,
    );
  }
}
