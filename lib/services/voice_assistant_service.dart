import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Handles converting spoken words into text (on-device, no API key
// needed) and speaking responses back to the user. The actual "which
// item did they mean" matching happens separately in the screen that
// uses this service, since that logic depends on the user's own items.
class VoiceAssistantService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  Future<bool> initialize() async {
    return await _speechToText.initialize();
  }

  bool get isListening => _speechToText.isListening;

  void startListening({required Function(String) onResult}) {
    _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
    );
  }

  void stopListening() {
    _speechToText.stop();
  }

  Future<void> speak(String text) async {
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  }
}