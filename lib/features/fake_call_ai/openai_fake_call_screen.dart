import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as session;
import 'package:audioplayers/audioplayers.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'fake_call_scenario.dart';
import 'google_maps_services.dart';
import 'models.dart';
import 'navigation_controller.dart';
import 'speech_queue.dart';

class OpenAIFakeCallScreen extends StatefulWidget {
  final FakeCallScenario scenario;
  final String openAiApiKey;
  final String googleMapsApiKey;

  const OpenAIFakeCallScreen({
    super.key,
    required this.scenario,
    required this.openAiApiKey,
    required this.googleMapsApiKey,
  });

  @override
  State<OpenAIFakeCallScreen> createState() => _OpenAIFakeCallScreenState();
}

class _OpenAIFakeCallScreenState extends State<OpenAIFakeCallScreen> {
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  late final SpeechQueue _speechQueue;
  late final GoogleGeocodingService _geocodingService;
  late final NavigationController _navigationController;

  final List<OpenAIChatCompletionChoiceMessageModel> _messages = [];

  StreamSubscription<Position>? _locationSub;
  StreamSubscription<NavCue>? _navCueSub;

  String _subtitle = '';
  String _status = 'Conectare...';
  bool _muted = false;
  bool _speakerOn = true;
  bool _recording = false;
  bool _navigating = false;
  Duration _callDuration = Duration.zero;
  Timer? _timer;
  LatLng? _lastPosition;

  @override
  void initState() {
    super.initState();
    OpenAI.apiKey = widget.openAiApiKey;
    _geocodingService = GoogleGeocodingService(widget.googleMapsApiKey);
    _navigationController = NavigationController(
      routesService: GoogleRoutesService(widget.googleMapsApiKey),
    );
    _speechQueue = SpeechQueue(speak: _speak);
    _setupAudio();
    _setupChat();
    _listenLocation();
    _listenNavCues();
    _startTimer();
    _status = 'Conectat';
  }

