import 'package:flutter/material.dart';
import '../services/audio_YAMNet/audio_monitor_service.dart';

class SoundMonitorPage extends StatefulWidget {
  const SoundMonitorPage({super.key});

  @override
  State<SoundMonitorPage> createState() => _SoundMonitorPageState();
}

class _SoundMonitorPageState extends State<SoundMonitorPage> {
  bool _monitoring = false;
  String _lastEvent = 'Nimic detectat încă';

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
                if (_monitoring) {
                  await AudioMonitorService.instance.stopMonitoring();
                  setState(() {
                    _monitoring = false;
                  });
                } else {
                  await AudioMonitorService.instance.startMonitoring(
                    onAlert: (result) {
                      setState(() {
                        _lastEvent =
                            'Alertă: $result'; // aici poți pune un mesaj mai frumos
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Alertă sunet: $result')),
                      );
                    },
                  );
                  setState(() {
                    _monitoring = true;
                  });
                }
              },
              child: Text(
                _monitoring
                    ? 'Oprește monitorizarea sunetelor'
                    : 'Pornește monitorizarea sunetelor',
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
