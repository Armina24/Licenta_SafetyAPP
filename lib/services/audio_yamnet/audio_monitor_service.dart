import 'package:flutter/foundation.dart';

import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'yamnet_service.dart';

class SoundAlertResult {
  final double tipete;
  final double aglomeratie;
  final double spargere;
  final bool isScream;
  final bool isCrowd;
  final bool isGlass;

  const SoundAlertResult({
    required this.tipete,
    required this.aglomeratie,
    required this.spargere,
    required this.isScream,
    required this.isCrowd,
    required this.isGlass,
  });

  @override
  String toString() {
    return 'SoundAlertResult(tipete=$tipete, aglomeratie=$aglomeratie, '
        'spargere=$spargere, isScream=$isScream, '
        'isCrowd=$isCrowd, isGlass=$isGlass)';
  }
}

class AudioMonitorService {
  AudioMonitorService._internal();
  static final AudioMonitorService instance = AudioMonitorService._internal();

  final FlutterAudioCapture _plugin = FlutterAudioCapture();

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  bool _audioInitialized = false;

  final List<double> _sampleBuffer = [];

  void Function(SoundAlertResult)? _onAlert;

  static const double _thrScream = 0.30;
  static const double _thrCrowd = 0.30;
  static const double _thrGlass = 0.25;

  static const double _thrScreamImmediate = 0.75;
  static const double _thrCrowdImmediate = 0.75;
  static const double _thrGlassImmediate = 0.70;

  static const int _screamWindows = 3;
  static const int _crowdWindows = 3;
  static const int _glassWindows = 1;

  int _screamCounter = 0;
  int _crowdCounter = 0;
  int _glassCounter = 0;

  static const int _frameSamples = 15600;

  Future<void> startMonitoring({
    required void Function(SoundAlertResult) onAlert,
  }) async {
    debugPrint(
      '🎙 AudioMonitorService.startMonitoring() chemat (isMonitoring=$_isMonitoring)',
    );
    if (_isMonitoring) return;

    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      debugPrint(
        'AudioMonitorService: microfon NEpermis.'
        'Cere permisiunea din UI înainte de a porni monitorizarea.',
      );
      return;
    }

    await YamnetService.instance.init();

    if (!_audioInitialized) {
      await _plugin.init();
      _audioInitialized = true;
      debugPrint('AudioMonitorService: flutter_audio_capture INIT done.');
    }

    _onAlert = onAlert;
    _isMonitoring = true;

    debugPrint('AudioMonitorService: START (flutter_audio_capture).');

    await _plugin.start(
      _audioListener,
      _onError,
      sampleRate: 16000,
      bufferSize: 3000,
    );
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    await _plugin.stop();
    _isMonitoring = false;
    _sampleBuffer.clear();
    _screamCounter = 0;
    _crowdCounter = 0;
    _glassCounter = 0;

    debugPrint('AudioMonitorService: STOP.');
  }

  void _audioListener(dynamic obj) async {
    if (!_isMonitoring) return;

    final Float64List buffer = Float64List.fromList(obj.cast<double>());

    for (final v in buffer) {
      _sampleBuffer.add(v.toDouble());
    }

    while (_sampleBuffer.length >= _frameSamples) {
      final frame = _sampleBuffer.sublist(0, _frameSamples);
      _sampleBuffer.removeRange(0, _frameSamples);

      await _analyzeFrame(frame);
    }
  }

  void _onError(Object e) {
    debugPrint('AudioMonitorService: eroare din flutter_audio_capture: $e');
  }

  Future<void> _analyzeFrame(List<double> frame) async {
    final scores = await YamnetService.instance.classify(frame);

    final double sScream = scores['tipete'] ?? 0.0;
    final double sCrowd = scores['aglomeratie'] ?? 0.0;
    final double sGlass = scores['spargere'] ?? 0.0;

    if (sScream > _thrScream) {
      _screamCounter++;
    } else {
      _screamCounter = 0;
    }

    if (sCrowd > _thrCrowd) {
      _crowdCounter++;
    } else {
      _crowdCounter = 0;
    }

    if (sGlass > _thrGlass) {
      _glassCounter++;
    } else {
      _glassCounter = 0;
    }

    final bool isScream =
        _screamCounter >= _screamWindows || sScream >= _thrScreamImmediate;
    final bool isCrowd =
        _crowdCounter >= _crowdWindows || sCrowd >= _thrCrowdImmediate;
    final bool isGlass =
        _glassCounter >= _glassWindows || sGlass >= _thrGlassImmediate;

    final result = SoundAlertResult(
      tipete: sScream,
      aglomeratie: sCrowd,
      spargere: sGlass,
      isScream: isScream,
      isCrowd: isCrowd,
      isGlass: isGlass,
    );

    debugPrint('AudioMonitorService frame -> $result');

    if ((isScream || isCrowd || isGlass) && _onAlert != null) {
      _onAlert!(result);
    }
  }
}