  Future<void> _setupAudio() async {
    final audioSession = await session.AudioSession.instance;
    await audioSession.configure(
      const session.AudioSessionConfiguration(
        avAudioSessionCategory: session.AVAudioSessionCategory.playAndRecord,
        avAudioSessionMode: session.AVAudioSessionMode.voiceChat,
        androidAudioAttributes: session.AndroidAudioAttributes(
          contentType: session.AndroidAudioContentType.speech,
          usage: session.AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: session.AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ),
    );
  }

  void _setupChat() {
    _messages.add(
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.system,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            widget.scenario == FakeCallScenario.social
                ? 'Ești Tata într-un apel telefonic real. Vorbește calm, scurt, natural. Nu menționa AI.'
                : 'Ești dispecerat securitate într-un apel real. Vorbește scurt, calm, protector. Nu menționa AI.',
          ),
        ],
      ),
    );
  }

  void _listenLocation() {
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _locationSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (pos) {
            _lastPosition = LatLng(pos.latitude, pos.longitude);
            if (_navigating) {
              _navigationController.onLocationUpdate(_lastPosition!);
            }
          },
        );
  }

  void _listenNavCues() {
    _navCueSub = _navigationController.cues.listen((cue) {
      if (_muted) return;
      setState(() => _subtitle = cue.text);
      _speechQueue.add(cue.text, priority: cue.priority);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _speak(String text) async {
    if (_muted) return;

    await _player.stop();
    final dir = await getTemporaryDirectory();
    final outDir = Directory(dir.path);
    final outName = 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3';

    final speechFile = await OpenAI.instance.audio.createSpeech(
      model: 'tts-1',
      input: text,
      voice: OpenAIAudioVoice.onyx,
      responseFormat: OpenAIAudioSpeechResponseFormat.mp3,
      outputDirectory: outDir,
      outputFileName: outName,
    );

    await _player.play(
      DeviceFileSource(speechFile.path),
      volume: _speakerOn ? 1.0 : 0.2,
    );
    await _player.onPlayerComplete.first;

    try {
      if (await speechFile.exists()) await speechFile.delete();
    } catch (_) {}
  }

  Future<void> _recordAndSend() async {
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      setState(() => _status = 'Fără permisiune microfon');
      return;
    }

    setState(() {
      _recording = true;
      _status = 'Ascult...';
    });

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/user_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 16000,
      ),
      path: path,
    );

    await Future<void>.delayed(const Duration(seconds: 5));
    final recordedPath = await _recorder.stop();

    setState(() {
      _recording = false;
      _status = 'Procesez...';
    });

    if (recordedPath == null) {
      setState(() => _status = 'Nu am capturat audio.');
      return;
    }

    final transcription = await OpenAI.instance.audio.createTranscription(
      file: File(recordedPath),
      model: 'gpt-4o-mini-transcribe',
      language: 'ro',
      responseFormat: OpenAIAudioResponseFormat.json,
    );

    String text = '';
    if (transcription is OpenAITranscriptionModel) {
      text = transcription.text.trim();
    } else if (transcription is OpenAITranscriptionVerboseModel) {
      text = transcription.text.trim();
    }
    if (text.isEmpty) {
      setState(() => _status = 'Nu am înțeles.');
      return;
    }

    await _handleUserText(text);
  }

  Future<void> _handleUserText(String text) async {
    if (await _handleNavigationIntent(text)) {
      return;
    }

    _messages.add(
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [OpenAIChatCompletionChoiceMessageContentItemModel.text(text)],
      ),
    );

    final response = await OpenAI.instance.chat.create(
      model: 'gpt-4o-mini',
      messages: _messages,
      temperature: 0.6,
    );

    final reply =
        response.choices.first.message.content?.first.text?.toString() ?? '';
    _messages.add(
      OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.assistant,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(reply),
        ],
      ),
    );

    setState(() {
      _subtitle = reply;
      _status = 'Conectat';
    });

    _speechQueue.add(reply);
  }

  Future<bool> _handleNavigationIntent(String text) async {
    final lower = text.toLowerCase();

    if (lower.contains('oprește navigația') ||
        lower.contains('stop navigație')) {
      _navigationController.stop();
      setState(() {
        _navigating = false;
        _status = 'Navigație oprită';
      });
      _speechQueue.add('Am oprit navigația.');
      return true;
    }

    final destination = _extractDestination(lower);
    if (destination == null) return false;

    await _startNavigation(destination);
    return true;
  }

  String? _extractDestination(String text) {
    final patterns = [
      RegExp(r'vreau să ajung la\s+(.+)$'),
      RegExp(r'vreau să ajung în\s+(.+)$'),
      RegExp(r'du-mă la\s+(.+)$'),
      RegExp(r'navighează către\s+(.+)$'),
      RegExp(r'cum ajung la\s+(.+)$'),
      RegExp(r'cum ajung în\s+(.+)$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }

    return null;
  }

  Future<void> _startNavigation(String destinationText) async {
    if (_lastPosition == null) {
      setState(() => _status = 'Aștept locația GPS...');
      return;
    }

    setState(() {
      _status = 'Caut destinația...';
    });

    try {
      final destination = await _geocodingService.geocode(destinationText);
      await _navigationController.start(
        origin: _lastPosition!,
        destination: destination,
      );
      setState(() {
        _navigating = true;
        _status = 'Navigație activă';
      });
    } catch (e) {
      setState(() => _status = 'Nu pot porni navigația');
      _speechQueue.add('Nu pot porni navigația acum.');
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes % 60);
    final seconds = twoDigits(d.inSeconds % 60);
    return '${twoDigits(d.inHours)}:$minutes:$seconds';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSub?.cancel();
    _navCueSub?.cancel();
    _navigationController.dispose();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.scenario == FakeCallScenario.social
        ? 'Tata'
        : 'Dispecerat Securitate';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDuration(_callDuration),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _subtitle.isEmpty ? '...' : _subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const SizedBox(height: 12),
            Text(_status, style: const TextStyle(color: Colors.white54)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildControl(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Mute' : 'Mic',
                    onTap: () => setState(() => _muted = !_muted),
                  ),
                  _buildRecordButton(),
                  _buildControl(
                    icon: _speakerOn ? Icons.volume_up : Icons.volume_mute,
                    label: _speakerOn ? 'Speaker' : 'Jos',
                    onTap: () => setState(() => _speakerOn = !_speakerOn),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _recordAndSend,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: _recording ? Colors.red : Colors.green,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _recording ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 28),
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
