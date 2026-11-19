part of '../vehicle_form_screen.dart';

/// Nombre y teléfono del responsable, con la opción de traerlos de un
/// contacto del teléfono.
class _ResponsibleSection extends StatelessWidget {
  final VehicleFormData data;

  const _ResponsibleSection({required this.data});

  Future<void> _importContact(BuildContext context) async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (context.mounted) {
        AppSnack.error(context,
            'Para importar un contacto, permití el acceso a los contactos.');
      }
      return;
    }
    final picked = await FlutterContacts.openExternalPick();
    if (picked == null) return;
    final contact = await FlutterContacts.getContact(
      picked.id,
      withProperties: true,
      withPhoto: false,
    );
    if (contact == null || !context.mounted) return;

    data.responsibleName.text = contact.displayName;
    if (contact.phones.isNotEmpty) {
      data.responsiblePhone.text =
          contact.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '');
    }
    AppSnack.success(context, 'Contacto importado: ${contact.displayName}');
  }

  @override
  Widget build(BuildContext context) {
    // El selector de contactos solo existe en el teléfono.
    final canImport = !kIsWeb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Responsable',
          actionLabel: canImport ? 'Importar contacto' : null,
          actionIcon: Icons.contacts_rounded,
          onAction: canImport ? () => _importContact(context) : null,
        ),
        const Gap(Space.s2),
        AppTextField(
          label: 'Nombre',
          required: true,
          controller: data.responsibleName,
          hint: 'Nombre y apellido',
          icon: Icons.person_rounded,
          textCapitalization: TextCapitalization.words,
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresá el nombre del responsable'
              : null,
        ),
        const Gap(Space.s4),
        AppTextField(
          label: 'Teléfono',
          required: true,
          controller: data.responsiblePhone,
          hint: 'Ej: 1155667788',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Ingresá el teléfono del responsable'
              : null,
        ),
      ],
    );
  }
}
