import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Advanced shake detection service that distinguishes between:
/// - Rhythmic movement (running/jogging) - ignored
/// - Sudden impacts (falls) - dangerous
/// - Chaotic multi-axis movement (struggles) - dangerous
class ShakeDetectionService {
  ShakeDetectionService._internal();
  static final ShakeDetectionService instance = ShakeDetectionService._internal();

  // Configuration parameters
  static const double _impactThreshold = 25.0; // G-force threshold for falls
  static const double _chaoticMovementThreshold = 15.0; // G-force for struggle
  static const int _accelerometerSampleBufferSize = 50; // samples to keep for analysis

  // State
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  final List<AccelerometerSample> _sampleBuffer = [];
  bool _isListening = false;
  DateTime? _lastDangerousEventTime;
  static const Duration _minEventInterval = Duration(seconds: 3); // debounce

  // Callbacks
  Function(ShakeDangerType)? _onDangerousShakeDetected;

  /// Start listening to accelerometer data
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

  /// Stop listening to accelerometer data
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
      magnitude: sqrt(event.x * event.x + event.y * event.y + event.z * event.z),
    );

    _sampleBuffer.add(sample);
    if (_sampleBuffer.length > _accelerometerSampleBufferSize) {
      _sampleBuffer.removeAt(0);
    }

    // Check for dangerous patterns
    _analyzeMovementPattern();
  }

  void _analyzeMovementPattern() {
    if (_sampleBuffer.length < 10) return;

    final now = DateTime.now();
    
    // Debounce: don't trigger multiple events too quickly
    if (_lastDangerousEventTime != null) {
      if (now.difference(_lastDangerousEventTime!) < _minEventInterval) {
        return;
      }
    }

    // Check for sudden impact (fall detection)
    if (_detectSuddenImpact()) {
      _triggerDangerousEvent(ShakeDangerType.suddenImpact);
      return;
    }

    // Check for chaotic movement (struggle detection)
    if (_detectChaoticMovement()) {
      _triggerDangerousEvent(ShakeDangerType.chaoticMovement);
      return;
    }
  }

  /// Detects sudden, high-G impact followed by orientation change (typical of falls)
  bool _detectSuddenImpact() {
    // Get the latest few samples
    if (_sampleBuffer.length < 5) return false;

    final recent = _sampleBuffer.sublist(max(0, _sampleBuffer.length - 5));
    final maxMagnitude = recent.map((s) => s.magnitude).reduce(max);

    if (maxMagnitude < _impactThreshold) {
      return false;
    }

    // Check if there's a sudden spike (not gradual increase)
    if (recent.length >= 2) {
      final previousAvg = recent.sublist(0, recent.length - 1)
          .map((s) => s.magnitude)
          .reduce((a, b) => a + b) / (recent.length - 1);
      final latestMagnitude = recent.last.magnitude;

      // Sudden spike: current is significantly higher than recent average
      if (latestMagnitude > previousAvg * 1.5) {
        return true;
      }
    }

    return false;
  }

  /// Detects rapid, chaotic multi-axis movement (struggle or attack)
  bool _detectChaoticMovement() {
    if (_sampleBuffer.length < 10) return false;

    // Analyze variance across all axes to detect chaotic, uncoordinated movement
    final recentSamples = _sampleBuffer.sublist(max(0, _sampleBuffer.length - 10));

    // Calculate per-axis variance
    double calculateVariance(List<double> values) {
      if (values.isEmpty) return 0;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final sumSquaredDiff =
          values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b);
      return sumSquaredDiff / values.length;
    }

    final xValues = recentSamples.map((s) => s.x).toList();
    final yValues = recentSamples.map((s) => s.y).toList();
    final zValues = recentSamples.map((s) => s.z).toList();

    final xVariance = calculateVariance(xValues);
    final yVariance = calculateVariance(yValues);
    final zVariance = calculateVariance(zValues);

    // Check if movement is happening across all axes (not just rhythmic in one axis)
    final totalVariance = xVariance + yVariance + zVariance;
    
    // Also check if any axis has high magnitude and variance
    final anyHighMovement = recentSamples.any((s) => s.magnitude > _chaoticMovementThreshold);

    // Chaotic movement: high variance across multiple axes + high magnitude
    if (totalVariance > 50 && anyHighMovement && _isMultiAxisMovement(recentSamples)) {
      // Additional check: is this NOT rhythmic (running)?
      if (!_isRhythmicMovement(recentSamples)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if movement is happening across multiple axes (not just one)
  bool _isMultiAxisMovement(List<AccelerometerSample> samples) {
    int axesWithSignificantVariance = 0;

    double calculateVariance(List<double> values) {
      if (values.isEmpty) return 0;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final sumSquaredDiff =
          values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b);
      return sumSquaredDiff / values.length;
    }

    if (calculateVariance(samples.map((s) => s.x).toList()) > 5) axesWithSignificantVariance++;
    if (calculateVariance(samples.map((s) => s.y).toList()) > 5) axesWithSignificantVariance++;
    if (calculateVariance(samples.map((s) => s.z).toList()) > 5) axesWithSignificantVariance++;

    return axesWithSignificantVariance >= 2;
  }

  /// Detects if movement is rhythmic (running/jogging) - should be ignored
  bool _isRhythmicMovement(List<AccelerometerSample> samples) {
    if (samples.length < 8) return false;

    // Rhythmic movement typically has:
    // 1. Repeating peaks at regular intervals
    // 2. Lower overall variance compared to chaotic movement
    // 3. Dominant in vertical axis (Z)

    final magnitudes = samples.map((s) => s.magnitude).toList();

    // Find peaks (local maxima)
    final peaks = <int>[];
    for (int i = 1; i < magnitudes.length - 1; i++) {
      if (magnitudes[i] > magnitudes[i - 1] && magnitudes[i] > magnitudes[i + 1]) {
        peaks.add(i);
      }
    }

    // Rhythmic movement should have multiple regular peaks
    if (peaks.length < 2) return false;

    // Check if peaks are somewhat regularly spaced (running cadence ~1-2 samples apart)
    final peakIntervals = <int>[];
    for (int i = 1; i < peaks.length; i++) {
      peakIntervals.add(peaks[i] - peaks[i - 1]);
    }

    if (peakIntervals.isEmpty) return false;

    final avgInterval = peakIntervals.reduce((a, b) => a + b) / peakIntervals.length;
    final intervalVariance =
        peakIntervals.map((v) => pow(v - avgInterval, 2)).reduce((a, b) => a + b) /
            peakIntervals.length;

    // Regular spacing indicates rhythmic movement
    return intervalVariance < avgInterval; // Low relative variance = regular pattern
  }

  void _triggerDangerousEvent(ShakeDangerType dangerType) {
    _lastDangerousEventTime = DateTime.now();
    _onDangerousShakeDetected?.call(dangerType);
  }
}

/// Type of dangerous shake detected
enum ShakeDangerType {
  suddenImpact, // Fall or hard bump
  chaoticMovement, // Struggle or attack
}

/// Represents a single accelerometer sample
class AccelerometerSample {
  final double x;
  final double y;
  final double z;
  final double magnitude; // Overall G-force
  final DateTime timestamp;

  AccelerometerSample({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.timestamp,
  });
}
