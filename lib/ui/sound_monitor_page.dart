import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_YAMNet/audio_monitor_service.dart';
import '../services/audio_YAMNet/audio_threat_detection_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sound_detection_dialog.dart';

class SoundMonitorPage extends StatefulWidget {
  const SoundMonitorPage({super.key});

  @override
  State<SoundMonitorPage> createState() => _SoundMonitorPageState();
}

class _SoundMonitorPageState extends State<SoundMonitorPage> {
  bool _fgMonitoring = false;    //monitorizare doar cand e deschisa pagina
  bool _bgMonitoring = false;    //monitorizare in bg (via service)
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
    
    // Check if Safety Shield is active and auto-enable monitoring
    _checkSafetyShieldState();
  }

  /// Check if Safety Shield is active and auto-activate foreground monitoring
  Future<void> _checkSafetyShieldState() async {
    final prefs = await SharedPreferences.getInstance();
    final isSafetyShieldActive = prefs.getBool('safety_shield_active') ?? false;
    
    if (isSafetyShieldActive && !_fgMonitoring) {
      // Auto-enable foreground monitoring if Safety Shield is active
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
          _lastEvent = 'Monitorizare sunete (foreground) PORNITĂ (Safety Shield Active)';
        });
      }
    }
  }

  @override
  void dispose() {
    _threatDetectionService.cancelActivePreAlarm();
    super.dispose();
  }

  /// Called when a threat is detected
  void _onThreatDetected(ThreatDetectionEvent event) {
    debugPrint('🚨 Threat detected: ${event.threatType} @ ${event.confidenceScore.toStringAsFixed(2)}');
    setState(() {
      _lastEvent = 'Alertă: ${event.threatType} (${(event.confidenceScore * 100).toStringAsFixed(0)}%)';
    });
  }

  /// Called when pre-alarm is confirmed (timeout or user action)
  void _onPreAlarmConfirmed(ThreatDetectionEvent event) {
    debugPrint('✓ Pre-alarm confirmed - executing SOS');
    setState(() {
      _lastEvent = 'SOS TRIMIS pentru ${event.threatType}!';
    });
    // Here you would call _sendSos() from your emergency service
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SOS SENT for ${event.threatType} detection!'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Called when user dismisses as false alarm
  void _onPreAlarmCancelled(ThreatDetectionEvent event, String reason) {
    debugPrint('✓ Pre-alarm cancelled: $reason');
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

  /// Show sound detection dialog when threat is detected
  void _showSoundDetectionDialog(ThreatDetectionEvent event) {
    String threatTypeLabel = event.threatType == ThreatType.scream ? 'Scream' : 'Glass Breaking';

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
          _threatDetectionService.handleHelpNow(); // Auto-execute
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
            // 1) Buton pentru monitorizare DOAR cât timp e pagina deschisă (foreground)
            ElevatedButton(
              onPressed: () async {
                // cerem permisiunea aici, în UI
                final micStatus = await Permission.microphone.request();
                if (!context.mounted) return;
                if (!micStatus.isGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permisiunea pentru microfon este necesară.'),
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
                      // Process sound through threat detection service
                      _threatDetectionService.processSoundDetection(result);

                      setState(() {
                        _lastEvent = 'Detectare sunet: $result';
                      });

                      // If there's an active pre-alarm, show the dialog
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

            // 2) Buton pentru monitorizare în FUNDAL (prin background service)
            ElevatedButton(
              onPressed: () async {
                final service = FlutterBackgroundService();

                // cerem permisiunea de microfon în UI
                final micStatus = await Permission.microphone.request();
                if (!context.mounted) return;
                if (!micStatus.isGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permisiunea pentru microfon este necesară.'),
                    ),
                  );
                  return;
                }

                final isRunning = await service.isRunning();
                debugPrint('UI: background service running? $isRunning');

                if (!isRunning) {
                  debugPrint('UI: pornesc background service...');
                  await service.startService(); // ⬅️ AICI declanșăm _onStart
                  // dăm un pic de timp isolate-ului să pornească și să atașeze listener-ele
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
