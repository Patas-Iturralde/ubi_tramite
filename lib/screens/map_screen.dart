import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/office_location.dart';
import '../providers/location_provider.dart';
import '../providers/offices_provider.dart';
import '../config/mapbox_config.dart';
import 'add_office_screen.dart';

/// Pantalla principal que muestra el mapa interactivo con oficinas gubernamentales
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  Uint8List? _markerImage;

  bool _isLoading = true;
  String? _errorMessage;
  List<OfficeLocation> _offices = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Usar configuración centralizada
  static const double _defaultLatitude = MapboxConfig.defaultLatitude;
  static const double _defaultLongitude = MapboxConfig.defaultLongitude;
  static const double _defaultZoom = MapboxConfig.defaultZoom;

  @override
  void initState() {
    super.initState();
    _loadMarkerImage().then((_) {
      _clearCustomOffices();
      _initializeMap();
    });
  }

  /// Limpia las oficinas personalizadas guardadas
  Future<void> _clearCustomOffices() async {
    try {
      await ref.read(officesProvider.notifier).clearCustomOffices();
      debugPrint('Oficinas personalizadas limpiadas');
    } catch (e) {
      debugPrint('Error al limpiar oficinas personalizadas: $e');
    }
  }

  /// Carga la imagen del marcador desde los assets.
  Future<void> _loadMarkerImage() async {
    try {
      final ByteData byteData = await rootBundle.load('assets/images/marker_icon.png');
      setState(() {
        _markerImage = byteData.buffer.asUint8List();
      });
    } catch (e) {
      debugPrint('Error al cargar la imagen del marcador: $e');
      setState(() {
        _errorMessage = 'Error al cargar recursos del mapa.';
      });
    }
  }

  /// Inicializa el mapa y los permisos
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
      await Permission.location.request();
    }
  }

  /// Configura el mapa cuando está listo
  void _onMapCreated(MapboxMap controller) {
    mapboxMap = controller;
    _enableUserLocation();
    _addOfficeMarkers();
    _centerOnUserLocation();
    
    ref.listen(officesProvider, (previous, next) {
      if (mounted && mapboxMap != null) {
        _addOfficeMarkers();
      }
    });
  }

  /// Habilita la visualización de la ubicación del usuario en el mapa
  Future<void> _enableUserLocation() async {
    if (mapboxMap == null) return;
    await mapboxMap!.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ),
    );
  }

  /// Obtiene las oficinas del provider y llama a la función para dibujarlas
  Future<void> _addOfficeMarkers() async {
    if (mapboxMap == null) return;
    try {
      await ref.read(officesProvider.notifier).loadOffices();
      final officesState = ref.read(officesProvider);
      setState(() {
        _offices = officesState.offices;
      });
      await _addMapboxMarkers();
    } catch (e) {
      debugPrint('Error al cargar oficinas: $e');
    }
  }

  /// Agrega marcadores usando el sistema nativo de Anotaciones de Mapbox
  Future<void> _addMapboxMarkers() async {
    if (mapboxMap == null || _markerImage == null) return;

    if (_pointAnnotationManager == null) {
      _pointAnnotationManager = await mapboxMap!.annotations.createPointAnnotationManager();
    } else {
      await _pointAnnotationManager!.deleteAll();
    }

    if (_offices.isEmpty) return;

      final List<PointAnnotationOptions> optionsList = _offices.map((office) {
        return PointAnnotationOptions(
          geometry: Point(coordinates: Position(office.longitude, office.latitude)),
          image: _markerImage,
          iconSize: 0.3,
          textField: office.name,
          iconTextFit: IconTextFit.NONE,
          iconTextFitPadding: [0, 0, 0, 0],
        );
      }).toList();

      if (optionsList.isNotEmpty) {
        await _pointAnnotationManager!.createMulti(optionsList);
      }

      // Los marcadores se pueden tocar desde el drawer lateral
  }

  /// Muestra el diálogo con información de la oficina
  void _showOfficeInfoDialog(OfficeLocation office) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  office.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                office.description,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Coordenadas:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${office.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      'Lng: ${office.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToOffice(office);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Ir a ubicación'),
            ),
          ],
        );
      },
    );
  }

  /// Centra el mapa en la ubicación actual del usuario
  Future<void> _centerOnUserLocation() async {
    try {
      final position = await ref.read(locationProvider.notifier).getCurrentPosition();
      if (position != null && mapboxMap != null) {
        mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(position.longitude, position.latitude)),
            zoom: 15.0,
          ),
          MapAnimationOptions(duration: 2000),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener tu ubicación.')),
        );
      }
    } catch (e) {
      debugPrint('Error al centrar en ubicación del usuario: $e');
    }
  }

  /// Navega y centra el mapa en una oficina específica
  Future<void> _navigateToOffice(OfficeLocation office) async {
    if (mapboxMap == null) return;
    await mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(office.longitude, office.latitude)),
        zoom: 16.0,
      ),
      MapAnimationOptions(duration: 1500),
    );
  }

  /// Construye el Drawer lateral con la lista de oficinas
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue[700]),
            child: const Center(
              child: Text(
                'Oficinas - UbiTrámite',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: _offices.isEmpty
                ? const Center(child: Text('No hay oficinas disponibles.'))
                : ListView.builder(
                    itemCount: _offices.length,
                    itemBuilder: (context, index) {
                      final office = _offices[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.redAccent),
                        title: Text(office.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(office.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          Navigator.of(context).pop(); // Cerrar drawer
                          _showOfficeInfoDialog(office);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('UbiTrámite'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Stack(
                    children: [
                      MapWidget(
                        key: const ValueKey('ubimap'),
                        cameraOptions: CameraOptions(
                          center: Point(coordinates: Position(_defaultLongitude, _defaultLatitude)),
                          zoom: _defaultZoom,
                        ),
                        styleUri: MapboxConfig.defaultStyle,
                        onMapCreated: _onMapCreated,
                      ),
                      Positioned(
                        bottom: 96,
                        right: 20,
                        child: FloatingActionButton(
                          heroTag: 'centerLocationFab',
                          onPressed: _centerOnUserLocation,
                          backgroundColor: Colors.blue[700],
                          child: const Icon(Icons.my_location, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: FloatingActionButton(
                          heroTag: 'addOfficeFab',
                          onPressed: () async {
                            await Navigator.of(context).push<bool>(
                              MaterialPageRoute(builder: (context) => const AddOfficeScreen()),
                            );
                            if (mounted) {
                              await _addOfficeMarkers();
                            }
                          },
                          backgroundColor: Colors.green[600],
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}