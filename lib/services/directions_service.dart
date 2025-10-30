import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/mapbox_config.dart';

class DirectionsService {
  static Future<List<List<double>>> getRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/'
      '$originLng,$originLat;$destLng,$destLat'
      '?alternatives=false&geometries=geojson&overview=full&steps=false&access_token=${MapboxConfig.accessToken}',
    );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Error al obtener ruta (${resp.statusCode})');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?
        ?? (throw Exception('Sin rutas disponibles'));
    if (routes.isEmpty) throw Exception('Sin rutas disponibles');
    final geometry = routes.first['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List)
        .map<List<double>>((c) => [(c[1] as num).toDouble(), (c[0] as num).toDouble()])
        .toList();
    return coords; // [lat, lng]
  }
}


