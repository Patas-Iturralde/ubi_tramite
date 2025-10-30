import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/office_location.dart';
import '../providers/location_provider.dart';
import '../providers/offices_provider.dart';
import '../providers/auth_provider.dart';
import '../config/mapbox_config.dart';
import '../theme/app_colors.dart';
import 'add_office_screen.dart';
import '../services/auth_service.dart';
import '../services/directions_service.dart';

/// Pantalla principal que muestra el mapa interactivo con oficinas gubernamentales
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  MapboxMap? mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  List<PolylineAnnotation> _routePolylines = const [];
  Uint8List? _markerImage;

  bool _isLoading = true;
  String? _errorMessage;
  List<OfficeLocation> _offices = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Animación para el panel desplegable
  late AnimationController _panelController;
  late Animation<double> _panelAnimation;
  bool _isPanelExpanded = false;

  // Usar configuración centralizada
  static const double _defaultLatitude = MapboxConfig.defaultLatitude;
  static const double _defaultLongitude = MapboxConfig.defaultLongitude;
  static const double _defaultZoom = MapboxConfig.defaultZoom;

  @override
  void initState() {
    super.initState();
    
    // Inicializar animación del panel
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _panelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeInOut,
    ));
    
    _loadMarkerImage().then((_) {
      _initializeMap();
    });
  }

  @override
  void dispose() {
    _panelController.dispose();
    super.dispose();
  }

  // Eliminado: ya no se limpian oficinas al iniciar

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
      final officesState = ref.read(officesProvider);
      setState(() => _offices = officesState.offices);
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
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _drawRouteToOffice(office);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Trazar ruta'),
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
    
    // Cerrar el panel después de navegar
    if (_isPanelExpanded) {
      _togglePanel();
    }
  }

  Future<void> _drawRouteToOffice(OfficeLocation office) async {
    if (mapboxMap == null) return;
    try {
      final position = await ref.read(locationProvider.notifier).getCurrentPosition();
      if (position == null) return;

      final coords = await DirectionsService.getRoute(
        position.latitude,
        position.longitude,
        office.latitude,
        office.longitude,
      );

      // Crear/limpiar polyline manager
      _polylineAnnotationManager ??= await mapboxMap!.annotations.createPolylineAnnotationManager();
      if (_routePolylines.isNotEmpty) {
        await _polylineAnnotationManager!.deleteAll();
        _routePolylines = const [];
      }

      final line = await _polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
          lineOpacity: 0.9,
          geometry: LineString(coordinates: coords.map((p) => Position(p[1], p[0])).toList()),
        ),
      );
      _routePolylines = [line];

      // Ajustar cámara aproximadamente al destino
      await _navigateToOffice(office);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo trazar la ruta: $e')),
        );
      }
    }
  }

  /// Construye el Drawer lateral con la lista de oficinas
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.darkBlue,
                  AppColors.mediumBlue,
                  AppColors.lightBlue,
                ],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: AppColors.white,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                'Oficinas - TuGuiApp',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _offices.isEmpty
                ? const Center(
                    child: Text(
                      'No hay oficinas disponibles.',
                      style: TextStyle(
                        color: AppColors.lightBlue,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _offices.length,
                    itemBuilder: (context, index) {
                      final office = _offices[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.overlayDark,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primaryColor,
                            ),
                          ),
                          title: Text(
                            office.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkBlue,
                            ),
                          ),
                          subtitle: Text(
                            office.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.darkBlue.withOpacity(0.8),
                            ),
                          ),
                        onTap: () {
                          Navigator.of(context).pop(); // Cerrar drawer
                          _showOfficeInfoDialog(office);
                        },
                        ),
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
    // Escuchar cambios de oficinas y actualizar marcadores cuando cambien
    ref.listen(officesProvider, (previous, next) async {
      if (!mounted) return;
      setState(() {
        _offices = next.offices;
      });
      await _addMapboxMarkers();
    });
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('TuGuiApp'),
        backgroundColor: AppColors.secondaryColor,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await AuthService.signOut();
              } catch (_) {}
            },
            tooltip: 'Cerrar sesión',
          )
        ],
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
                          backgroundColor: AppColors.primaryColor,
                          child: const Icon(Icons.my_location, color: AppColors.white),
                        ),
                      ),
                      Consumer(builder: (context, ref, _) {
                        final roleAsync = ref.watch(userRoleProvider);
                        final isAdmin = roleAsync.maybeWhen(
                          data: (r) => r.toString().contains('admin'),
                          orElse: () => false,
                        );
                        if (!isAdmin) return const SizedBox.shrink();
                        return Positioned(
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
                            backgroundColor: AppColors.secondaryColor,
                            child: const Icon(Icons.add, color: AppColors.white),
                          ),
                        );
                      }),
                      
                      // Botón desplegable de oficinas
                      _buildOfficesDropdownButton(),
                    ],
                  ),
      ),
    );
  }

  /// Botón desplegable de oficinas desde abajo
  Widget _buildOfficesDropdownButton() {
    final officesState = ref.watch(officesProvider);
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _panelAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _panelAnimation.value) * 350),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.overlayDark,
                    blurRadius: 15,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle para indicar que se puede deslizar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Botón para expandir/contraer
                  GestureDetector(
                    onTap: _togglePanel,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryColor, AppColors.secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Oficinas Cercanas',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkBlue,
                                  ),
                                ),
                                Text(
                                  '${officesState.offices.length} oficinas disponibles',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.mediumBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _isPanelExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_up,
                                color: AppColors.primaryColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Panel expandible con lista de oficinas
                  if (_isPanelExpanded) ...[
                    Container(
                      height: 350,
                      child: officesState.isLoading
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Cargando oficinas...',
                                    style: TextStyle(color: AppColors.mediumBlue),
                                  ),
                                ],
                              ),
                            )
                          : officesState.error != null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: AppColors.primaryColor,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Error: ${officesState.error}',
                                        style: const TextStyle(color: AppColors.mediumBlue),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : officesState.offices.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.location_off,
                                            color: AppColors.lightGrey,
                                            size: 48,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No hay oficinas disponibles',
                                            style: TextStyle(color: AppColors.mediumBlue),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: officesState.offices.length,
                                      itemBuilder: (context, index) {
                                        final office = officesState.offices[index];
                                        return _buildOfficeCard(office);
                                      },
                                    ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  /// Alterna el estado del panel desplegable
  void _togglePanel() {
    setState(() {
      _isPanelExpanded = !_isPanelExpanded;
      if (_isPanelExpanded) {
        _panelController.forward();
      } else {
        _panelController.reverse();
      }
    });
  }

  /// Tarjeta de oficina moderna
  Widget _buildOfficeCard(OfficeLocation office) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.overlayDark.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.lightGrey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToOffice(office),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryColor, AppColors.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        office.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBlue,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        office.description,
                        style: TextStyle(
                          color: AppColors.mediumBlue,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.my_location,
                            size: 14,
                            color: AppColors.lightGrey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${office.latitude.toStringAsFixed(4)}, ${office.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: AppColors.lightGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.primaryColor,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
                  ),
      ),
    );
  }
}