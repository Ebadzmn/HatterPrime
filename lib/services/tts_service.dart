import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();

  static Future<void> speak(String text) async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(text);
      debugPrint("TTS Spoke: '$text'");
    } catch (e) {
      debugPrint("TTS Error speaking text '$text': $e");
    }
  }
}
