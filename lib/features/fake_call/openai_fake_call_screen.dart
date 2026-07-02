import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:audio_session/audio_session.dart' as session;
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'fake_call_scenario.dart';

class OpenAIFakeCallScreen extends StatefulWidget {
  final FakeCallScenario scenario;

  const OpenAIFakeCallScreen({super.key, required this.scenario});

  @override
  State<OpenAIFakeCallScreen> createState() => _OpenAIFakeCallScreenState();
}

class _OpenAIFakeCallScreenState extends State<OpenAIFakeCallScreen>
    with SingleTickerProviderStateMixin {
  static const String _openAIKey = String.fromEnvironment('OPENAI_API_KEY');

  late final AudioPlayer _audioPlayer;
  final AudioRecorder _recorder = AudioRecorder();
  session.AudioSession? _audioSession;

  Timer? _callTimer;
  int _callDuration = 0;

  String _statusText = 'Conectare...';
  String _currentAiLine = '';
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isMuted = false;
  bool _isCallActive = true;
  bool _isSpeakerOn = false;
  bool _isKeyboardVisible = false;

  late String _callerName;
  late String _systemPrompt;
  late String _starterLine;

  final List<OpenAIChatCompletionChoiceMessageModel> _chatMessages = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Duration _listenDuration = Duration(seconds: 5);

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
      _systemPrompt = """
Ești într-un apel telefonic REALIST cu utilizatorul.
Tu ești TATĂL, ton ușor autoritar dar nu agresiv.
Vorbești scurt, ca la telefon. Sunete naturale: “mda”, “ok”, “înțeleg”.
Nu spui niciodată că ești AI, model, bot.
Păstrezi conversația naturală, cu întrebări scurte și follow-up dacă e nevoie.
""";
      _starterLine =
          "Alo? Unde ești? Ai zis că ajungi la timp. Te rog, vino acasă acum.";
    } else {
      _callerName = "Dispecerat Securitate";
      _systemPrompt = """
Ești într-un apel telefonic REALIST cu utilizatorul.
Tu ești DISPECERAT/OPERATOR, calm, profesionist, orientat pe siguranță.
Vorbești scurt, clar, ca într-o situație urgentă.
Nu spui niciodată că ești AI, model, bot.
Pui întrebări simple și dai pași concreți, fără explicații lungi.
""";
      _starterLine =
          "Alo, da. Suntem dispeceratul. Te monitorizăm prin locație. Ești în siguranță acum?";
    }
  }

  Future<void> _initializeServicesAndStart() async {
    try {
      OpenAI.apiKey = _openAIKey;

      _audioPlayer = AudioPlayer();

      _audioSession = await session.AudioSession.instance;
      await _audioSession!.configure(
        const session.AudioSessionConfiguration(
          avAudioSessionCategory: session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionMode: session.AVAudioSessionMode.voiceChat,
          androidAudioAttributes: session.AndroidAudioAttributes(
            usage: session.AndroidAudioUsage.voiceCommunication,
            contentType: session.AndroidAudioContentType.speech,
          ),
        ),
      );

      _startCallTimer();

      if (mounted) {
        setState(() {
          _statusText = 'Conectat';
        });
      }

      _chatMessages
        ..clear()
        ..add(
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                _systemPrompt,
              ),
            ],
          ),
        );

      unawaited(_runConversationLoop());
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Eroare init: $e');
    }
  }

  Future<void> _runConversationLoop() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!_isCallActive) return;

    await _speakTtsAndShowSubtitles(_starterLine);

    while (_isCallActive) {
      final userText = await _listenAndTranscribeOneTurn();
      if (!_isCallActive) break;

      final cleaned = userText.trim();
      if (cleaned.isEmpty) {
        final nudge = await _getAiReply("(liniște / utilizatorul nu răspunde)");
        if (!_isCallActive) break;
        await _speakTtsAndShowSubtitles(nudge);
        continue;
      }

      final aiReply = await _getAiReply(cleaned);
      if (!_isCallActive) break;

      await _speakTtsAndShowSubtitles(aiReply);
    }
  }

  Future<String> _listenAndTranscribeOneTurn() async {
    if (!_isCallActive) return "";

    if (_isMuted) {
      if (mounted) setState(() => _statusText = "Microfon oprit");
      await Future.delayed(_listenDuration);
      return "";
    }

    if (mounted) {
      setState(() {
        _statusText = "Te ascult...";
        _isListening = true;
        _pulseController.stop();
      });
    }

    File? audioFile;
    try {
      audioFile = await _recordFixedDuration(_listenDuration);
      if (!_isCallActive) return "";

      if (mounted) setState(() => _statusText = "Procesez...");

      final text = await _openAiTranscribe(audioFile);
      return text;
    } catch (e) {
      if (mounted) setState(() => _statusText = "Eroare STT: $e");
      return "";
    } finally {
      if (mounted) setState(() => _isListening = false);
      try {
        if (audioFile != null && await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<File> _recordFixedDuration(Duration duration) async {
    final ok = await _recorder.hasPermission();
    if (!ok) throw Exception("Nu ai permisiune de microfon.");

    final dir = await getTemporaryDirectory();
    final path =
        "${dir.path}/fakecall_user_${DateTime.now().millisecondsSinceEpoch}.m4a";

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    await Future.delayed(duration);

    final outPath = await _recorder.stop();
    if (outPath == null) throw Exception("Recorder stop a returnat null.");

    return File(outPath);
  }

  Future<String> _openAiTranscribe(File audioFile) async {
    final res = await OpenAI.instance.audio.createTranscription(
      file: audioFile,
      model: "gpt-4o-mini-transcribe",
      language: "ro",
      responseFormat: OpenAIAudioResponseFormat.json,
    );

    if (res is OpenAITranscriptionModel) return res.text;
    if (res is OpenAITranscriptionVerboseModel) return res.text;
    return "";
  }

  Future<String> _getAiReply(String userText) async {
    _chatMessages.add(
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(userText),
        ],
      ),
    );

    if (_chatMessages.length > 1 + 14) {
      final system = _chatMessages.first;
      final tail = _chatMessages.sublist(_chatMessages.length - 14);
      _chatMessages
        ..clear()
        ..add(system)
        ..addAll(tail);
    }

    final chat = await OpenAI.instance.chat.create(
      model: "gpt-4o-mini",
      messages: _chatMessages,
      temperature: 0.7,
      maxTokens: 140,
    );

    final aiText =
        chat.choices.first.message.content?.first.text?.toString() ?? "";

    _chatMessages.add(
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(aiText),
        ],
      ),
    );

    return aiText;
  }

  Future<void> _speakTtsAndShowSubtitles(String text) async {
    if (!_isCallActive) return;

    if (mounted) {
      setState(() {
        _isSpeaking = true;
        _statusText = _callerName;
        _currentAiLine = text;
        _pulseController.repeat(reverse: true);
      });
    }

    try {
      await _audioPlayer.stop();

      final dir = await getTemporaryDirectory();
      final outDir = Directory(dir.path);
      final outName =
          "fakecall_tts_${DateTime.now().millisecondsSinceEpoch}.mp3";

      final speechFile = await OpenAI.instance.audio.createSpeech(
        model: "tts-1",
        input: text,
        voice: OpenAIAudioVoice.onyx,
        responseFormat: OpenAIAudioSpeechResponseFormat.mp3,
        outputDirectory: outDir,
        outputFileName: outName,
      );

      if (!_isCallActive) return;

      await _audioPlayer.play(DeviceFileSource(speechFile.path));
      await _audioPlayer.onPlayerComplete.first;

      try {
        if (await speechFile.exists()) await speechFile.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => _statusText = "Eroare TTS: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _pulseController.stop();
        });
      }
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);

    try {
      if (_isSpeakerOn) {
        await _audioSession?.configure(
          const session.AudioSessionConfiguration(
            avAudioSessionCategory:
                session.AVAudioSessionCategory.playAndRecord,
            avAudioSessionMode: session.AVAudioSessionMode.videoChat,
            androidAudioAttributes: session.AndroidAudioAttributes(
              usage: session.AndroidAudioUsage.voiceCommunication,
              contentType: session.AndroidAudioContentType.speech,
            ),
            androidAudioFocusGainType: session.AndroidAudioFocusGainType.gain,
          ),
        );
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              audioMode: AndroidAudioMode.inCommunication,
            ),
          ),
        );
      } else {
        await _audioSession?.configure(
          const session.AudioSessionConfiguration(
            avAudioSessionCategory:
                session.AVAudioSessionCategory.playAndRecord,
            avAudioSessionMode: session.AVAudioSessionMode.voiceChat,
            androidAudioAttributes: session.AndroidAudioAttributes(
              usage: session.AndroidAudioUsage.voiceCommunication,
              contentType: session.AndroidAudioContentType.speech,
            ),
          ),
        );
        await _audioPlayer.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: false,
              audioMode: AndroidAudioMode.inCommunication,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  void _toggleKeyboard() {
    setState(() => _isKeyboardVisible = !_isKeyboardVisible);
  }

  void _endCall() {
    _isCallActive = false;
    _callTimer?.cancel();
    _pulseController.stop();
    unawaited(_audioPlayer.stop());
    unawaited(_safeStopRecorder());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _safeStopRecorder() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(_pulseController);
  }

  @override
  void dispose() {
    _isCallActive = false;
    _callTimer?.cancel();
    _pulseController.dispose();
    _audioPlayer.dispose();
    unawaited(_safeStopRecorder());
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
            colors: [Colors.black, Colors.grey.shade900, Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                            _callerName.isNotEmpty ? _callerName[0] : "?",
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
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                    if (_currentAiLine.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
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
                    if (_isKeyboardVisible)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            _isListening ? "Ascult..." : "Keypad",
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                child: Column(
                  children: [
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
                          icon: _isSpeakerOn
                              ? Icons.volume_up
                              : Icons.volume_off,
                          label: 'speaker',
                          isActive: _isSpeakerOn,
                          onPressed: _toggleSpeaker,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
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
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
