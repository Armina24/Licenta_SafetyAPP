import 'package:flutter/material.dart';
import '../services/audio_YAMNet/audio_monitor_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/background_service.dart'; // dacă vrei să te asiguri că e inițializat


class SoundMonitorPage extends StatefulWidget {
  const SoundMonitorPage({super.key});

  @override
  State<SoundMonitorPage> createState() => _SoundMonitorPageState();
}

class _SoundMonitorPageState extends State<SoundMonitorPage> {
  bool _fgMonitoring = false;    //monitorizare doar cand e deschisa pagina
  bool _bgMonitoring = false;    //monitorizare in bg (via service)
  String _lastEvent = 'Nimic detectat încă';

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
                      setState(() {
                        _lastEvent = 'Alertă (foreground): $result';
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Alertă sunet: $result')),
                      );
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
                if (!micStatus.isGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permisiunea pentru microfon este necesară.'),
                    ),
                  );
                  return;
                }

                final isRunning = await service.isRunning();
                print('UI: background service running? $isRunning');

                if (!isRunning) {
                  print('UI: pornesc background service...');
                  await service.startService(); // ⬅️ AICI declanșăm _onStart
                  // dăm un pic de timp isolate-ului să pornească și să atașeze listener-ele
                  await Future.delayed(const Duration(seconds: 1));
                }

                if (_bgMonitoring) {
                  print('UI: trimit stopAudio către service');
                  service.invoke('stopAudio');
                  setState(() {
                    _bgMonitoring = false;
                    _lastEvent = 'Monitorizare audio în fundal OPRITĂ';
                  });
                } else {
                  print('UI: trimit startAudio către service');
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
