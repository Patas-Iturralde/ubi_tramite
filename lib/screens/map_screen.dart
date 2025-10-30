import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
// SVG runtime rasterization removed; using PNG assets registration instead
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../models/office_location.dart';
import '../providers/location_provider.dart';
import '../models/place_category.dart';
import '../providers/offices_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_role.dart';
import '../config/mapbox_config.dart';
import '../theme/app_colors.dart';
import 'add_office_screen.dart';
import '../services/auth_service.dart';
import '../services/directions_service.dart';
import '../providers/theme_provider.dart';

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
  PointAnnotationManager? _routePointManager;
  List<PolylineAnnotation> _routePolylines = const [];
  List<PointAnnotation> _routeEndpoints = const [];
  List<PointAnnotation?> _officeAnnotations = const [];
  List<String> _officeLabels = const [];
  final Map<String, OfficeLocation> _annotationIdToOffice = {};
  OnPointAnnotationClickListener? _pinClickListener;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Uint8List? _markerImage;
  Uint8List? _startImage;
  Uint8List? _endImage;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _alternateRouteStyle = false;
  // Imagen personalizada deshabilitada por ahora; usamos iconos del estilo
  
  // ETA dinámico para la ruta activa
  String? _routeEtaText;
  Timer? _etaTimer;
  Timer? _zoomTimer;

  bool _isLoading = true;
  String? _errorMessage;
  List<OfficeLocation> _offices = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Animación del panel (reemplazado por DraggableScrollableSheet)

  // Usar configuración centralizada
  static const double _defaultLatitude = MapboxConfig.defaultLatitude;
  static const double _defaultLongitude = MapboxConfig.defaultLongitude;
  static const double _defaultZoom = MapboxConfig.defaultZoom;
  
  // Ubicación actual precalculada (evitar modificar providers durante build)
  Future<geo.Position?>? _positionFuture;

  Future<String> _computeDistanceEtaText(OfficeLocation office) async {
    final pos = await _positionFuture;
    if (pos == null) return 'Distancia desconocida';
    try {
      final summary = await DirectionsService.getRouteSummary(
        pos.latitude,
        pos.longitude,
        office.latitude,
        office.longitude,
      );
      final km = summary.distanceMeters / 1000.0;
      final totalMinutes = (summary.durationSeconds / 60.0).round();
      final distText = km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
      String etaText;
      if (totalMinutes >= 60) {
        final hours = totalMinutes ~/ 60;
        final mins = totalMinutes % 60;
        etaText = mins == 0 ? '${hours} h' : '${hours} h ${mins} min';
      } else {
        etaText = totalMinutes <= 1 ? '1 min' : '${totalMinutes} min';
      }
      return '$distText • $etaText';
    } catch (_) {
      // Fallback: calcular distancia geodésica si falla la API
      final meters = geo.Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        office.latitude,
        office.longitude,
      );
      final km = meters / 1000.0;
      final distText = km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
      return distText;
    }
  }

  @override
  void initState() {
    super.initState();
    
    _loadMarkerImage().then((_) {
      _initializeMap();
    });

    // Disparar la obtención de ubicación después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _positionFuture = ref.read(locationProvider.notifier).getCurrentPosition();
      });
    });
  }

  @override
  void dispose() {
    _etaTimer?.cancel();
    _zoomTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Eliminado: ya no se limpian oficinas al iniciar

  /// Carga la imagen del marcador desde los assets.
  Future<void> _loadMarkerImage() async {
    try {
      final ByteData byteData = await rootBundle.load('assets/images/marker_icon.png');
      setState(() {
        _markerImage = byteData.buffer.asUint8List();
        _startImage = _markerImage;
        _endImage = _markerImage;
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
    _applyMapStyle(mode: ref.read(themeModeProvider));
    _ensureCustomIcons().then((_) => _addOfficeMarkers());
    _centerOnUserLocation();
    _updateMarkerLabelSizeForZoom();
    _zoomTimer?.cancel();
    _zoomTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _updateMarkerLabelSizeForZoom();
    });
  }

  Future<void> _ensureCustomIcons() async {
    if (mapboxMap == null) return;
    await _registerPngStyleImage('edificio', 'assets/images/edificio.png', 48);
    await _registerPngStyleImage('abogado', 'assets/images/abogado.png', 48);
  }

  Future<void> _registerPngStyleImage(String name, String assetPath, int size) async {
    if (mapboxMap == null) return;
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      final mbx = MbxImage(width: size, height: size, data: bytes);
      await mapboxMap!.style.addStyleImage(
        name,
        1.0,
        mbx,
        false,
        const [],
        const [],
        null,
      );
    } catch (_) {
      // Fallback a icono genérico si el PNG no existe aún
      try {
        final data = await rootBundle.load('assets/images/marker_icon.png');
        final bytes = data.buffer.asUint8List();
        final mbx = MbxImage(width: size, height: size, data: bytes);
        await mapboxMap!.style.addStyleImage(
          name,
          1.0,
          mbx,
          false,
          const [],
          const [],
          null,
        );
      } catch (e) {
        debugPrint('No se pudo registrar el icono $name: $e');
      }
    }
  }

  // Carga de imagen personalizada eliminada por compatibilidad de API

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
    if (mapboxMap == null) return;

    if (_pointAnnotationManager == null) {
      _pointAnnotationManager = await mapboxMap!.annotations.createPointAnnotationManager();
      // Listener de clic en pines
      _pinClickListener = _PointTapListener((annotation){
        final office = _annotationIdToOffice[annotation.id];
        if (office != null) {
          _showOfficeInfoDialog(office);
        }
      });
      if (_pinClickListener != null) {
        _pointAnnotationManager!.addOnPointAnnotationClickListener(_pinClickListener!);
      }
    } else {
      await _pointAnnotationManager!.deleteAll();
    }

    if (_offices.isEmpty) return;

      final List<String> labels = [];
      final List<PointAnnotationOptions> optionsList = _offices.map((office) {
        labels.add(office.name);
        return PointAnnotationOptions(
          geometry: Point(coordinates: Position(office.longitude, office.latitude)),
          iconImage: office.category.iconName,
          iconColor: office.category.color.value,
          iconSize: 1.2,
          textField: office.name,
          textAnchor: TextAnchor.TOP,
          textOffset: [0, -1.6],
          textHaloColor: Colors.black.withOpacity(0.6).value,
          textHaloWidth: 1.0,
          textColor: Colors.white.value,
          iconTextFit: IconTextFit.NONE,
          iconTextFitPadding: [0, 0, 0, 0],
        );
      }).toList();

      if (optionsList.isNotEmpty) {
        _officeAnnotations = await _pointAnnotationManager!.createMulti(optionsList);
        _officeLabels = labels;
        _annotationIdToOffice.clear();
        for (var i = 0; i < _officeAnnotations.length; i++) {
          final ann = _officeAnnotations[i];
          if (ann != null && i < _offices.length) {
            _annotationIdToOffice[ann.id] = _offices[i];
          }
        }
      }

      // Los marcadores se pueden tocar desde el drawer lateral
  }

  Future<void> _updateMarkerLabelSizeForZoom() async {
    if (mapboxMap == null || _officeAnnotations.isEmpty || _pointAnnotationManager == null) return;
    try {
      final cam = await mapboxMap!.getCameraState();
      final zoom = cam.zoom;
      // Escala simple y ocultar etiquetas con poco zoom
      final size = (9.0 + (zoom - 13.0)).clamp(9.0, 14.0);
      final hideLabels = zoom < 12.0;
      final futures = <Future>[];
      for (var i = 0; i < _officeAnnotations.length; i++) {
        final ann = _officeAnnotations[i];
        if (ann == null) continue;
        ann.textSize = size;
        ann.textField = hideLabels ? '' : (_officeLabels.length > i ? _officeLabels[i] : ann.textField);
        futures.add(_pointAnnotationManager!.update(ann));
      }
      await Future.wait(futures);
    } catch (_) {}
  }

  /// Muestra el diálogo con información de la oficina
  void _showOfficeInfoDialog(OfficeLocation office) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF232323) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.darkBlue;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      barrierLabel: 'Detalles oficina',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.6 : 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        child: const Icon(Icons.location_on, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          office.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    office.description,
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.my_location, size: 18, color: AppColors.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _computeDistanceEtaText(office),
                            builder: (context, snap) {
                              final text = snap.connectionState == ConnectionState.waiting
                                  ? 'Calculando distancia…'
                                  : (snap.data ?? 'Distancia desconocida');
                              return Text(
                                text,
                                style: TextStyle(fontSize: 12, color: textColor),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.primaryColor.withOpacity(0.5)),
                            foregroundColor: AppColors.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cerrar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _drawRouteToOffice(office);
                            if (_sheetController.isAttached) {
                              await _sheetController.animateTo(
                                0.12,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          icon: const Icon(Icons.alt_route),
                          label: const Text('Ir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved), child: child),
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
        // Ajustar tamaño de etiquetas tras animación
        Future.delayed(const Duration(milliseconds: 600), _updateMarkerLabelSizeForZoom);
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
    Future.delayed(const Duration(milliseconds: 500), _updateMarkerLabelSizeForZoom);
    // El panel es draggable; no es necesario cerrarlo manualmente
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
      // Crear/limpiar route endpoints manager
      _routePointManager ??= await mapboxMap!.annotations.createPointAnnotationManager();
      if (_routeEndpoints.isNotEmpty) {
        await _routePointManager!.deleteAll();
        _routeEndpoints = const [];
      }

      final geometry = LineString(
        coordinates: coords.map((p) => Position(p[1], p[0])).toList(),
      );

      // Grosor dinámico por zoom y colores por tema
      final camera = await mapboxMap!.getCameraState();
      final zoom = camera.zoom;
      double base = (2.0 + (zoom - 10.0) * 0.7).clamp(3.0, 10.0);
      final isDark = Theme.of(context).brightness == Brightness.dark;

      // Estilo multicapa (azul/cyan vs alterno morado/magenta)
      // Sombra
      final shadowLine = await _polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          lineColor: (isDark ? Colors.white12 : Colors.black26).value,
          lineWidth: base + 4,
          lineOpacity: 1.0,
          geometry: geometry,
        ),
      );
      // Principal
      final mainLine = await _polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          lineColor: (_alternateRouteStyle
                  ? const Color(0xFF8E24AA)
                  : (isDark ? const Color(0xFF90CAF9) : const Color(0xFF1E88E5)))
              .withOpacity(0.9)
              .value,
          lineWidth: base + 1,
          lineOpacity: 1.0,
          geometry: geometry,
        ),
      );
      // Highlight
      final highlightLine = await _polylineAnnotationManager!.create(
        PolylineAnnotationOptions(
          lineColor: (_alternateRouteStyle
                  ? const Color(0xFFFF4081)
                  : (isDark ? const Color(0xFF80DEEA) : const Color(0xFF26C6DA)))
              .withOpacity(0.95)
              .value,
          lineWidth: base - 1,
          lineOpacity: 1.0,
          geometry: geometry,
        ),
      );

      _routePolylines = [shadowLine, mainLine, highlightLine];

      // Punto de fin únicamente (no mostrar icono en el inicio de la ruta)
      final end = await _routePointManager!.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(office.longitude, office.latitude)),
          iconImage: 'flag',
          iconSize: 1.2,
        ),
      );
      _routeEndpoints = [end];

      // Ajustar cámara aproximadamente al destino
      await _navigateToOffice(office);
      // Calcular ETA inicial y programar actualizaciones periódicas
      await _updateRouteEta(office);
      _etaTimer?.cancel();
      _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        await _updateRouteEta(office);
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo trazar la ruta: $e')),
        );
      }
    }
  }

  Future<void> _updateRouteEta(OfficeLocation office) async {
    try {
      final pos = await ref.read(locationProvider.notifier).getCurrentPosition();
      if (pos == null) return;
      final summary = await DirectionsService.getRouteSummary(
        pos.latitude,
        pos.longitude,
        office.latitude,
        office.longitude,
      );
      final totalMinutes = (summary.durationSeconds / 60.0).round();
      String etaText;
      if (totalMinutes >= 60) {
        final hours = totalMinutes ~/ 60;
        final mins = totalMinutes % 60;
        etaText = mins == 0 ? '${hours} h' : '${hours} h ${mins} min';
      } else {
        etaText = totalMinutes <= 1 ? '1 min' : '${totalMinutes} min';
      }
      if (mounted) {
        setState(() {
          _routeEtaText = etaText;
        });
      }
    } catch (_) {
      // mantener último ETA si falla temporalmente
    }
  }

  /// Aplica estilo del mapa considerando ThemeMode explícito o tema actual
  Future<void> _applyMapStyle({ThemeMode? mode}) async {
    if (mapboxMap == null) return;
    bool isDark;
    if (mode != null) {
      isDark = mode == ThemeMode.dark
          ? true
          : mode == ThemeMode.light
              ? false
              : MediaQuery.of(context).platformBrightness == Brightness.dark;
    } else {
      isDark = Theme.of(context).brightness == Brightness.dark;
    }
    final uri = isDark ? MapboxConfig.darkStyle : MapboxConfig.defaultStyle;
    try {
      await mapboxMap!.style.setStyleURI(uri);
      await _ensureCustomIcons();
    } catch (_) {}
  }

  

  Future<void> _clearRoute() async {
    try {
      _etaTimer?.cancel();
      _etaTimer = null;
      _routeEtaText = null;
      if (_polylineAnnotationManager != null) {
        await _polylineAnnotationManager!.deleteAll();
        _routePolylines = const [];
      }
      if (_routePointManager != null) {
        await _routePointManager!.deleteAll();
        _routeEndpoints = const [];
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Construye el Drawer lateral con la lista de oficinas
  Widget _buildDrawer() {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
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
          const Divider(height: 1),
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Modo oscuro'),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
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
    // Escuchar cambios de tema y aplicar estilo de mapa en caliente
    ref.listen(themeModeProvider, (previous, next) async {
      await _applyMapStyle(mode: next);
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
                        styleUri: Theme.of(context).brightness == Brightness.dark
                            ? MapboxConfig.darkStyle
                            : MapboxConfig.defaultStyle,
                        onMapCreated: _onMapCreated,
                      ),
                      Positioned(
                        top: 55,
                        left: 5,
                        child: FloatingActionButton(
                          heroTag: 'centerLocationFab',
                          tooltip: 'Centrar en mi ubicación',
                          onPressed: _centerOnUserLocation,
                          backgroundColor: AppColors.primaryColor,
                          child: const Icon(Icons.my_location, color: AppColors.white),
                        ),
                      ),
                      // Burbuja ETA sobre el mapa cuando hay ruta
                      if (_routePolylines.isNotEmpty && _routeEtaText != null)
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    _routeEtaText!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Consumer(builder: (context, ref, _) {
                        final roleAsync = ref.watch(userRoleProvider);
                        final isAdmin = roleAsync.maybeWhen(
                          data: (r) => r.toString().contains('admin'),
                          orElse: () => false,
                        );
                        return Positioned(
                          top: 55,
                          right: 5,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Limpiar ruta si existe
                              if (_routePolylines.isNotEmpty || _routeEndpoints.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: FloatingActionButton(
                                    heroTag: 'clearRouteFab',
                                    tooltip: 'Limpiar ruta',
                                      onPressed: _clearRoute,
                                    backgroundColor: Colors.redAccent,
                                    child: const Icon(Icons.clear_all, color: Colors.white),
                                  ),
                                ),
                              if (isAdmin)
                                FloatingActionButton(
                                  heroTag: 'addOfficeFab',
                                  tooltip: 'Agregar oficina',
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
                            ],
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : AppColors.white;
    final sheetShadow = isDark ? Colors.black54 : AppColors.overlayDark;
    final titleColor = isDark ? Colors.white : AppColors.darkBlue;
    final subtitleColor = isDark ? Colors.white70 : AppColors.mediumBlue;

    return Align(
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        controller: _sheetController,
        expand: false,
        initialChildSize: 0.14,
        minChildSize: 0.12,
        maxChildSize: 0.65,
        builder: (context, scrollController) {
          return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: sheetShadow,
                blurRadius: 15,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Oficinas Cercanas',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                          ),
                          Text(
                            '${officesState.offices.length} oficinas disponibles',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: subtitleColor,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Buscador
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Buscar oficinas...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF222222) : Colors.grey.shade100,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (officesState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                    ),
                  ),
                )
              else if (officesState.error != null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('Error al cargar oficinas',
                        style: TextStyle(color: AppColors.mediumBlue)),
                  ),
                )
              else if (officesState.offices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('No hay oficinas disponibles',
                        style: TextStyle(color: AppColors.mediumBlue)),
                  ),
                )
              else
                ...officesState.offices
                    .where((o) {
                      if (_searchQuery.isEmpty) return true;
                      final q = _searchQuery.toLowerCase();
                      return o.name.toLowerCase().contains(q) ||
                             o.description.toLowerCase().contains(q);
                    })
                    .map((o) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildOfficeCard(o),
                        ))
                    .toList(),
              const SizedBox(height: 12),
            ],
          ),
          );
        },
      ),
    );
  }
  
  // Panel inferior ahora es DraggableScrollableSheet

  /// Tarjeta de oficina moderna
  Widget _buildOfficeCard(OfficeLocation office) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleAsync = ref.watch(userRoleProvider);
    final cardBg = isDark ? const Color(0xFF252525) : AppColors.white;
    final borderCol = isDark ? Colors.white10 : AppColors.lightGrey.withOpacity(0.3);
    final titleCol = isDark ? Colors.white : AppColors.darkBlue;
    final bodyCol = isDark ? Colors.white70 : AppColors.mediumBlue;

    String? _scheduleFrom(OfficeLocation o) {
      if (o.schedule != null && o.schedule!.trim().isNotEmpty) return o.schedule!.trim();
      final match = RegExp(r'Horario:\s*(.*)', caseSensitive: false).firstMatch(o.description);
      final value = match?.group(1)?.trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }
    String _cleanDescription(String text) {
      return text.replaceAll(RegExp(r'\n?\s*Horario:\s*.*', caseSensitive: false), '').trim();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black54 : AppColors.overlayDark).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: borderCol,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOfficeInfoDialog(office),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: titleCol,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _cleanDescription(office.description),
                        style: TextStyle(
                          color: bodyCol,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<geo.Position?>(
                        future: _positionFuture,
                        builder: (context, snap) {
                          String text = 'Distancia desconocida';
                          if (snap.connectionState == ConnectionState.waiting) {
                            text = 'Calculando distancia…';
                          } else if (snap.data != null) {
                            final pos = snap.data!;
                            final meters = geo.Geolocator.distanceBetween(
                              pos.latitude,
                              pos.longitude,
                              office.latitude,
                              office.longitude,
                            );
                            final km = (meters / 1000.0);
                            text = km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
                          }
                          return Row(
                            children: [
                              Icon(
                                Icons.route,
                                size: 14,
                                color: isDark ? Colors.white54 : AppColors.lightGrey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                text,
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : AppColors.lightGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      if (_scheduleFrom(office) != null)
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: isDark ? Colors.white54 : AppColors.lightGrey,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _scheduleFrom(office)!,
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : AppColors.lightGrey,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                    color: AppColors.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.primaryColor,
                    size: 16,
                  ),
                ),
                if (roleAsync.value == UserRole.admin) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Editar',
                    icon: Icon(Icons.edit, color: isDark ? Colors.white70 : AppColors.darkBlue),
                    onPressed: () => _showEditOfficeSheet(office),
                  ),
                ],
              ],
            ),
          ),
                  ),
      ),
    );
  }

  Future<void> _showEditOfficeSheet(OfficeLocation office) async {
    final nameCtrl = TextEditingController(text: office.name);
    final descCtrl = TextEditingController(text: office.description);
    final schedCtrl = TextEditingController(text: office.schedule ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Future<void> _pickSchedule() async {
      final now = TimeOfDay.now();
      final start = await showTimePicker(
        context: context,
        initialTime: now,
        helpText: 'Selecciona hora de inicio',
      );
      if (start == null) return;
      final end = await showTimePicker(
        context: context,
        initialTime: start.replacing(hour: (start.hour + 1) % 24),
        helpText: 'Selecciona hora de fin',
      );
      if (end == null) return;
      final startStr = start.format(context);
      final endStr = end.format(context);
      schedCtrl.text = '$startStr - $endStr';
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Editar oficina', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: schedCtrl,
                readOnly: true,
                onTap: _pickSchedule,
                decoration: InputDecoration(
                  labelText: 'Horario',
                  hintText: 'Selecciona el horario',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.access_time),
                  suffixIcon: IconButton(
                    tooltip: 'Elegir horario',
                    icon: const Icon(Icons.schedule),
                    onPressed: _pickSchedule,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await ref.read(officesProvider.notifier)
                            .deleteCustomOffice(office.name);
                        if (ok && mounted) Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Borrar'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final updated = office.copyWith(
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          schedule: schedCtrl.text.trim(),
                        );
                        final ok = await ref.read(officesProvider.notifier)
                            .addCustomOffice(updated);
                        if (ok && mounted) Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Sincronización de descripción/horario ahora separadas en el modelo
}

class _PointTapListener extends OnPointAnnotationClickListener {
  final void Function(PointAnnotation) onTap;
  _PointTapListener(this.onTap);
  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    onTap(annotation);
    return true;
  }
}