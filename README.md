# TuGuiApp

Una aplicación Flutter para encontrar oficinas gubernamentales en Ecuador usando mapas interactivos.

## Características

- 🗺️ **Mapa interactivo** con Mapbox
- 📍 **Geolocalización** del usuario
- 🏢 **Marcadores** de oficinas gubernamentales
- 📱 **Soporte multiplataforma** (Android y Web)
- 🎨 **Interfaz moderna** con Material Design 3

## Tecnologías Utilizadas

- **Flutter 3.x** - Framework de desarrollo
- **Riverpod** - Gestión de estado
- **Mapbox Maps Flutter** - Mapas interactivos
- **Geolocator** - Geolocalización
- **Permission Handler** - Manejo de permisos

## Configuración del Proyecto

### 1. Instalar dependencias

```bash
flutter pub get
```

### 2. Configurar Mapbox

El token de Mapbox ya está configurado en el proyecto:
- Token: `pk.eyJ1IjoiaGVybmFuLWl0dXJyYWxkZSIsImEiOiJjbWdpYWR4MmgwNzNoMmxvdmMyZzNseHNiIn0.tLctAoCsjPzIcp3kCD0QPQ`
- Ubicado en: `lib/config/mapbox_config.dart`

### 3. Permisos de Android

Los permisos de ubicación ya están configurados en `android/app/src/main/AndroidManifest.xml`:
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `INTERNET`

### 4. Ejecutar la aplicación

```bash
# Para Android
flutter run

# Para Web
flutter run -d web-server --web-port 8080
```

## Estructura del Proyecto

```
lib/
├── config/
│   └── mapbox_config.dart          # Configuración de Mapbox
├── data/
│   └── mock_offices.dart           # Datos mock de oficinas
├── models/
│   └── office_location.dart       # Modelo de datos
├── providers/
│   └── location_provider.dart     # Provider de ubicación
├── screens/
│   └── map_screen.dart            # Pantalla principal del mapa
└── main.dart                      # Punto de entrada
```

## Funcionalidades

### Mapa Interactivo
- Centrado en Quito, Ecuador por defecto
- Estilo de mapa: Mapbox Streets
- Zoom y navegación táctil

### Geolocalización
- Solicitud automática de permisos
- Ubicación actual del usuario
- Botón "Mi ubicación" para centrar el mapa

### Oficinas Gubernamentales
- Marcadores de oficinas en Quito
- Información detallada al tocar marcadores
- Navegación a ubicaciones específicas

## Oficinas Incluidas

1. **SRI - La Mariscal** - Servicio de Rentas Internas
2. **Contraloría General del Estado** - Control gubernamental
3. **Agencia Nacional de Tránsito** - ANT
4. **Registro Civil** - Documentación personal
5. **Ministerio de Trabajo** - Relaciones laborales
6. **IESS** - Seguridad social

## Desarrollo

### Agregar nuevas oficinas

Edita `lib/data/mock_offices.dart` y agrega nuevas entradas al array `offices`:

```dart
OfficeLocation(
  name: 'Nombre de la oficina',
  description: 'Descripción y horarios',
  latitude: -0.1234,
  longitude: -78.5678,
),
```

### Personalizar el mapa

Modifica `lib/config/mapbox_config.dart` para cambiar:
- Estilo del mapa
- Coordenadas por defecto
- Configuración de zoom

## Requisitos del Sistema

- Flutter 3.x o superior
- Dart 3.x o superior
- Android SDK (para Android)
- Navegador web moderno (para Web)

## Licencia

Este proyecto es de código abierto y está disponible bajo la licencia MIT.