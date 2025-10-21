import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;

/// Estado de la ubicación del usuario
class LocationState {
  final geo.Position? currentPosition;
  final bool isLoading;
  final String? error;

  const LocationState({
    this.currentPosition,
    this.isLoading = false,
    this.error,
  });

  LocationState copyWith({
    geo.Position? currentPosition,
    bool? isLoading,
    String? error,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Notifier para manejar el estado de la ubicación
class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(const LocationState());

  /// Obtiene la posición actual del usuario
  Future<geo.Position?> getCurrentPosition() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          error: 'El servicio de ubicación está deshabilitado',
        );
        return null;
      }

      // Verificar permisos
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            error: 'Los permisos de ubicación fueron denegados',
          );
          return null;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          error: 'Los permisos de ubicación fueron denegados permanentemente',
        );
        return null;
      }

      // Obtener la posición actual
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      state = state.copyWith(
        currentPosition: position,
        isLoading: false,
        error: null,
      );

      return position;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al obtener la ubicación: $e',
      );
      return null;
    }
  }

  /// Actualiza la posición actual
  void updatePosition(geo.Position position) {
    state = state.copyWith(
      currentPosition: position,
      error: null,
    );
  }

  /// Limpia el error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Resetea el estado
  void reset() {
    state = const LocationState();
  }
}

/// Provider para el estado de ubicación
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);

/// Provider para obtener la posición actual
final currentPositionProvider = FutureProvider<geo.Position?>((ref) async {
  final locationNotifier = ref.read(locationProvider.notifier);
  return await locationNotifier.getCurrentPosition();
});
