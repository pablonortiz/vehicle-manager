import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/vehicle_icon.dart';
import '../widgets/city_autocomplete.dart';
import '../widgets/lugar_autocomplete.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  final String? vehicleId;

  const VehicleFormScreen({super.key, this.vehicleId});

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cityAutocompleteKey = GlobalKey<CityAutocompleteState>();
  final _lugarAutocompleteKey = GlobalKey<LugarAutocompleteState>();

  late TextEditingController _plateController;
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _kmController;
  late TextEditingController _insuranceCompanyController;
  late TextEditingController _cityController;
  late TextEditingController _lugarController;
  late TextEditingController _responsibleNameController;
  late TextEditingController _responsiblePhoneController;

  VehicleType _selectedType = VehicleType.car;
  Color _selectedColor = VehicleColors.options.first.color;
  FuelType _selectedFuelType = FuelType.nafta;
  VehicleStatus _selectedStatus = VehicleStatus.available;
  int _selectedProvinceId = 1;
  String? _selectedCityId;
  String? _selectedLugarId;
  DateTime? _vtvExpiry;
  DateTime? _insuranceExpiry;

  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _plateController = TextEditingController();
    _brandController = TextEditingController();
    _modelController = TextEditingController();
    _yearController = TextEditingController(text: DateTime.now().year.toString());
    _kmController = TextEditingController(text: '0');
    _insuranceCompanyController = TextEditingController();
    _cityController = TextEditingController();
    _lugarController = TextEditingController();
    _responsibleNameController = TextEditingController();
    _responsiblePhoneController = TextEditingController();

    _plateController.addListener(() {
      setState(() {});
    });

    if (widget.vehicleId != null) {
      _isEditing = true;
      _loadVehicle();
    }
  }

  Future<void> _loadVehicle() async {
    final vehicle = await ref.read(vehicleByIdProvider(widget.vehicleId!).future);
    if (vehicle != null) {
      setState(() {
        _plateController.text = vehicle.plate;
        _brandController.text = vehicle.brand;
        _modelController.text = vehicle.model;
        _yearController.text = vehicle.year.toString();
        _kmController.text = vehicle.km.toString();
        _insuranceCompanyController.text = vehicle.insuranceCompany ?? '';
        _cityController.text = vehicle.city;
        _lugarController.text = vehicle.lugar ?? '';
        _responsibleNameController.text = vehicle.responsibleName;
        _responsiblePhoneController.text = vehicle.responsiblePhone;
        _selectedType = vehicle.type;
        _selectedColor = vehicle.color;
        _selectedFuelType = vehicle.fuelType;
        _selectedStatus = vehicle.status;
        _selectedProvinceId = vehicle.provinceId;
        _selectedCityId = vehicle.cityId;
        _selectedLugarId = vehicle.lugarId;
        _vtvExpiry = vehicle.vtvExpiry;
        _insuranceExpiry = vehicle.insuranceExpiry;
      });
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _kmController.dispose();
    _insuranceCompanyController.dispose();
    _cityController.dispose();
    _lugarController.dispose();
    _responsibleNameController.dispose();
    _responsiblePhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    // Solicitar permiso
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se necesita permiso para acceder a los contactos'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }

    // Abrir selector de contactos
    final contact = await FlutterContacts.openExternalPick();
    
    if (contact == null) return;

    // Obtener detalles completos del contacto
    final fullContact = await FlutterContacts.getContact(
      contact.id,
      withProperties: true,
      withPhoto: false,
    );

    if (fullContact == null) return;

    setState(() {
      // Nombre
      _responsibleNameController.text = fullContact.displayName;

      // Teléfono - usar el primero disponible
      if (fullContact.phones.isNotEmpty) {
        String phone = fullContact.phones.first.number;
        // Limpiar el número (remover espacios, guiones, etc.)
        phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
        _responsiblePhoneController.text = phone;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contacto importado: ${fullContact.displayName}'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header sticky con icono del vehículo
              _StickyVehicleHeader(
                type: _selectedType,
                color: _selectedColor,
                status: _selectedStatus,
                title: _isEditing ? 'Editar Vehículo' : 'Nuevo Vehículo',
                plate: _plateController.text.isNotEmpty 
                    ? _plateController.text.toUpperCase() 
                    : null,
                onClose: () => context.pop(),
              ),
              
              // Contenido scrolleable
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Tipo de vehículo
                    _SectionLabel(label: 'Tipo de Vehículo'),
                    const SizedBox(height: 12),
                    VehicleTypeSelector(
                      selectedType: _selectedType,
                      vehicleColor: _selectedColor,
                      onSelected: (type) => setState(() => _selectedType = type),
                    ),
                    const SizedBox(height: 24),

                    // Color
                    _SectionLabel(label: 'Color'),
                    const SizedBox(height: 12),
                    VehicleColorSelector(
                      selectedColor: _selectedColor,
                      onSelected: (color) => setState(() => _selectedColor = color),
                    ),
                    const SizedBox(height: 24),

                    // Patente
                    _SectionLabel(label: 'Patente *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _plateController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Ej: AA123BB',
                        prefixIcon: Icon(Icons.confirmation_number),
                      ),
                      inputFormatters: [
                        UpperCaseTextFormatter(),
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresá la patente';
                        }
                        if (value.length < 6) {
                          return 'La patente debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Marca y Modelo
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel(label: 'Marca *'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _brandController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Ej: Toyota',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Requerido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel(label: 'Modelo *'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _modelController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  hintText: 'Ej: Hilux',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Requerido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Año y Kilometraje
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel(label: 'Año *'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _yearController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '2024',
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Requerido';
                                  }
                                  final year = int.tryParse(value);
                                  if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                                    return 'Año inválido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionLabel(label: 'Kilometraje'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _kmController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  suffixText: 'km',
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Combustible
                    _SectionLabel(label: 'Combustible'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<FuelType>(
                      value: _selectedFuelType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.local_gas_station),
                      ),
                      items: FuelType.values.map((fuel) {
                        return DropdownMenuItem(
                          value: fuel,
                          child: Row(
                            children: [
                              Icon(fuel.icon, size: 18, color: AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Text(fuel.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedFuelType = value);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Estado
                    _SectionLabel(label: 'Estado'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<VehicleStatus>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      items: VehicleStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: status.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(status.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedStatus = value);
                      },
                    ),
                    const SizedBox(height: 24),

                    const Divider(),
                    const SizedBox(height: 24),

                    // Ubicación
                    _SectionLabel(label: 'Ubicación'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedProvinceId,
                      decoration: const InputDecoration(
                        labelText: 'Provincia *',
                        prefixIcon: Icon(Icons.map),
                      ),
                      items: ArgentinaProvinces.all.map((province) {
                        return DropdownMenuItem(
                          value: province.id,
                          child: Text(province.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedProvinceId = value;
                            // Clear city and lugar when province changes
                            _cityController.clear();
                            _lugarController.clear();
                            _selectedCityId = null;
                            _selectedLugarId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CityAutocomplete(
                      key: _cityAutocompleteKey,
                      controller: _cityController,
                      provinceId: _selectedProvinceId,
                      initialCityId: _selectedCityId,
                      onCitySelected: (city) {
                        setState(() {
                          _selectedCityId = city.id;
                          // Clear lugar when city changes
                          _lugarController.clear();
                          _selectedLugarId = null;
                        });
                      },
                      onCityTextChanged: (text) {
                        // If user types something different, clear the selection
                        if (_selectedCityId != null) {
                          final cityAutocomplete = _cityAutocompleteKey.currentState;
                          if (cityAutocomplete != null && !cityAutocomplete.hasMatchingCity) {
                            setState(() {
                              _selectedCityId = null;
                              _lugarController.clear();
                              _selectedLugarId = null;
                            });
                          }
                        } else {
                          // Rebuild so LugarAutocomplete gets the updated pendingCityText
                          setState(() {});
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresá la ciudad';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    LugarAutocomplete(
                      key: _lugarAutocompleteKey,
                      controller: _lugarController,
                      cityId: _selectedCityId,
                      initialLugarId: _selectedLugarId,
                      // Pass city text when creating new city (cityId is null but text is entered)
                      pendingCityText: _selectedCityId == null ? _cityController.text : null,
                      onLugarSelected: (lugar) {
                        setState(() {
                          _selectedLugarId = lugar.id;
                        });
                      },
                      onLugarTextChanged: (text) {
                        if (_selectedLugarId != null) {
                          final lugarAutocomplete = _lugarAutocompleteKey.currentState;
                          if (lugarAutocomplete != null && !lugarAutocomplete.hasMatchingLugar) {
                            setState(() {
                              _selectedLugarId = null;
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    const Divider(),
                    const SizedBox(height: 24),

                    // Responsable
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel(label: 'Responsable'),
                        // El selector de contactos solo está disponible en móvil
                        if (!kIsWeb)
                          TextButton.icon(
                            onPressed: _pickContact,
                            icon: const Icon(Icons.contacts, size: 18),
                            label: const Text('Importar contacto'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _responsibleNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        hintText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresá el nombre del responsable';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _responsiblePhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono *',
                        hintText: 'Ej: 1155667788',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresá el teléfono';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    const Divider(),
                    const SizedBox(height: 24),

                    // Documentación
                    _SectionLabel(label: 'Documentación'),
                    const SizedBox(height: 12),
                    _DatePickerField(
                      label: 'Vencimiento VTV',
                      value: _vtvExpiry,
                      onChanged: (date) => setState(() => _vtvExpiry = date),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _insuranceCompanyController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Compañía de Seguro',
                        hintText: 'Ej: La Segunda',
                        prefixIcon: Icon(Icons.security),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DatePickerField(
                      label: 'Vencimiento Seguro',
                      value: _insuranceExpiry,
                      onChanged: (date) => setState(() => _insuranceExpiry = date),
                    ),
                    const SizedBox(height: 32),

                    // Botón guardar
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveVehicle,
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isEditing ? 'Guardar Cambios' : 'Agregar Vehículo'),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get or create city
      String? cityId = _selectedCityId;
      final cityText = _cityController.text.trim();
      bool createdNewCity = false;
      if (cityText.isNotEmpty && cityId == null) {
        final locationRepo = ref.read(locationRepositoryProvider);
        final city = await locationRepo.getOrCreateCity(_selectedProvinceId, cityText);
        cityId = city.id;
        createdNewCity = true;
      }

      // Get or create lugar (optional)
      String? lugarId = _selectedLugarId;
      final lugarText = _lugarController.text.trim();
      bool createdNewLugar = false;
      if (lugarText.isNotEmpty && lugarId == null && cityId != null) {
        final locationRepo = ref.read(locationRepositoryProvider);
        final lugar = await locationRepo.getOrCreateLugar(cityId, lugarText);
        lugarId = lugar.id;
        createdNewLugar = true;
      }

      // Invalidate location providers if we created new city/lugar
      if (createdNewCity) {
        ref.invalidate(citiesByProvinceProvider(_selectedProvinceId));
        ref.invalidate(vehicleCountByCityProvider(_selectedProvinceId));
      }
      if (createdNewLugar && cityId != null) {
        ref.invalidate(lugaresByCityProvider(cityId));
        ref.invalidate(vehicleCountByLugarProvider(cityId));
      }
      // Always refresh province counts since a new vehicle was added
      ref.invalidate(vehicleCountByProvinceProvider);

      final vehicle = Vehicle(
        id: widget.vehicleId,
        plate: _plateController.text.trim().toUpperCase(),
        type: _selectedType,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        year: int.parse(_yearController.text),
        color: _selectedColor,
        km: int.tryParse(_kmController.text) ?? 0,
        vtvExpiry: _vtvExpiry,
        insuranceCompany: _insuranceCompanyController.text.trim().isEmpty
            ? null
            : _insuranceCompanyController.text.trim(),
        insuranceExpiry: _insuranceExpiry,
        fuelType: _selectedFuelType,
        status: _selectedStatus,
        provinceId: _selectedProvinceId,
        city: cityText,
        cityId: cityId,
        lugarId: lugarId,
        lugar: lugarText.isEmpty ? null : lugarText,
        responsibleName: _responsibleNameController.text.trim(),
        responsiblePhone: _responsiblePhoneController.text.trim(),
      );

      bool success;
      if (_isEditing) {
        success = await ref
            .read(vehicleNotifierProvider.notifier)
            .updateVehicle(vehicle);
      } else {
        final id = await ref
            .read(vehicleNotifierProvider.notifier)
            .addVehicle(vehicle);
        success = id != null;
      }

      setState(() => _isLoading = false);

      if (mounted) {
        if (success) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing
                  ? 'Vehículo actualizado'
                  : 'Vehículo agregado'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al guardar. ¿La patente ya existe?'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppTheme.accentPrimary,
                  surface: AppTheme.surface,
                ),
              ),
              child: child!,
            );
          },
        );
        onChanged(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : null,
        ),
        child: Text(
          value != null ? dateFormat.format(value!) : 'Seleccionar fecha',
          style: TextStyle(
            color: value != null 
                ? AppTheme.textPrimary 
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _StickyVehicleHeader extends StatelessWidget {
  final VehicleType type;
  final Color color;
  final VehicleStatus status;
  final String title;
  final String? plate;
  final VoidCallback onClose;

  const _StickyVehicleHeader({
    required this.type,
    required this.color,
    required this.status,
    required this.title,
    this.plate,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceLight,
            ),
          ),
          const SizedBox(width: 12),
          
          VehicleIcon(
            type: type,
            vehicleColor: color,
            status: status,
            size: 48,
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (plate != null && plate!.isNotEmpty)
                  Text(
                    plate!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.accentPrimary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: status.color.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: 14, color: status.color),
                const SizedBox(width: 4),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: status.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
