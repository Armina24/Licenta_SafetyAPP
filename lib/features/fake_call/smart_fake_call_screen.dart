import 'package:flutter/material.dart';
import 'fake_call_scenario.dart';
import 'incoming_call_screen.dart';

class SmartFakeCallScreen extends StatefulWidget {
  final FakeCallScenario scenario;

  const SmartFakeCallScreen({super.key, required this.scenario});

  @override
  State<SmartFakeCallScreen> createState() => _SmartFakeCallScreenState();
}

class _SmartFakeCallScreenState extends State<SmartFakeCallScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToIncomingCall();
    });
  }

  void _navigateToIncomingCall() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(scenario: widget.scenario),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.teal)),
      ),
    );
  }
}
