import 'package:flutter/material.dart';

import 'fake_call_scenario.dart';
import 'openai_fake_call_screen.dart';

const String kOpenAIApiKey = String.fromEnvironment('OPENAI_API_KEY');
const String kGoogleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class FakeCallAIDemoEntry extends StatelessWidget {
  const FakeCallAIDemoEntry({super.key});

  void _open(BuildContext context, FakeCallScenario scenario) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OpenAIFakeCallScreen(
          scenario: scenario,
          openAiApiKey: kOpenAIApiKey,
          googleMapsApiKey: kGoogleMapsApiKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Fake Call Demo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => _open(context, FakeCallScenario.social),
              child: const Text('Fake Call: Tata'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _open(context, FakeCallScenario.safety),
              child: const Text('Fake Call: Dispecerat'),
            ),
          ],
        ),
      ),
    );
  }
}
