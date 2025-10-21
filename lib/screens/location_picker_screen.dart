import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/location_provider.dart';
import '../config/mapbox_config.dart';

/// Pantalla para seleccionar una ubicación en el mapa
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  MapboxMap? mapboxMap;
  bool _isLoading = true;
  String? _errorMessage;
  double? _selectedLatitude;
  double? _selectedLongitude;

  // Usar configuración centralizada
  static const double _defaultLatitude = MapboxConfig.defaultLatitude;
  static const double _defaultLongitude = MapboxConfig.defaultLongitude;
  static const double _defaultZoom = MapboxConfig.defaultZoom;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Inicializa el mapa
  Future<void> _initializeMap() async {
    try {
      await _checkLocationPermissions();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al inicializar el mapa: $e';
        _isLoading = false;
      });
    }
  }

  /// Verifica y solicita permisos de ubicación
  Future<void> _checkLocationPermissions() async {
    final status = await Permission.location.status;
    
    if (status.isDenied) {
      final result = await Permission.location.request();
      if (result.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se requieren permisos de ubicación para usar esta función'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  /// Configura el mapa cuando está listo
  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _addSelectionMarker();
    _centerOnUserLocation();
  }

  /// Agrega un marcador de selección en el centro del mapa
  Future<void> _addSelectionMarker() async {
    if (mapboxMap == null) return;

    try {
      // Inicializar con ubicación por defecto
      setState(() {
        _selectedLatitude = _defaultLatitude;
        _selectedLongitude = _defaultLongitude;
      });
      
      debugPrint('Marcador de selección inicializado en: $_selectedLatitude, $_selectedLongitude');
    } catch (e) {
      debugPrint('Error al agregar marcador de selección: $e');
    }
  }

  /// Centra el mapa en la ubicación del usuario
  Future<void> _centerOnUserLocation() async {
    try {
      final locationNotifier = ref.read(locationProvider.notifier);
      final position = await locationNotifier.getCurrentPosition();
      
      if (position != null && mapboxMap != null) {
        await mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(position.longitude, position.latitude)),
            zoom: 15.0,
          ),
          MapAnimationOptions(duration: 2000),
        );
      }
    } catch (e) {
      debugPrint('Error al centrar en ubicación del usuario: $e');
    }
  }

  /// Actualiza la ubicación seleccionada basada en el centro del mapa
  Future<void> _updateSelectedLocation() async {
    if (mapboxMap == null) return;

    try {
      // Obtener el centro actual del mapa
      final cameraState = await mapboxMap!.getCameraState();
      final center = cameraState.center;
      
      setState(() {
        _selectedLatitude = center.coordinates.lat.toDouble();
        _selectedLongitude = center.coordinates.lng.toDouble();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ubicación actualizada: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al actualizar ubicación seleccionada: $e');
    }
  }


  /// Confirma la selección y regresa a la pantalla anterior
  void _confirmSelection() {
    if (_selectedLatitude != null && _selectedLongitude != null) {
      Navigator.of(context).pop({
        'latitude': _selectedLatitude!,
        'longitude': _selectedLongitude!,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una ubicación en el mapa'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Ubicación'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (_selectedLatitude != null && _selectedLongitude != null)
            TextButton(
              onPressed: _confirmSelection,
              child: const Text(
                'Confirmar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando mapa...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _isLoading = true;
                          });
                          _initializeMap();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Mapa principal
                    MapWidget(
                      key: const ValueKey('location_picker_map'),
                      cameraOptions: CameraOptions(
                        center: Point(
                          coordinates: Position(_defaultLongitude, _defaultLatitude),
                        ),
                        zoom: _defaultZoom,
                      ),
                      styleUri: MapboxConfig.defaultStyle,
                      onMapCreated: _onMapCreated,
                    ),
                    
                    // Botón de ubicación actual
                    Positioned(
                      bottom: 80,
                      right: 20,
                      child: FloatingActionButton(
                        onPressed: _centerOnUserLocation,
                        backgroundColor: Colors.blue[700],
                        child: const Icon(Icons.my_location, color: Colors.white),
                      ),
                    ),
                    
                    // Botón para seleccionar ubicación actual del mapa
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        onPressed: _updateSelectedLocation,
                        backgroundColor: Colors.green[600],
                        child: const Icon(Icons.add_location, color: Colors.white),
                      ),
                    ),
                    
                    // Cruz indicadora estática en el centro del mapa
                    const Center(
                      child: Icon(
                        Icons.add,
                        color: Colors.red,
                        size: 40,
                        weight: 3,
                      ),
                    ),
                    
                    // Instrucciones
                    Positioned(
                      top: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.center_focus_strong,
                              color: Colors.red,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mueve el mapa para centrar la cruz roja en la ubicación deseada',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'La cruz roja fija indica dónde se seleccionará la ubicación',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_selectedLatitude != null && _selectedLongitude != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Ubicación seleccionada:\n${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
