import 'package:flutter/foundation.dart';

import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

import 'yamnet_service.dart';

/// Rezultat pe care îl primește UI-ul la fiecare "alertă".
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

  // buffer de sample-uri pentru YAMNet
  final List<double> _sampleBuffer = [];

  // callback-ul pe care îl dăm din UI
  void Function(SoundAlertResult)? _onAlert;

  // praguri (poți să le ajustezi ulterior)
  static const double _thrScream = 0.6;
  static const double _thrCrowd = 0.6;
  static const double _thrGlass = 0.7;

  // câte ferestre consecutive trebuie să fie peste prag
  static const int _screamWindows = 3;
  static const int _crowdWindows = 3;
  static const int _glassWindows = 1;

  int _screamCounter = 0;
  int _crowdCounter = 0;
  int _glassCounter = 0;

  // dimensiunea așteptată de YAMNet (din testele tale: 15600)
  static const int _frameSamples = 15600;

  Future<void> startMonitoring({
    required void Function(SoundAlertResult) onAlert,
  }) async {
    debugPrint('🎙 AudioMonitorService.startMonitoring() chemat (isMonitoring=$_isMonitoring)');
    if (_isMonitoring) return;

    // 1. permisiune microfon
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      debugPrint('AudioMonitorService: microfon NEpermis.'
        'Cere permisiunea din UI înainte de a porni monitorizarea.',);
      return;
    }

    // 2. init YAMNet (dacă nu e deja)
    await YamnetService.instance.init();

    // 3. init pluginul audio o singură dată
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
      sampleRate: 16000, // exact cât vrea YAMNet
      bufferSize: 3000,  // doar pentru iOS, la Android e ignorat
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

  /// Listener-ul chemat de flutter_audio_capture pentru fiecare chunk.
  void _audioListener(dynamic obj) async {
    if (!_isMonitoring) return;

    // pluginul trimite Float64List dynamic → îl convertim
    final Float64List buffer = Float64List.fromList(obj.cast<double>());

    // adăugăm în bufferul mare
    for (final v in buffer) {
      _sampleBuffer.add(v.toDouble());
    }

    // cât timp avem destule sample-uri pentru o fereastră YAMNet
    while (_sampleBuffer.length >= _frameSamples) {
      final frame = _sampleBuffer.sublist(0, _frameSamples);
      _sampleBuffer.removeRange(0, _frameSamples);

      await _analyzeFrame(frame);
    }
  }

  void _onError(Object e) {
    debugPrint('AudioMonitorService: eroare din flutter_audio_capture: $e');
  }

  /// Rulează YAMNet pe o fereastră și verifică pragurile.
  Future<void> _analyzeFrame(List<double> frame) async {
    final scores = await YamnetService.instance.classify(frame);

    final double sScream = scores['tipete'] ?? 0.0;
    final double sCrowd = scores['aglomeratie'] ?? 0.0;
    final double sGlass = scores['spargere'] ?? 0.0;

    // update contoare
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

    final bool isScream = _screamCounter >= _screamWindows;
    final bool isCrowd = _crowdCounter >= _crowdWindows;
    final bool isGlass = _glassCounter >= _glassWindows;

    final result = SoundAlertResult(
      tipete: sScream,
      aglomeratie: sCrowd,
      spargere: sGlass,
      isScream: isScream,
      isCrowd: isCrowd,
      isGlass: isGlass,
    );

    // pur debug, poți comenta dacă e spam:
    debugPrint('AudioMonitorService frame -> $result');

    if ((isScream || isCrowd || isGlass) && _onAlert != null) {
      _onAlert!(result);
    }
  }
}
