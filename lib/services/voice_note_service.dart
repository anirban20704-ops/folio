import 'package:speech_to_text/speech_to_text.dart';

/// Wraps speech_to_text. Transcription is done by the phone's own
/// speech recogniser - no extra AI API is used.
class VoiceNoteService {
  final SpeechToText _stt = SpeechToText();
  bool _ready = false;

  bool get isListening => _stt.isListening;

  Future<bool> init({void Function(String status)? onStatus}) async {
    _ready = await _stt.initialize(
      onStatus: onStatus,
      onError: (_) {},
    );
    return _ready;
  }

  Future<void> start(void Function(String text, bool isFinal) onResult) async {
    if (!_ready) return;
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stop() => _stt.stop();

  /// Light, rule-based tidy-up (no AI): trims, collapses spaces,
  /// capitalises the first letter and ends with a full stop.
  static String tidy(String raw) {
    var t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return t;
    t = t[0].toUpperCase() + t.substring(1);
    if (!RegExp(r'[.!?]$').hasMatch(t)) t = '$t.';
    return t;
  }
}
