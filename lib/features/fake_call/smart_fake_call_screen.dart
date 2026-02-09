import 'package:flutter/material.dart';
import 'fake_call_scenario.dart';
import 'incoming_call_screen.dart';

/// Smart fake call screen - entry point that routes to incoming call
class SmartFakeCallScreen extends StatefulWidget {
  final FakeCallScenario scenario;

  const SmartFakeCallScreen({
    super.key,
    required this.scenario,
  });

  @override
  State<SmartFakeCallScreen> createState() => _SmartFakeCallScreenState();
}

class _SmartFakeCallScreenState extends State<SmartFakeCallScreen> {
  @override
  void initState() {
    super.initState();
    // Immediately navigate to incoming call screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToIncomingCall();
    });
  }

  void _navigateToIncomingCall() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          scenario: widget.scenario,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This screen immediately navigates to IncomingCallScreen
    // So we show a blank loading state briefly
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.teal,
          ),
        ),
      ),
    );
  }
}
