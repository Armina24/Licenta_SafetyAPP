import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetectionService {
  ShakeDetectionService._internal();
  static final ShakeDetectionService instance =
      ShakeDetectionService._internal();

  static const double _impactThreshold = 25.0;
  static const double _chaoticMovementThreshold = 15.0;
  static const int _accelerometerSampleBufferSize = 50;

  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  final List<AccelerometerSample> _sampleBuffer = [];
  bool _isListening = false;
  DateTime? _lastDangerousEventTime;
  static const Duration _minEventInterval = Duration(seconds: 3);

  Function(ShakeDangerType)? _onDangerousShakeDetected;

  void startListening({required Function(ShakeDangerType) onDangerousShake}) {
    if (_isListening) return;
    _isListening = true;
    _onDangerousShakeDetected = onDangerousShake;
    _sampleBuffer.clear();
    _lastDangerousEventTime = null;

    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      _processAccelerometerEvent(event);
    });
  }

  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    _accelerometerSubscription.cancel();
    _sampleBuffer.clear();
  }

  void _processAccelerometerEvent(AccelerometerEvent event) {
    final now = DateTime.now();
    final sample = AccelerometerSample(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: now,
      magnitude: sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      ),
    );

    _sampleBuffer.add(sample);
    if (_sampleBuffer.length > _accelerometerSampleBufferSize) {
      _sampleBuffer.removeAt(0);
    }

    _analyzeMovementPattern();
  }

  void _analyzeMovementPattern() {
    if (_sampleBuffer.length < 10) return;

    final now = DateTime.now();

    if (_lastDangerousEventTime != null) {
      if (now.difference(_lastDangerousEventTime!) < _minEventInterval) {
        return;
      }
    }

    if (_detectSuddenImpact()) {
      _triggerDangerousEvent(ShakeDangerType.suddenImpact);
      return;
    }

    if (_detectChaoticMovement()) {
      _triggerDangerousEvent(ShakeDangerType.chaoticMovement);
      return;
    }
  }

  bool _detectSuddenImpact() {
    if (_sampleBuffer.length < 5) return false;

    final recent = _sampleBuffer.sublist(max(0, _sampleBuffer.length - 5));
    final maxMagnitude = recent.map((s) => s.magnitude).reduce(max);

    if (maxMagnitude < _impactThreshold) {
      return false;
    }

    if (recent.length >= 2) {
      final previousAvg =
          recent
              .sublist(0, recent.length - 1)
              .map((s) => s.magnitude)
              .reduce((a, b) => a + b) /
          (recent.length - 1);
      final latestMagnitude = recent.last.magnitude;

      if (latestMagnitude > previousAvg * 1.5) {
        return true;
      }
    }

    return false;
  }

  bool _detectChaoticMovement() {
    if (_sampleBuffer.length < 10) return false;

    final recentSamples = _sampleBuffer.sublist(
      max(0, _sampleBuffer.length - 10),
    );

    double calculateVariance(List<double> values) {
      if (values.isEmpty) return 0;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final sumSquaredDiff = values
          .map((v) => pow(v - mean, 2))
          .reduce((a, b) => a + b);
      return sumSquaredDiff / values.length;
    }

    final xValues = recentSamples.map((s) => s.x).toList();
    final yValues = recentSamples.map((s) => s.y).toList();
    final zValues = recentSamples.map((s) => s.z).toList();

    final xVariance = calculateVariance(xValues);
    final yVariance = calculateVariance(yValues);
    final zVariance = calculateVariance(zValues);

    final totalVariance = xVariance + yVariance + zVariance;

    final anyHighMovement = recentSamples.any(
      (s) => s.magnitude > _chaoticMovementThreshold,
    );

    if (totalVariance > 50 &&
        anyHighMovement &&
        _isMultiAxisMovement(recentSamples)) {
      if (!_isRhythmicMovement(recentSamples)) {
        return true;
      }
    }

    return false;
  }

  bool _isMultiAxisMovement(List<AccelerometerSample> samples) {
    int axesWithSignificantVariance = 0;

    double calculateVariance(List<double> values) {
      if (values.isEmpty) return 0;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final sumSquaredDiff = values
          .map((v) => pow(v - mean, 2))
          .reduce((a, b) => a + b);
      return sumSquaredDiff / values.length;
    }

    if (calculateVariance(samples.map((s) => s.x).toList()) > 5)
      axesWithSignificantVariance++;
    if (calculateVariance(samples.map((s) => s.y).toList()) > 5)
      axesWithSignificantVariance++;
    if (calculateVariance(samples.map((s) => s.z).toList()) > 5)
      axesWithSignificantVariance++;

    return axesWithSignificantVariance >= 2;
  }

  bool _isRhythmicMovement(List<AccelerometerSample> samples) {
    if (samples.length < 8) return false;

    final magnitudes = samples.map((s) => s.magnitude).toList();

    final peaks = <int>[];
    for (int i = 1; i < magnitudes.length - 1; i++) {
      if (magnitudes[i] > magnitudes[i - 1] &&
          magnitudes[i] > magnitudes[i + 1]) {
        peaks.add(i);
      }
    }

    if (peaks.length < 2) return false;

    final peakIntervals = <int>[];
    for (int i = 1; i < peaks.length; i++) {
      peakIntervals.add(peaks[i] - peaks[i - 1]);
    }

    if (peakIntervals.isEmpty) return false;

    final avgInterval =
        peakIntervals.reduce((a, b) => a + b) / peakIntervals.length;
    final intervalVariance =
        peakIntervals
            .map((v) => pow(v - avgInterval, 2))
            .reduce((a, b) => a + b) /
        peakIntervals.length;

    return intervalVariance < avgInterval;
  }

  void _triggerDangerousEvent(ShakeDangerType dangerType) {
    _lastDangerousEventTime = DateTime.now();
    _onDangerousShakeDetected?.call(dangerType);
  }
}

enum ShakeDangerType { suddenImpact, chaoticMovement }

class AccelerometerSample {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  AccelerometerSample({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });
}
