import 'dart:async';

class SpeechQueue {
  final Future<void> Function(String text) speak;
  final List<_SpeechItem> _queue = [];
  bool _busy = false;

  SpeechQueue({required this.speak});

  void add(String text, {bool priority = false}) {
    if (priority) {
      _queue.insert(0, _SpeechItem(text));
    } else {
      _queue.add(_SpeechItem(text));
    }
    _pump();
  }

  void clear() {
    _queue.clear();
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    while (_queue.isNotEmpty) {
      final item = _queue.removeAt(0);
      try {
        await speak(item.text);
      } catch (_) {
        // ignore TTS errors to keep queue moving
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    _busy = false;
  }
}

class _SpeechItem {
  final String text;

  _SpeechItem(this.text);
}
