import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'fake_call_scenario.dart';
import 'active_call_screen.dart';
import '../../services/ringer_mode_service.dart';

/// Incoming call screen that mimics native iOS/Android incoming call UI
class IncomingCallScreen extends StatefulWidget {
  final FakeCallScenario scenario;

  const IncomingCallScreen({
    super.key,
    required this.scenario,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
  with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _vibrationTimer;
  RingerMode _ringerMode = RingerMode.normal;
  bool _isAnswering = false;

  @override
  void initState() {
    super.initState();
    _initializeScreenAnimations();
    _initializeCallRinger();
  }

  void _initializeScreenAnimations() {
    // Pulse animation for avatar
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);

    // Slide animation for decline/accept buttons
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.forward();
  }

  Future<void> _initializeCallRinger() async {
    try {
      _ringerMode = await RingerModeService.getRingerMode();

      // Initialize audio player for ringtone
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      
      // Play based on ringer mode
      if (_ringerMode == RingerMode.normal) {
        await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
        _startVibrationPattern();
      } else if (_ringerMode == RingerMode.vibrate) {
        _startVibrationPattern();
      }
      // If silent, do nothing

      setState(() {});
    } catch (e) {
      debugPrint('Error initializing ringtone: $e');
    }
  }

  void _startVibrationPattern() {
    // Pattern: 1s wait, 0.5s vibrate, 0.5s pause, repeat
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      Future.delayed(const Duration(seconds: 1), () {
        Vibration.vibrate(duration: 500);
      });
    });
  }

  Future<void> _acceptCall() async {
    if (_isAnswering) return;
    _isAnswering = true;

    // Stop ringtone and vibration
    await _audioPlayer.stop();
    _vibrationTimer?.cancel();
    _pulseController.stop();

    // Brief haptic feedback
    await Vibration.vibrate(duration: 100);

    if (!mounted) return;

    // Navigate to active call screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ActiveCallScreen(
          scenario: widget.scenario,
        ),
      ),
    );
  }

  void _declineCall() {
    _audioPlayer.stop();
    _vibrationTimer?.cancel();
    _pulseController.stop();
    Navigator.of(context).pop();
  }

  String _getCallerName() {
    return widget.scenario == FakeCallScenario.social ? 'Tata' : 'Emergency Services';
  }

  String _getCallerSubtitle() {
    return widget.scenario == FakeCallScenario.social ? 'Mobile' : 'Emergency';
  }

  Color _getThemeColor() {
    return widget.scenario == FakeCallScenario.social
        ? Colors.teal
        : Colors.deepOrange;
  }

  IconData _getCallerIcon() {
    return widget.scenario == FakeCallScenario.social
        ? Icons.person
        : Icons.shield;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _vibrationTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getThemeColor();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _declineCall();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                themeColor.withValues(alpha: 0.9),
                themeColor.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Blurred background effect
              Container(
                color: Colors.black.withValues(alpha: 0.1),
              ),

              // Main content
              SafeArea(
                child: Column(
                  children: [
                    // Top status bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Incoming Call',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Caller avatar with pulse animation
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 25,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(
                              _getCallerIcon(),
                              size: 70,
                              color: themeColor,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Caller name
                    Text(
                      _getCallerName(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Caller subtitle
                    Text(
                      _getCallerSubtitle(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 16,
                      ),
                    ),

                    const Spacer(),

                    // Action buttons with slide animation
                    SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 48.0,
                        ),
                        child: Column(
                          children: [
                            // Swipe hint
                            Text(
                              'Slide or tap to answer',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Accept/Decline buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Decline button
                                _IncomingCallButton(
                                  icon: Icons.call_end,
                                  color: Colors.red,
                                  label: 'Decline',
                                  onPressed: _declineCall,
                                ),

                                // Accept button
                                _IncomingCallButton(
                                  icon: Icons.call,
                                  color: Colors.green,
                                  label: 'Accept',
                                  onPressed: _acceptCall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Custom button widget for accept/decline actions
class _IncomingCallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _IncomingCallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 12,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
