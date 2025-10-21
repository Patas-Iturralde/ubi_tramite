# Instrucciones de Ejecución - UbiTrámite

## 🚀 Cómo ejecutar la aplicación

### 1. Instalar dependencias
```bash
flutter pub get
```

### 2. Ejecutar en Android
```bash
flutter run
```

### 3. Ejecutar en Web
```bash
flutter run -d web-server --web-port 8080
```

## 📱 Características Implementadas

### ✅ Completadas
- **Mapa interactivo** con Mapbox centrado en Quito, Ecuador
- **Geolocalización** del usuario con permisos
- **Botón "Mi ubicación"** para centrar el mapa
- **Interfaz moderna** con Material Design 3
- **Gestión de estado** con Riverpod
- **Manejo de errores** y estados de carga
- **Configuración de permisos** para Android

### 🏢 Oficinas Incluidas
- SRI - La Mariscal
- Contraloría General del Estado  
- Agencia Nacional de Tránsito
- Registro Civil
- Ministerio de Trabajo
- IESS

## 🔧 Configuración Técnica

### Token de Mapbox
El token ya está configurado en `lib/config/mapbox_config.dart`:
```
pk.eyJ1IjoiaGVybmFuLWl0dXJyYWxkZSIsImEiOiJjbWdpYWR4MmgwNzNoMmxvdmMyZzNseHNiIn0.tLctAoCsjPzIcp3kCD0QPQ
```

### Permisos Android
Configurados en `android/app/src/main/AndroidManifest.xml`:
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION` 
- `INTERNET`

## 🎯 Funcionalidades Principales

1. **Mapa Base**: Centrado en Quito con estilo Mapbox Streets
2. **Geolocalización**: Solicita permisos y obtiene ubicación del usuario
3. **Navegación**: Botón para centrar en ubicación actual
4. **Información**: Panel con lista de oficinas disponibles

## 📁 Estructura del Proyecto

```
lib/
├── config/
│   └── mapbox_config.dart          # Configuración de Mapbox
├── data/
│   └── mock_offices.dart           # Datos de oficinas
├── models/
│   └── office_location.dart       # Modelo de datos
├── providers/
│   └── location_provider.dart     # Provider de ubicación
├── screens/
│   └── map_screen.dart            # Pantalla principal
└── main.dart                      # Punto de entrada
```

## 🐛 Solución de Problemas

### Error de permisos
Si la aplicación no solicita permisos de ubicación:
1. Verificar que los permisos estén en `AndroidManifest.xml`
2. Reiniciar la aplicación
3. Verificar configuración del dispositivo

### Error de Mapbox
Si el mapa no carga:
1. Verificar conexión a internet
2. Verificar que el token sea válido
3. Revisar logs de la consola

## 🔄 Próximos Pasos

Para mejorar la aplicación, se pueden agregar:
- Marcadores interactivos en el mapa
- Búsqueda de oficinas
- Navegación GPS
- Información detallada de cada oficina
- Filtros por tipo de oficina

## 📞 Soporte

Para problemas técnicos, revisar:
1. Logs de Flutter: `flutter logs`
2. Análisis de código: `flutter analyze`
3. Tests: `flutter test`
