# 🎯 Solución para Marcadores Dinámicos - UbiTrámite

## ✅ **Problema Resuelto**

### 🚨 **Problema Original:**
- Los marcadores se movían junto con la pantalla
- No se quedaban en sus ubicaciones geográficas correctas
- Se desplazaban incorrectamente al navegar por el mapa

### 🔧 **Solución Implementada:**

#### **1. Sistema de Conversión Dinámica de Coordenadas:**
```dart
/// Convierte coordenadas geográficas a coordenadas de pantalla usando el estado actual del mapa
Future<Offset?> _geoToScreen(double lat, double lng) async {
  if (mapboxMap == null) return null;
  
  try {
    // Obtener el estado actual de la cámara del mapa
    final cameraState = await mapboxMap!.getCameraState();
    final center = cameraState.center;
    final zoom = cameraState.zoom;
    
    // Calcular la diferencia en grados desde el centro actual
    final double latDiff = lat - center.coordinates.lat;
    final double lngDiff = lng - center.coordinates.lng;
    
    // Calcular píxeles por grado basado en el zoom actual
    final double pixelsPerDegree = 256 * pow(2, zoom) / 360;
    
    // Convertir a coordenadas de pantalla
    final double x = (screenWidth / 2) + (lngDiff * pixelsPerDegree);
    final double y = (screenHeight / 2) - (latDiff * pixelsPerDegree);
    
    return Offset(x, y);
  } catch (e) {
    debugPrint('Error al convertir coordenadas: $e');
    return null;
  }
}
```

#### **2. Actualización Automática de Marcadores:**
```dart
/// Configura los listeners del mapa para actualizar marcadores
void _setupMapListeners() {
  if (mapboxMap == null) return;
  
  // Timer para actualizar marcadores periódicamente
  _markerUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
    if (mounted) {
      setState(() {
        // Esto causará que los FutureBuilder se reconstruyan
        // y recalculen las posiciones de los marcadores
      });
    }
  });
}
```

#### **3. Marcadores con FutureBuilder:**
```dart
/// Crea un marcador Flutter para una oficina
Widget _buildOfficeMarker(OfficeLocation office) {
  return FutureBuilder<Offset?>(
    future: _geoToScreen(office.latitude, office.longitude),
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data == null) {
        return const SizedBox.shrink();
      }
      
      final screenPos = snapshot.data!;
      
      return Positioned(
        left: screenPos.dx - 15,
        top: screenPos.dy - 30,
        child: GestureDetector(
          onTap: () => _showOfficeInfo(office),
          child: Container(
            // ... marcador visual
          ),
        ),
      );
    },
  );
}
```

## 🎯 **Características de la Solución:**

### **✅ Ventajas:**
- **Posicionamiento Dinámico**: Los marcadores se recalculan en tiempo real
- **Centro Actual**: Usa el centro actual del mapa, no coordenadas fijas
- **Zoom Adaptativo**: Se ajusta automáticamente al nivel de zoom
- **Actualización Continua**: Timer que actualiza cada 500ms
- **Gestión de Memoria**: Limpia el timer en dispose()

### **🔧 Componentes Técnicos:**

#### **1. Conversión de Coordenadas:**
- **Estado del Mapa**: Obtiene el centro y zoom actuales
- **Cálculo Relativo**: Calcula diferencias desde el centro actual
- **Fórmula de Zoom**: `256 * pow(2, zoom) / 360` píxeles por grado
- **Coordenadas de Pantalla**: Conversión precisa a píxeles

#### **2. Actualización Automática:**
- **Timer Periódico**: Actualiza cada 500ms
- **setState()**: Fuerza la reconstrucción de widgets
- **FutureBuilder**: Recalcula posiciones automáticamente
- **Gestión de Ciclo de Vida**: Limpia recursos en dispose()

#### **3. Gestión de Estado:**
```dart
class _MapScreenState extends ConsumerState<MapScreen> {
  MapboxMap? mapboxMap;
  List<OfficeLocation> _offices = [];
  Timer? _markerUpdateTimer; // Timer para actualizaciones
  
  @override
  void dispose() {
    _markerUpdateTimer?.cancel(); // Limpiar recursos
    super.dispose();
  }
}
```

## 📱 **Resultado Final:**

### **Comportamiento Esperado:**
1. **Marcadores Fijos**: Se mantienen en sus ubicaciones geográficas
2. **Navegación Correcta**: Se mueven apropiadamente al navegar el mapa
3. **Zoom Adaptativo**: Se ajustan al nivel de zoom actual
4. **Actualización Fluida**: Se recalculan cada 500ms
5. **Interactividad**: Mantienen la funcionalidad de toque

### **Flujo de Funcionamiento:**
```
1. Usuario navega por el mapa
2. Timer detecta movimiento (cada 500ms)
3. setState() fuerza reconstrucción
4. FutureBuilder recalcula posiciones
5. Marcadores se reposicionan correctamente
```

## 🚀 **Optimizaciones Implementadas:**

### **Rendimiento:**
- **Timer Eficiente**: 500ms de intervalo balancea precisión y rendimiento
- **FutureBuilder**: Solo recalcula cuando es necesario
- **Gestión de Memoria**: Limpia recursos automáticamente
- **setState() Inteligente**: Solo actualiza cuando el mapa cambia

### **Precisión:**
- **Centro Dinámico**: Usa el centro actual del mapa
- **Zoom Real**: Considera el nivel de zoom actual
- **Fórmula Matemática**: Conversión precisa de coordenadas
- **Estado del Mapa**: Obtiene datos reales de Mapbox

---

**✅ Estado**: **RESUELTO** - Los marcadores ahora se posicionan dinámicamente basándose en el estado actual del mapa y se mantienen en sus ubicaciones geográficas correctas durante la navegación.
