import 'dart:async';
import 'dart:math';

import 'google_maps_services.dart';
import 'models.dart';

class NavigationController {
  final GoogleRoutesService routesService;
  final StreamController<NavCue> _cueController =
      StreamController<NavCue>.broadcast();

  List<LatLng> _polyline = [];
  List<NavStep> _steps = [];
  int _stepIndex = 0;
  bool _spokenSoon = false;
  bool _spokenNow = false;
  int _offRouteCount = 0;
  DateTime? _lastReassurance;
  bool _rerouting = false;
  LatLng? _destination;

  NavigationController({required this.routesService});

  Stream<NavCue> get cues => _cueController.stream;

  bool get isNavigating => _steps.isNotEmpty;

  Future<void> start({
    required LatLng origin,
    required LatLng destination,
  }) async {
    _destination = destination;
    final route = await routesService.computeRoute(
      origin: origin,
      destination: destination,
    );
    _polyline = route.polyline;
    _steps = route.steps;
    _stepIndex = 0;
    _spokenSoon = false;
    _spokenNow = false;
    _offRouteCount = 0;
    _lastReassurance = DateTime.now();
    _emitCue('Pornim. Țin legătura cu tine.', priority: true);

    if (_steps.isNotEmpty) {
      _emitCue('Urmează: ${_steps.first.instruction}');
    }
  }

  void stop() {
    _polyline = [];
    _steps = [];
    _stepIndex = 0;
    _spokenSoon = false;
    _spokenNow = false;
    _offRouteCount = 0;
    _destination = null;
  }

  Future<void> onLocationUpdate(LatLng position) async {
    if (_steps.isEmpty || _polyline.isEmpty) {
      return;
    }

    final distanceFromRoute = _distanceToPolyline(position, _polyline);
    if (distanceFromRoute > 55) {
      _offRouteCount += 1;
    } else {
      _offRouteCount = 0;
    }

    if (_offRouteCount >= 3 && !_rerouting && _destination != null) {
      _rerouting = true;
      try {
        final route = await routesService.computeRoute(
          origin: position,
          destination: _destination!,
        );
        _polyline = route.polyline;
        _steps = route.steps;
        _stepIndex = 0;
        _spokenSoon = false;
        _spokenNow = false;
        _emitCue('Recalculez traseul.');
      } catch (_) {
      } finally {
        _offRouteCount = 0;
        _rerouting = false;
      }
      return;
    }

    if (_stepIndex >= _steps.length) {
      _emitCue('Ai ajuns. Rămân cu tine.', priority: true);
      stop();
      return;
    }

    final step = _steps[_stepIndex];
    final distToStep = _distanceMeters(position, step.endLocation);

    if (!_spokenSoon && distToStep <= 45 && distToStep > 12) {
      _spokenSoon = true;
      _emitCue('În ${_formatDistance(distToStep)}: ${step.instruction}');
    }

    if (!_spokenNow && distToStep <= 12) {
      _spokenNow = true;
      _emitCue('Acum: ${step.instruction}', priority: true);
    }

    if (distToStep <= 8) {
      _stepIndex += 1;
      _spokenSoon = false;
      _spokenNow = false;
      if (_stepIndex < _steps.length) {
        _emitCue('Bine. Urmează: ${_steps[_stepIndex].instruction}');
      } else {
        _emitCue('Ai ajuns. Rămân cu tine.', priority: true);
        stop();
      }
      return;
    }

    if (distToStep > 60) {
      final now = DateTime.now();
      final last =
          _lastReassurance ?? now.subtract(const Duration(seconds: 60));
      if (now.difference(last).inSeconds >= 18) {
        _lastReassurance = now;
        _emitCue(_reassuranceLine());
      }
    }
  }

  void _emitCue(String text, {bool priority = false}) {
    _cueController.add(NavCue(text: text, priority: priority));
  }

  String _reassuranceLine() {
    const lines = [
      'E ok, mai ai puțin. Sunt aici.',
      'Ține ritmul, ești pe traseu.',
      'Mergem bine, mai un pic.',
      'Ești bine, rămân cu tine.',
    ];
    return lines[DateTime.now().millisecondsSinceEpoch % lines.length];
  }

  double _distanceToPolyline(LatLng p, List<LatLng> polyline) {
    if (polyline.length < 2) return 0;
    double minDist = double.infinity;
    for (var i = 0; i < polyline.length - 1; i++) {
      final a = polyline[i];
      final b = polyline[i + 1];
      final dist = _distanceToSegmentMeters(p, a, b);
      if (dist < minDist) minDist = dist;
    }
    return minDist;
  }

  double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final ax = _lonToMeters(a.longitude, a.latitude);
    final ay = _latToMeters(a.latitude);
    final bx = _lonToMeters(b.longitude, b.latitude);
    final by = _latToMeters(b.latitude);
    final px = _lonToMeters(p.longitude, p.latitude);
    final py = _latToMeters(p.latitude);

    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) {
      return _distanceMeters(p, a);
    }
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final clamped = t.clamp(0.0, 1.0);
    final closestX = ax + clamped * dx;
    final closestY = ay + clamped * dy;
    final dxp = px - closestX;
    final dyp = py - closestY;
    return sqrt(dxp * dxp + dyp * dyp);
  }

  double _latToMeters(double lat) => lat * 111320.0;

  double _lonToMeters(double lon, double lat) {
    return lon * 111320.0 * cos(_degToRad(lat));
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final hav =
        sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(hav), sqrt(1 - hav));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * pi / 180.0;

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km km';
    }
    return '${meters.round()} m';
  }

  void dispose() {
    _cueController.close();
  }
}
