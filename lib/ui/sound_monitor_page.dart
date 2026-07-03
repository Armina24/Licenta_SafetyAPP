import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_yamnet/audio_monitor_service.dart';
import '../services/audio_yamnet/audio_threat_detection_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sound_detection_dialog.dart';
import '../services/background_sound_service.dart';

class SoundMonitorPage extends StatefulWidget {
  const SoundMonitorPage({super.key});

  @override
  State<SoundMonitorPage> createState() => _SoundMonitorPageState();
}

class _SoundMonitorPageState extends State<SoundMonitorPage> {
  bool _fgMonitoring = false;
  bool _bgMonitoring = false;
  bool _trialBgService = false;
  String _lastEvent = 'Nimic detectat încă';
  late final AudioThreatDetectionService _threatDetectionService;

  @override
  void initState() {
    super.initState();
    _threatDetectionService = AudioThreatDetectionService.instance;
    _threatDetectionService.initialize(
      onThreatDetected: _onThreatDetected,
      onPreAlarmConfirmed: _onPreAlarmConfirmed,
      onPreAlarmCancelled: _onPreAlarmCancelled,
    );

    _checkSafetyShieldState();
  }

  Future<void> _checkSafetyShieldState() async {
    final prefs = await SharedPreferences.getInstance();
    final isSafetyShieldActive = prefs.getBool('safety_shield_active') ?? false;

    if (isSafetyShieldActive && !_fgMonitoring) {
      final micStatus = await Permission.microphone.request();
      if (!mounted) return;

      if (micStatus.isGranted) {
        await AudioMonitorService.instance.startMonitoring(
          onAlert: (result) {
            _threatDetectionService.processSoundDetection(result);
            setState(() {
              _lastEvent = 'Detectare sunet: $result';
            });

            if (_threatDetectionService.hasActivePreAlarm) {
              final prealarm = _threatDetectionService.currentPreAlarm;
              if (prealarm != null) {
                _showSoundDetectionDialog(prealarm.threatEvent);
              }
            }
          },
        );
        setState(() {
          _fgMonitoring = true;
          _lastEvent =
              'Monitorizare sunete (foreground) PORNITĂ (Safety Shield Active)';
        });
      }
    }
  }

  @override
  void dispose() {
    _threatDetectionService.cancelActivePreAlarm();
    super.dispose();
  }

  void _onThreatDetected(ThreatDetectionEvent event) {
    debugPrint(
      'Threat detected: ${event.threatType} @ ${event.confidenceScore.toStringAsFixed(2)}',
    );
    setState(() {
      _lastEvent =
          'Alertă: ${event.threatType} (${(event.confidenceScore * 100).toStringAsFixed(0)}%)';
    });
  }

  void _onPreAlarmConfirmed(ThreatDetectionEvent event) {
    debugPrint('Pre-alarm confirmed - executing SOS');
    setState(() {
      _lastEvent = 'SOS TRIMIS pentru ${event.threatType}!';
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SOS SENT for ${event.threatType} detection!'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onPreAlarmCancelled(ThreatDetectionEvent event, String reason) {
    debugPrint('Pre-alarm cancelled: $reason');
    setState(() {
      _lastEvent = 'Alertă anulată: $reason';
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('False alarm logged: $reason'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSoundDetectionDialog(ThreatDetectionEvent event) {
    String threatTypeLabel;
    if (event.threatType == ThreatType.scream) {
      threatTypeLabel = 'Scream';
    } else if (event.threatType == ThreatType.crowdNoise) {
      threatTypeLabel = 'Crowd Noise';
    } else {
      threatTypeLabel = 'Glass Breaking';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SoundDetectionDialog(
        threatType: threatTypeLabel,
        confidenceScore: event.confidenceScore,
        countdownDuration: const Duration(seconds: 15),
        onFalseAlarm: () {
          _threatDetectionService.handleFalseAlarm('User dismissed');
        },
        onHelpNow: () {
          _threatDetectionService.handleHelpNow();
        },
        onTimeout: () {
          _threatDetectionService.handleHelpNow();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitorizare sunete')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final micStatus = await Permission.microphone.request();
                if (!context.mounted) return;
                if (!micStatus.isGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Permisiunea pentru microfon este necesară.',
                      ),
                    ),
                  );
                  return;
                }

                if (_fgMonitoring) {
                  await AudioMonitorService.instance.stopMonitoring();
                  setState(() {
                    _fgMonitoring = false;
                    _lastEvent = 'Monitorizare sunete (foreground) oprită';
                  });
                } else {
                  await AudioMonitorService.instance.startMonitoring(
                    onAlert: (result) {
                      _threatDetectionService.processSoundDetection(result);

                      setState(() {
                        _lastEvent = 'Detectare sunet: $result';
                      });

                      if (_threatDetectionService.hasActivePreAlarm) {
                        final prealarm =
                            _threatDetectionService.currentPreAlarm;
                        if (prealarm != null) {
                          _showSoundDetectionDialog(prealarm.threatEvent);
                        }
                      }
                    },
                  );
                  setState(() {
                    _fgMonitoring = true;
                    _lastEvent = 'Monitorizare sunete (foreground) PORNITĂ';
                  });
                }
              },
              child: Text(
                _fgMonitoring
                    ? 'Oprește monitorizarea sunetelor (foreground)'
                    : 'Pornește monitorizarea sunetelor (foreground)',
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                if (_trialBgService) {
                  await BackgroundSoundService.instance.stop();
                  setState(() {
                    _trialBgService = false;
                    _lastEvent = 'Serviciu de test (heartbeat) OPRIT';
                  });
                } else {
                  await BackgroundSoundService.instance.initialize();
                  setState(() {
                    _trialBgService = true;
                    _lastEvent = 'Serviciu de test (heartbeat) PORNIT';
                  });
                }
              },
              child: Text(
                _trialBgService
                    ? 'Oprește serviciul de test (heartbeat)'
                    : 'Pornește serviciul de test (heartbeat)',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () async {
                final service = FlutterBackgroundService();

                final micStatus = await Permission.microphone.request();
                if (!context.mounted) return;
                if (!micStatus.isGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Permisiunea pentru microfon este necesară.',
                      ),
                    ),
                  );
                  return;
                }

                final isRunning = await service.isRunning();
                debugPrint('UI: background service running? $isRunning');

                if (!isRunning) {
                  debugPrint('UI: pornesc background service...');
                  await service.startService();

                  await Future.delayed(const Duration(seconds: 1));
                }

                if (_bgMonitoring) {
                  debugPrint('UI: trimit stopAudio către service');
                  service.invoke('stopAudio');
                  setState(() {
                    _bgMonitoring = false;
                    _lastEvent = 'Monitorizare audio în fundal OPRITĂ';
                  });
                } else {
                  debugPrint('UI: trimit startAudio către service');
                  service.invoke('startAudio');
                  setState(() {
                    _bgMonitoring = true;
                    _lastEvent =
                        'Monitorizare audio în fundal PORNITĂ (merge și cu aplicația minimizată)';
                  });
                }
              },
              child: Text(
                _bgMonitoring
                    ? 'Oprește monitorizarea audio în FUNDAL'
                    : 'Pornește monitorizarea audio în FUNDAL',
              ),
            ),
            const SizedBox(height: 24),

            Text(_lastEvent),
          ],
        ),
      ),
    );
  }
}
