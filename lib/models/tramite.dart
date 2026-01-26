/// Modelo de datos para representar un trámite con sus requisitos y costos
class Tramite {
  final String nombre;
  final List<String> requisitos;
  final String? costo; // Puede ser "Gratis", "$10.00", "Variable", etc.
  final String? descripcion; // Descripción adicional del trámite

  const Tramite({
    required this.nombre,
    this.requisitos = const [],
    this.costo,
    this.descripcion,
  });

  /// Crea un Tramite desde un Map (JSON)
  factory Tramite.fromJson(Map<String, dynamic> json) {
    final requisitosData = json['requisitos'];
    List<String> requisitos = [];
    if (requisitosData != null && requisitosData is List) {
      requisitos = requisitosData.map((e) => e.toString()).toList();
    }

    return Tramite(
      nombre: json['nombre'] as String? ?? '',
      requisitos: requisitos,
      costo: json['costo'] as String?,
      descripcion: json['descripcion'] as String?,
    );
  }

  /// Convierte el objeto a un Map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'requisitos': requisitos,
      if (costo != null) 'costo': costo,
      if (descripcion != null) 'descripcion': descripcion,
    };
  }

  /// Crea un Tramite desde un String (para compatibilidad con datos antiguos)
  factory Tramite.fromString(String nombre) {
    return Tramite(nombre: nombre);
  }

  /// Convierte a String (para compatibilidad con código existente)
  @override
  String toString() => nombre;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tramite && other.nombre == nombre;
  }

  @override
  int get hashCode => nombre.hashCode;
}

