import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/office_location.dart';
import '../services/local_storage_service.dart';
import '../services/firestore_service.dart';

/// Estado de las oficinas (predeterminadas + personalizadas)
class OfficesState {
  final List<OfficeLocation> offices;
  final bool isLoading;
  final String? error;

  const OfficesState({
    this.offices = const [],
    this.isLoading = false,
    this.error,
  });

  OfficesState copyWith({
    List<OfficeLocation>? offices,
    bool? isLoading,
    String? error,
  }) {
    return OfficesState(
      offices: offices ?? this.offices,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier para manejar el estado de las oficinas
class OfficesNotifier extends StateNotifier<OfficesState> {
  OfficesNotifier() : super(const OfficesState()) {
    loadOffices();
  }

  /// Carga todas las oficinas (predeterminadas + personalizadas)
  Future<void> loadOffices() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      // Cargar desde Firestore; si falla, usar almacenamiento local como respaldo
      List<OfficeLocation> offices;
      try {
        offices = await FirestoreService.getAllOffices();
      } catch (_) {
        offices = await LocalStorageService.getAllOffices();
      }
      
      state = state.copyWith(
        offices: offices,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar oficinas: $e',
      );
    }
  }

  /// Agrega una nueva oficina personalizada
  Future<bool> addCustomOffice(OfficeLocation office) async {
    try {
      bool success;
      try {
        success = await FirestoreService.saveCustomOffice(office);
      } catch (_) {
        success = await LocalStorageService.saveCustomOffice(office);
      }
      
      if (success) {
        // Recargar la lista de oficinas
        await loadOffices();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Error al agregar oficina: $e');
      return false;
    }
  }

  /// Elimina una oficina personalizada
  Future<bool> deleteCustomOffice(String officeName) async {
    try {
      bool success;
      try {
        success = await FirestoreService.deleteCustomOfficeByName(officeName);
      } catch (_) {
        success = await LocalStorageService.deleteCustomOffice(officeName);
      }
      
      if (success) {
        // Recargar la lista de oficinas
        await loadOffices();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar oficina: $e');
      return false;
    }
  }

  /// Limpia todas las oficinas personalizadas
  Future<bool> clearCustomOffices() async {
    try {
      bool success;
      try {
        success = await FirestoreService.clearCustomOffices();
      } catch (_) {
        success = await LocalStorageService.clearCustomOffices();
      }
      
      if (success) {
        // Recargar la lista de oficinas
        await loadOffices();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Error al limpiar oficinas: $e');
      return false;
    }
  }

  /// Busca oficinas por nombre o descripción
  List<OfficeLocation> searchOffices(String query) {
    if (query.isEmpty) return state.offices;
    
    return state.offices.where((office) {
      final q = query.toLowerCase();
      return office.name.toLowerCase().contains(q) ||
             office.description.toLowerCase().contains(q) ||
             (office.schedule?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}

/// Provider para el estado de oficinas
final officesProvider = StateNotifierProvider<OfficesNotifier, OfficesState>(
  (ref) => OfficesNotifier(),
);

/// Provider para obtener solo las oficinas personalizadas
final customOfficesProvider = FutureProvider<List<OfficeLocation>>((ref) async {
  return await LocalStorageService.getCustomOffices();
});
