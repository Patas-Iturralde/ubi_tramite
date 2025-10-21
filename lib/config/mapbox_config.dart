/// Configuración de Mapbox para la aplicación UbiTrámite
class MapboxConfig {
  /// Token de acceso público de Mapbox
  /// IMPORTANTE: En producción, considera usar variables de entorno
  static const String accessToken = 'pk.eyJ1IjoiaGVybmFuLWl0dXJyYWxkZSIsImEiOiJjbWdpYWR4MmgwNzNoMmxvdmMyZzNseHNiIn0.tLctAoCsjPzIcp3kCD0QPQ';
  
  /// Estilo de mapa por defecto
  static const String defaultStyle = 'mapbox://styles/mapbox/streets-v12';
  
  /// Coordenadas por defecto (Riobamba, Ecuador)
  static const double defaultLatitude = -1.6715;
  static const double defaultLongitude = -78.6485;
  static const double defaultZoom = 14.0;
  
  /// Configuración de animaciones
  static const Duration defaultAnimationDuration = Duration(milliseconds: 1500);
  
  /// Configuración de zoom para diferentes contextos
  static const double cityZoom = 12.0;
  static const double streetZoom = 16.0;
  static const double buildingZoom = 18.0;
}
