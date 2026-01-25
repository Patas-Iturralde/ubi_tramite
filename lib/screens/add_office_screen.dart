import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/office_location.dart';
import '../providers/offices_provider.dart';
import '../providers/location_provider.dart';
import 'location_picker_screen.dart';

/// Pantalla para agregar una nueva oficina personalizada
class AddOfficeScreen extends ConsumerStatefulWidget {
  const AddOfficeScreen({super.key});

  @override
  ConsumerState<AddOfficeScreen> createState() => _AddOfficeScreenState();
}

class _AddOfficeScreenState extends ConsumerState<AddOfficeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _tramiteController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  double? _selectedLatitude;
  double? _selectedLongitude;
  final List<String> _tramites = [];
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _scheduleController.dispose();
    _tramiteController.dispose();
    super.dispose();
  }

  void _addTramite() {
    final tramite = _tramiteController.text.trim();
    if (tramite.isNotEmpty && !_tramites.contains(tramite)) {
      setState(() {
        _tramites.add(tramite);
        _tramiteController.clear();
      });
    }
  }

  void _removeTramite(int index) {
    setState(() {
      _tramites.removeAt(index);
    });
  }

  /// Obtiene la ubicación actual del usuario
  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);
      
      final locationNotifier = ref.read(locationProvider.notifier);
      final position = await locationNotifier.getCurrentPosition();
      
      if (position != null) {
        setState(() {
          _selectedLatitude = position.latitude;
          _selectedLongitude = position.longitude;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ubicación actual obtenida'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener la ubicación actual'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al obtener ubicación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Abre el selector de ubicación en el mapa
  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
      });
    }
  }

  Future<void> _pickSchedule() async {
    final now = TimeOfDay.now();
    final start = await showTimePicker(
      context: context,
      initialTime: _startTime ?? now,
      helpText: 'Selecciona hora de inicio',
    );
    if (start == null) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _endTime ?? start.replacing(hour: (start.hour + 1) % 24),
      helpText: 'Selecciona hora de fin',
    );
    if (end == null) return;
    setState(() {
      _startTime = start;
      _endTime = end;
      final startStr = start.format(context);
      final endStr = end.format(context);
      _scheduleController.text = '$startStr - $endStr';
    });
  }

  /// Guarda la nueva oficina
  Future<void> _saveOffice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una ubicación'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final office = OfficeLocation(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        schedule: _scheduleController.text.trim(),
        latitude: _selectedLatitude!,
        longitude: _selectedLongitude!,
        tramites: List.from(_tramites),
      );

      final officesNotifier = ref.read(officesProvider.notifier);
      final success = await officesNotifier.addCustomOffice(office);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oficina agregada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar la oficina'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Oficina'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título
                    const Text(
                      'Nueva Oficina Gubernamental',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Nombre de la oficina
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la oficina *',
                        hintText: 'Ej: Ministerio de Salud',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción *',
                        hintText: 'Ej: Oficina principal del ministerio',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La descripción es obligatoria';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Trámites
                    const Text(
                      'Trámites disponibles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tramiteController,
                            decoration: const InputDecoration(
                              labelText: 'Agregar trámite',
                              hintText: 'Ej: Sacar pasaporte',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            onFieldSubmitted: (_) => _addTramite(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _addTramite,
                          icon: const Icon(Icons.add_circle),
                          color: Colors.green,
                          iconSize: 40,
                          tooltip: 'Agregar trámite',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_tramites.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _tramites.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              dense: true,
                              title: Text(_tramites[index]),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeTramite(index),
                                tooltip: 'Eliminar trámite',
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Horario de atención
                    TextFormField(
                      controller: _scheduleController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Horario de atención *',
                        hintText: 'Selecciona el horario',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.access_time),
                        suffixIcon: IconButton(
                          tooltip: 'Elegir horario',
                          icon: const Icon(Icons.schedule),
                          onPressed: _pickSchedule,
                        ),
                      ),
                      onTap: _pickSchedule,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El horario es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Selección de ubicación
                    const Text(
                      'Ubicación de la oficina',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón para seleccionar en el mapa
                    ElevatedButton.icon(
                      onPressed: _selectLocationOnMap,
                      icon: const Icon(Icons.map),
                      label: const Text('Seleccionar en el mapa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón para obtener ubicación actual
                    ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Usar mi ubicación actual'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mostrar ubicación seleccionada
                    if (_selectedLatitude != null && _selectedLongitude != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ubicación seleccionada:\n${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 24),

                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveOffice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
