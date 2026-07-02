import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class AudioRoutingService {
  static final AudioRoutingService _instance = AudioRoutingService._internal();

  bool _isSpeakerEnabled = false;

  factory AudioRoutingService() {
    return _instance;
  }

  AudioRoutingService._internal();

  Future<void> initializeCallAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.audibilityEnforced,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );
    } catch (e) {
      debugPrint('Error initializing audio session: $e');
    }
  }

  Future<void> enableSpeaker() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      _isSpeakerEnabled = true;
      debugPrint('Speaker enabled');
    } catch (e) {
      debugPrint('Error enabling speaker: $e');
    }
  }

  Future<void> disableSpeaker() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      _isSpeakerEnabled = false;
      debugPrint('Speaker disabled');
    } catch (e) {
      debugPrint('Error disabling speaker: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    if (_isSpeakerEnabled) {
      await disableSpeaker();
    } else {
      await enableSpeaker();
    }
  }

  bool get isSpeakerEnabled => _isSpeakerEnabled;
}
