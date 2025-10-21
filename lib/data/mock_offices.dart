import '../models/office_location.dart';

/// Datos mock de oficinas gubernamentales en Riobamba, Ecuador
class MockOffices {
  static final List<OfficeLocation> offices = [
    OfficeLocation(
      name: 'SRI - Riobamba',
      description: 'Servicio de Rentas Internas - Riobamba\nAv. Daniel León Borja y Av. 10 de Agosto\nHorario: Lunes a Viernes 8:00-16:30',
      latitude: -1.6708,
      longitude: -78.6478,
    ),
    OfficeLocation(
      name: 'Gobierno Provincial de Chimborazo',
      description: 'Gobierno Provincial de Chimborazo\nAv. Daniel León Borja y Av. 10 de Agosto\nHorario: Lunes a Viernes 8:00-17:00',
      latitude: -1.6715,
      longitude: -78.6485,
    ),
    OfficeLocation(
      name: 'ANT - Riobamba',
      description: 'Agencia Nacional de Tránsito - Riobamba\nAv. Daniel León Borja y Av. 10 de Agosto\nHorario: Lunes a Viernes 8:00-16:00',
      latitude: -1.6720,
      longitude: -78.6490,
    ),
    OfficeLocation(
      name: 'Registro Civil - Riobamba',
      description: 'Registro Civil - Riobamba\nAv. Daniel León Borja y Av. 10 de Agosto\nHorario: Lunes a Viernes 8:00-16:30',
      latitude: -1.6725,
      longitude: -78.6495,
    ),
    OfficeLocation(
      name: 'Ministerio de Trabajo - Riobamba',
      description: 'Ministerio de Relaciones Laborales - Riobamba\nAv. Daniel León Borja y Av. 10 de Agosto\nHorario: Lunes a Viernes 8:00-17:00',
      latitude: -1.6730,
      longitude: -78.6500,
    ),
    OfficeLocation(
      name: 'IESS - Riobamba',
      description: 'Instituto Ecuatoriano de Seguridad Social - Riobamba\nAv. Daniel León Borja y Av. 10 de Agosto\nHorario: Lunes a Viernes 8:00-16:30',
      latitude: -1.6735,
      longitude: -78.6505,
    ),
  ];

  /// Obtiene todas las oficinas disponibles
  static List<OfficeLocation> getAllOffices() {
    return List.from(offices);
  }

  /// Busca oficinas por nombre (búsqueda parcial)
  static List<OfficeLocation> searchOffices(String query) {
    if (query.isEmpty) return getAllOffices();
    
    return offices.where((office) {
      return office.name.toLowerCase().contains(query.toLowerCase()) ||
             office.description.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }
}
