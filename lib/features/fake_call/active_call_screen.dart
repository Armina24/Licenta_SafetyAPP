import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'fake_call_scenario.dart';
import '../../services/audio_routing_service.dart';

class ActiveCallScreen extends StatefulWidget {
  final FakeCallScenario scenario;

  const ActiveCallScreen({super.key, required this.scenario});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _socialAudios = [
    'sounds/social_1.mp3',
    'sounds/social_2.mp3',
    'sounds/social_3.mp3',
  ];

  static const List<String> _safetyAudios = [
    'sounds/safety_1.mp3',
    'sounds/safety_2.mp3',
    'sounds/safety_3.mp3',
    'sounds/safety_4.mp3',
  ];

  static const List<String> _socialScriptLines = [
    'Alo? Unde ești? Ai promis că ajungi la timp, musafirii au ajuns deja. Te rog să vii acasă imediat.',
    'Nu mă interesează scuzele. Hai te rog mai repede că e neplăcut față de oameni.',
    'Bine, haide, te așteptăm. Pa!',
  ];

  static const List<String> _safetyScriptLines = [
    'Alo, da. Vă monitorizăm locația prin GPS. Sunteți în siguranță?',
    'Am înțeles. Vă văd unde sunteți. Păstrați-vă calmul, ajutorul este pe drum.',
    'Echipajul ajunge în 2 minute. Vă rog să rămâneți la telefon și să mergeți spre o zonă luminată.',
    'Vă vedem pe cameră. Colegii mei sunt acolo. Totul e în regulă.',
  ];

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRoutingService _audioRoutingService = AudioRoutingService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Timer? _callTimer;
  Timer? _vadCheckTimer;
  int _callDuration = 0;
  List<String> _currentAudioList = [];
  List<String> _currentScriptLines = [];
  bool _isCallActive = true;

  bool _isMuted = false;
  bool _isSpeakerEnabled = false;
  bool _isVadActive = true;

  bool _showKeypad = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      if (widget.scenario == FakeCallScenario.social) {
        _currentAudioList = List<String>.from(_socialAudios);
        _currentScriptLines = List<String>.from(_socialScriptLines);
      } else {
        _currentAudioList = List<String>.from(_safetyAudios);
        _currentScriptLines = List<String>.from(_safetyScriptLines);
      }

      await _audioRoutingService.initializeCallAudioSession();

      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );

      _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      );

      _pulseController.repeat(reverse: true);

      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _callDuration++;
        });
      });

      _startSmartVadCheck();

      _runScriptSequence();

      setState(() {});
    } catch (e) {
      debugPrint('Error initializing call: $e');
    }
  }

  Future<void> _runScriptSequence() async {
    if (_currentAudioList.isEmpty || _currentScriptLines.isEmpty) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!_isCallActive) return;

    for (int i = 0; i < _currentScriptLines.length; i++) {
      if (!_isCallActive) break;

      final textLine = _currentScriptLines[i];
      final audioPath = _currentAudioList[i];

      await _playScriptLine(textLine, audioPath);

      if (!_isCallActive) break;

      _pulseController.stop();
      await Future.delayed(const Duration(seconds: 4));
      if (_isCallActive) {
        _pulseController.repeat(reverse: true);
      }
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _isCallActive) {
      _endCall();
    }
  }

  Future<void> _playScriptLine(String text, String assetPath) async {
    if (!_isCallActive) return;

    try {
      debugPrint('Playing script line: $text');
      _pulseController.repeat(reverse: true);

      await _audioPlayer.play(AssetSource(assetPath));
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      debugPrint('Error playing script line: $e');
    }
  }

  void _startSmartVadCheck() {
    _vadCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (!_isMuted && _isVadActive) {
        _simulateVadDetection();
      }
    });
  }

  void _simulateVadDetection() {}

  Future<void> _toggleMute() async {
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isMuted) {
      _isVadActive = false;
      await Vibration.vibrate(duration: 100);
      debugPrint('Muted - VAD paused');
    } else {
      _isVadActive = true;
      await Vibration.vibrate(duration: 100);
      debugPrint('Unmuted - VAD resumed');
    }
  }

  Future<void> _toggleSpeaker() async {
    setState(() {
      _isSpeakerEnabled = !_isSpeakerEnabled;
    });

    if (_isSpeakerEnabled) {
      await _audioRoutingService.enableSpeaker();
      await Vibration.vibrate(duration: 100);
    } else {
      await _audioRoutingService.disableSpeaker();
      await Vibration.vibrate(duration: 100);
    }
  }

  void _showKeypadModal() {
    setState(() {
      _showKeypad = true;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildKeypadModal(),
    ).whenComplete(() {
      setState(() {
        _showKeypad = false;
      });
    });
  }

  Widget _buildKeypadModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Keypad',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            Column(
              children: [
                _buildKeypadRow(['1', '2', '3']),
                const SizedBox(height: 16),
                _buildKeypadRow(['4', '5', '6']),
                const SizedBox(height: 16),
                _buildKeypadRow(['7', '8', '9']),
                const SizedBox(height: 16),
                _buildKeypadRow(['*', '0', '#']),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKeypadButton(key)).toList(),
    );
  }

  Widget _buildKeypadButton(String key) {
    return GestureDetector(
      onTap: () {
        _playKeypadTone(key);
        Vibration.vibrate(duration: 50);
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            key,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _playKeypadTone(String key) {
    debugPrint('Keypad pressed: $key');
  }

  Future<void> _endCall() async {
    _isCallActive = false;
    await _audioPlayer.stop();
    _callTimer?.cancel();
    _vadCheckTimer?.cancel();
    _pulseController.stop();

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  String _getCallerName() {
    return widget.scenario == FakeCallScenario.social
        ? 'Tata'
        : 'Emergency Contact';
  }

  Color _getThemeColor() {
    return widget.scenario == FakeCallScenario.social
        ? Colors.teal
        : Colors.deepOrange;
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callTimer?.cancel();
    _vadCheckTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getThemeColor();
    final callerName = _getCallerName();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              themeColor.withValues(alpha: 0.9),
              themeColor.withValues(alpha: 0.7),
              themeColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'In Call',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.scenario == FakeCallScenario.social
                            ? Icons.person
                            : Icons.shield,
                        size: 60,
                        color: themeColor,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.scenario == FakeCallScenario.social
                    ? 'Mobile'
                    : 'Emergency Contact',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallControlButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          label: _isMuted ? 'Unmute' : 'Mute',
                          isActive: _isMuted,
                          onPressed: _toggleMute,
                        ),

                        _CallControlButton(
                          icon: Icons.dialpad,
                          label: 'Keypad',
                          isActive: _showKeypad,
                          onPressed: _showKeypadModal,
                        ),

                        _CallControlButton(
                          icon: _isSpeakerEnabled
                              ? Icons.volume_up
                              : Icons.volume_mute,
                          label: _isSpeakerEnabled ? 'Earpiece' : 'Speaker',
                          isActive: _isSpeakerEnabled,
                          onPressed: _toggleSpeaker,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const SizedBox(height: 32),

                    _CallActionButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      label: 'End Call',
                      onPressed: _endCall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _CallActionButton({
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
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, size: 32, color: Colors.white),
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
