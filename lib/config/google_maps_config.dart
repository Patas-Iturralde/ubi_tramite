/// Configuración de Google Maps para la versión web
class GoogleMapsConfig {
  /// API Key de Google Maps
  /// IMPORTANTE: Reemplaza esto con tu propia API key de Google Maps
  /// Obtén una en: https://console.cloud.google.com/google/maps-apis
  static const String apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  
  /// Coordenadas por defecto (Riobamba, Ecuador)
  static const double defaultLatitude = -1.6715;
  static const double defaultLongitude = -78.6485;
  static const double defaultZoom = 14.0;
  
  /// Estilos de mapa
  static const String defaultMapType = 'roadmap';
  static const String satelliteMapType = 'satellite';
  static const String terrainMapType = 'terrain';
}

