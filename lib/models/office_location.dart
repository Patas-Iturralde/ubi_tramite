// Importa el paquete para generar IDs únicos
import 'package:uuid/uuid.dart';
import 'place_category.dart';

/// Modelo de datos para representar una ubicación de oficina gubernamental
class OfficeLocation {
  /// Un identificador único para cada oficina.
  final String id;
  final String name;
  final String description;
  final String? schedule;
  final double latitude;
  final double longitude;
  final PlaceCategory category;

  /// Constructor. Si no se provee un 'id', se genera uno automáticamente.
  OfficeLocation({
    String? id,
    required this.name,
    required this.description,
    this.schedule,
    required this.latitude,
    required this.longitude,
    this.category = PlaceCategory.publicInstitutions,
  }) : id = id ?? const Uuid().v4();

  /// Crea una copia del objeto con la posibilidad de modificar algunos campos.
  OfficeLocation copyWith({
    String? id,
    String? name,
    String? description,
    String? schedule,
    double? latitude,
    double? longitude,
    PlaceCategory? category,
  }) {
    return OfficeLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      schedule: schedule ?? this.schedule,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
    );
  }

  /// Convierte el objeto a un Map (JSON). Requerido por la pantalla del mapa.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'schedule': schedule,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.storageValue,
    };
  }

  /// Crea un objeto OfficeLocation desde un Map (JSON). Requerido por la pantalla del mapa.
  factory OfficeLocation.fromJson(Map<String, dynamic> json) {
    return OfficeLocation(
      id: json['id'] as String?,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      schedule: json['schedule'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      category: PlaceCategoryX.fromStorageValue(json['category'] as String?),
    );
  }

  @override
  String toString() {
    return 'OfficeLocation(id: $id, name: $name, description: $description, schedule: $schedule, lat: $latitude, lng: $longitude, category: ${category.storageValue})';
  }

  /// La igualdad se basa únicamente en el 'id' único.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfficeLocation && other.id == id;
  }

  /// El hashCode se basa únicamente en el 'id' único.
  @override
  int get hashCode {
    return id.hashCode;
  }
}