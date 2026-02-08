import 'dart:async';

class TtsService {
  // Singleton instance
  static final TtsService _instance = TtsService._internal();

  factory TtsService() {
    return _instance;
  }

  TtsService._internal();

  Future<void> init() async {
    print("TTS Service (Web): Init is a no-op on web.");
  }

  Future<String?> generateAudio(String text, {String? outputFileName}) async {
    print("TTS Service (Web): generateAudio is not supported on web.");
    return null;
  }

  Future<void> playAudio(String filePath, {Function()? onCompletion}) async {
    print("TTS Service (Web): playAudio is not supported on web.");
    if (onCompletion != null) onCompletion();
  }

  Future<void> speak(String text, {Function()? onCompletion}) async {
    print("TTS Service (Web): speak is not supported on web.");
    if (onCompletion != null) onCompletion();
  }

  Future<void> stop() async {
    print("TTS Service (Web): stop is a no-op on web.");
  }
}
