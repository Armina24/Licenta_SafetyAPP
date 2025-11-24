// lib/services/location_service.dart
import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();

  /// Verifică și cere permisiunea de locație.
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Ideal: arată un dialog în UI, dar aici doar returnăm false
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// O singură citire a poziției curente cu un fallback opțional la ultima
  /// locație cunoscută. Returnează un [LocationReading] ce descrie rezultatul.
  Future<LocationReading> acquireLocation({
    Duration timeout = const Duration(seconds: 12),
    bool allowLastKnownFallback = true,
  }) async {
    final permissionOk = await ensurePermission();
    if (!permissionOk) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationReading(
          error: LocationFailure.serviceDisabled,
          errorMessage:
              'Serviciile de locație sunt dezactivate. Activează GPS-ul și încearcă din nou.',
        );
      }
      return const LocationReading(
        error: LocationFailure.permissionDenied,
        errorMessage:
            'Permisiunea de locație este necesară pentru a obține poziția curentă.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);
      return LocationReading(
        position: position,
        usedLastKnownPosition: false,
      );
    } on TimeoutException {
      // Continuăm către fallback la ultima locație cunoscută.
    } on LocationServiceDisabledException {
      return const LocationReading(
        error: LocationFailure.serviceDisabled,
        errorMessage:
            'Serviciile de locație sunt dezactivate. Activează GPS-ul și încearcă din nou.',
      );
    } on PermissionDeniedException {
      return const LocationReading(
        error: LocationFailure.permissionDenied,
        errorMessage:
            'Permisiunea de locație a fost refuzată. Poți permite accesul din setările telefonului.',
      );
    } catch (_) {
      // Trecem la fallback.
    }

    if (!allowLastKnownFallback) {
      return const LocationReading(
        error: LocationFailure.unavailable,
        errorMessage:
            'Nu am putut obține poziția curentă. Încearcă din nou în câteva momente.',
      );
    }

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return LocationReading(
          position: lastKnown,
          usedLastKnownPosition: true,
        );
      }
    } catch (_) {
      // Ignorăm și continuăm către eroare.
    }

    return const LocationReading(
      error: LocationFailure.unavailable,
      errorMessage:
          'Nu am putut obține nicio locație. Verifică semnalul GPS și încearcă din nou.',
    );
  }

  /// O singură citire a poziției curente.
  Future<Position?> getCurrentPosition() async {
    final reading = await acquireLocation();
    return reading.position;
  }

  /// Stream cu update-uri de locație (se emite când te miști).
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 10,
  }) {
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

/// Reprezintă rezultatul unei cereri de locație.
class LocationReading {
  final Position? position;
  final bool usedLastKnownPosition;
  final LocationFailure? error;
  final String? errorMessage;

  const LocationReading({
    this.position,
    this.usedLastKnownPosition = false,
    this.error,
    this.errorMessage,
  });

  bool get isSuccess => position != null;
}

enum LocationFailure {
  permissionDenied,
  serviceDisabled,
  timeout,
  unavailable,
}
