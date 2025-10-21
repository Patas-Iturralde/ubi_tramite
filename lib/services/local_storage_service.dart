import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/office_location.dart';
import '../data/mock_offices.dart';

/// Servicio para manejar el almacenamiento local de ubicaciones personalizadas
class LocalStorageService {
  static const String _customOfficesKey = 'custom_offices';
  
  /// Obtiene todas las oficinas personalizadas guardadas
  static Future<List<OfficeLocation>> getCustomOffices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? officesJson = prefs.getString(_customOfficesKey);
      
      if (officesJson == null || officesJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> officesList = json.decode(officesJson);
      return officesList
          .map((json) => OfficeLocation.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error al cargar oficinas personalizadas: $e');
      return [];
    }
  }
  
  /// Guarda una nueva oficina personalizada
  static Future<bool> saveCustomOffice(OfficeLocation office) async {
    try {
      final List<OfficeLocation> existingOffices = await getCustomOffices();
      existingOffices.add(office);
      
      final List<Map<String, dynamic>> officesJson = 
          existingOffices.map((office) => office.toJson()).toList();
      
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_customOfficesKey, json.encode(officesJson));
    } catch (e) {
      debugPrint('Error al guardar oficina personalizada: $e');
      return false;
    }
  }
  
  /// Elimina una oficina personalizada por ID
  static Future<bool> deleteCustomOffice(String officeId) async {
    try {
      final List<OfficeLocation> existingOffices = await getCustomOffices();
      existingOffices.removeWhere((office) => office.name == officeId);
      
      final List<Map<String, dynamic>> officesJson = 
          existingOffices.map((office) => office.toJson()).toList();
      
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_customOfficesKey, json.encode(officesJson));
    } catch (e) {
      debugPrint('Error al eliminar oficina personalizada: $e');
      return false;
    }
  }
  
  /// Limpia todas las oficinas personalizadas
  static Future<bool> clearCustomOffices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_customOfficesKey);
    } catch (e) {
      debugPrint('Error al limpiar oficinas personalizadas: $e');
      return false;
    }
  }
  
  /// Obtiene todas las oficinas (predeterminadas + personalizadas)
  static Future<List<OfficeLocation>> getAllOffices() async {
    try {
      final List<OfficeLocation> defaultOffices = MockOffices.getAllOffices();
      final List<OfficeLocation> customOffices = await getCustomOffices();
      
      return [...defaultOffices, ...customOffices];
    } catch (e) {
      debugPrint('Error al obtener todas las oficinas: $e');
      return MockOffices.getAllOffices();
    }
  }
}
