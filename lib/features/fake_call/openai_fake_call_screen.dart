/*import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as session;
import 'package:path_provider/path_provider.dart';
import 'fake_call_scenario.dart';
import '../../services/audio_routing_service.dart';

class OpenAIFakeCallScreen extends StatefulWidget {
  final FakeCallScenario scenario;

  const OpenAIFakeCallScreen({
    super.key,
    required this.scenario,
  });

  @override
  State<OpenAIFakeCallScreen> createState() => _OpenAIFakeCallScreenState();
}

class _OpenAIFakeCallScreenState extends State<OpenAIFakeCallScreen>
    with SingleTickerProviderStateMixin {
  
  // ========== PUNE CHEIA TA AICI (Păstrată pentru backup) ==========
  static const String _openAIKey = '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'; 

  // ========== Services ==========
  late final AudioPlayer _audioPlayer;
  
  // ========== State ==========
  Timer? _callTimer;
  int _callDuration = 0;
  String _statusText = 'Conectare...';
  String _currentAiLine = ''; // Textul pe care îl zice AI-ul acum
  bool _isSpeaking = false;
  bool _isMuted = false;
  bool _isCallActive = true;
  bool _isSpeakerOn = false;
  bool _isKeyboardVisible = false;
  session.AudioSession? _audioSession;

  // ========== Scenarios Configuration ==========
  // late OpenAIAudioVoice _voiceModel; // Nu mai e necesar pentru MP3, dar îl las comentat
  late String _callerName;
  late List<String> _scriptLines; // Textul pentru subtitrare
  late List<String> _audioFiles;  // Căile către fișierele MP3

  // ========== Animation ==========
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _configureScenario();
    _setupAnimations();
    _initializeServicesAndStart();
  }

  void _configureScenario() {
    if (widget.scenario == FakeCallScenario.social) {
      _callerName = "Tata";
      // _voiceModel = OpenAIAudioVoice.onyx; 
      
      // SCENARIUL SOCIAL (TATA)
      // MP3-urile trebuie să fie în assets/audio/
      _audioFiles = [
        "sounds/social_1.mp3",
        "sounds/social_2.mp3",
        "sounds/social_3.mp3",
      ];

      _scriptLines = [
        "Alo? Unde ești? Ai promis că ajungi la timp, musafirii au ajuns deja. Te rog să vii acasă imediat.",
        "Nu mă interesează scuzele. Hai te rog mai repede că e neplăcut față de oameni.",
        "Bine, haide, te așteptăm. Pa!"
      ];

    } else {
      _callerName = "Dispecerat Securitate";
      // _voiceModel = OpenAIAudioVoice.shimmer; 
      
      // SCENARIUL SAFETY (DISPECERAT)
      _audioFiles = [
        "sounds/safety_1.mp3",
        "sounds/safety_2.mp3",
        "sounds/safety_3.mp3",
        "sounds/safety_4.mp3",
      ];

      _scriptLines = [
        "Alo, da. Vă monitorizăm locația prin GPS. Sunteți în siguranță?",
        "Am înțeles. Vă văd unde sunteți. Păstrați-vă calmul, ajutorul este pe drum.",
        "Echipajul ajunge în 2 minute. Vă rog să rămâneți la telefon și să mergeți spre o zonă luminată.",
        "Vă vedem pe cameră. Colegii mei sunt acolo. Totul e în regulă."
      ];
    }
  }

  Future<void> _initializeServicesAndStart() async {
    try {
      // OpenAI.apiKey = _openAIKey; // Nu inițializăm OpenAI pentru modul offline
      _audioPlayer = AudioPlayer();

      // Configurare sunet (Earpiece - default)
      _audioSession = await session.AudioSession.instance;
      await _audioSession!.configure(const session.AudioSessionConfiguration(
        avAudioSessionCategory: session.AVAudioSessionCategory.playAndRecord,
        avAudioSessionMode: session.AVAudioSessionMode.voiceChat,
        androidAudioAttributes: session.AndroidAudioAttributes(
          usage: session.AndroidAudioUsage.voiceCommunication,
          contentType: session.AndroidAudioContentType.speech,
        ),
      ));

      _startCallTimer();

      if (mounted) {
        setState(() {
          _statusText = 'Conectat';
        });
      }

      // PORNIRE SCENARIU
      _runScriptSequence();

    } catch (e) {
      if (mounted) setState(() => _statusText = 'Eroare: $e');
    }
  }

  // ========== LOGICA DE SCENARIU ==========
  Future<void> _runScriptSequence() async {
    // 1. Așteptăm 2 secunde la început ca tu să zici "Alo?"
    await Future.delayed(const Duration(seconds: 2));

    if (!_isCallActive) return;

    // 2. Parcurgem replicile una câte una folosind indexul
    for (int i = 0; i < _scriptLines.length; i++) {
      if (!_isCallActive) break;

      String textLinie = _scriptLines[i];
      String audioPath = _audioFiles[i]; // Luăm MP3-ul corespunzător

      // A. Redăm replica (Acum folosim MP3 local)
      await _speakLine(textLinie, audioPath);

      // B. Așteptăm să termine de vorbit (aproximativ) + TIMP PENTRU TINE SĂ RĂSPUNZI
      if (mounted) {
        setState(() {
          _statusText = 'Te ascult...'; // Vizual pare că te ascultă
          _pulseController.stop(); // Oprim pulsația cât "te ascultă"
        });
      }

      // Aici e timpul tău să răspunzi ("Da, vin acum...")
      // Poți mări durata dacă ai replici lungi de zis
      await Future.delayed(const Duration(seconds: 4)); 
    }

    // După ce termină toate replicile, închidem apelul automat după 2 secunde
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _isCallActive) {
      _endCall();
    }
  }

  // Modificat să accepte și path-ul către asset
  Future<void> _speakLine(String text, String assetPath) async {
    if (!_isCallActive) return;

    try {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
          _statusText = _callerName; // Arată numele când vorbește
          _currentAiLine = text;
          _pulseController.repeat(reverse: true); // Pulsează când vorbește
        });
      }

      // ============================================================
      // LOGICA VECHE OPENAI (COMENTATĂ PENTRU BACKUP)
      // ============================================================
      /*
      // Generare Audio OpenAI
      final tempDir = await getTemporaryDirectory();
      final outputPath = tempDir.path;
      
      await OpenAI.instance.audio.createSpeech(
        model: 'tts-1',
        input: text,
        voice: _voiceModel, // Ai nevoie de variabila _voiceModel decomentată sus
        responseFormat: OpenAIAudioSpeechResponseFormat.mp3,
        outputDirectory: Directory(outputPath),
        outputFileName: 'temp_speech',
      );

      final filePath = '$outputPath/temp_speech.mp3';
      
      // Redare fișier generat
      await _audioPlayer.play(DeviceFileSource(filePath));
      */
      // ============================================================

      // ============================================================
      // LOGICA NOUĂ OFFLINE (MP3 DIN ASSETS)
      // ============================================================
      
      // Redăm direct fișierul MP3 din folderul assets/audio/
      await _audioPlayer.play(AssetSource(assetPath));

      // Așteptăm să termine de vorbit acest fișier
      await _audioPlayer.onPlayerComplete.first;

      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _statusText = 'Eroare la redare: $e';
        });
        }
      }
    }
  
    void _startCallTimer() {
      _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _callDuration++;
          });
        }
      });
    }
  
    Future<void> _toggleSpeaker() async {
      setState(() {
        _isSpeakerOn = !_isSpeakerOn;
      });

      try {
        if (_isSpeakerOn) {
          // Comută la speaker
          await _audioSession?.configure(const session.AudioSessionConfiguration(
            avAudioSessionCategory: session.AVAudioSessionCategory.playAndRecord,
            avAudioSessionMode: session.AVAudioSessionMode.videoChat,
            androidAudioAttributes: session.AndroidAudioAttributes(
              usage: session.AndroidAudioUsage.voiceCommunication,
              contentType: session.AndroidAudioContentType.speech,
            ),
            androidAudioFocusGainType: session.AndroidAudioFocusGainType.gain,
          ));
          await _audioPlayer.setAudioContext(AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              audioMode: AndroidAudioMode.inCommunication,
            ),
          ));
          debugPrint('🔊 Speaker ON');
        } else {
          // Comută la earpiece
          await _audioSession?.configure(const session.AudioSessionConfiguration(
            avAudioSessionCategory: session.AVAudioSessionCategory.playAndRecord,
            avAudioSessionMode: session.AVAudioSessionMode.voiceChat,
            androidAudioAttributes: session.AndroidAudioAttributes(
              usage: session.AndroidAudioUsage.voiceCommunication,
              contentType: session.AndroidAudioContentType.speech,
            ),
          ));
          await _audioPlayer.setAudioContext(AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: false,
              audioMode: AndroidAudioMode.inCommunication,
            ),
          ));
          debugPrint('📱 Earpiece ON');
        }
      } catch (e) {
        debugPrint('Error toggling speaker: $e');
      }
    }

    void _toggleKeyboard() {
      setState(() {
        _isKeyboardVisible = !_isKeyboardVisible;
      });
    }
  
    void _endCall() {
      _isCallActive = false;
      _callTimer?.cancel();
      _audioPlayer.stop();
      _pulseController.stop();
      Navigator.of(context).pop();
    }
  
    void _setupAnimations() {
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(_pulseController);
    }
  
    @override
    void dispose() {
      _callTimer?.cancel();
      _pulseController.dispose();
      _audioPlayer.dispose();
      super.dispose();
    }
  
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Colors.grey.shade900,
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top Section - Caller Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.shade700,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _callerName[0],
                              style: const TextStyle(
                                fontSize: 45,
                                color: Colors.white,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Caller Name
                      Text(
                        _callerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Call Duration
                      Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Status
                      Text(
                        _statusText,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      
                      // Current AI Line (subtitles)
                      if (_currentAiLine.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentAiLine,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Bottom Section - Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                  child: Column(
                    children: [
                      // Top Row - Mic, Keyboard, Speaker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildControlButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            label: 'mute',
                            isActive: _isMuted,
                            onPressed: () {
                              setState(() => _isMuted = !_isMuted);
                            },
                          ),
                          _buildControlButton(
                            icon: Icons.dialpad,
                            label: 'keypad',
                            isActive: _isKeyboardVisible,
                            onPressed: _toggleKeyboard,
                          ),
                          _buildControlButton(
                            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                            label: 'speaker',
                            isActive: _isSpeakerOn,
                            onPressed: _toggleSpeaker,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      
                      // End Call Button
                      GestureDetector(
                        onTap: _endCall,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
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
    
    Widget _buildControlButton({
      required IconData icon,
      required String label,
      required bool isActive,
      required VoidCallback onPressed,
    }) {
      return Column(
        children: [
          GestureDetector(
            onTap: onPressed,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive 
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
  
    String _formatDuration(int seconds) {
      int minutes = seconds ~/ 60;
      int secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }*/