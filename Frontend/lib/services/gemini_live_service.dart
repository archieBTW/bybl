import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

class GeminiLiveService {
  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool isConnected = false;
  bool isRecording = false;

  Function(String)? onMessage;
  Function()? onDisconnect;
  Function()? onPlaybackComplete;

  String _apiKey = '';
  String _modelName = 'gemini-3.8-flash';
  String _systemPrompt = '';
  http.Client? _httpClient;
  List<Uint8List> _recordedAudioChunks = [];
  
  Future<void> connect(String apiKey, String systemPrompt, {String modelName = 'gemini-3.8-flash'}) async {
    _apiKey = apiKey;
    _modelName = modelName;
    _systemPrompt = systemPrompt;
    isConnected = true;
    
    // Stop any existing playback
    _audioPlayer.stop();
    _audioChunks.clear();
    _isPlaying = false;
  }
  
  // Audio playback queue
  List<Uint8List> _audioChunks = [];
  bool _isPlaying = false;
  
  Future<void> _playAudioChunk(Uint8List pcmData) async {
      final wavData = _addWavHeader(pcmData);
      _audioChunks.add(wavData);
      _playNext();
  }

  Uint8List _extractPcm(Uint8List data, bool wasPcm) {
     if (wasPcm) return data;
     // Find 'data' chunk in WAV header
     for (int i = 0; i < data.length - 8; i++) {
        if (data[i] == 0x64 && data[i+1] == 0x61 && data[i+2] == 0x74 && data[i+3] == 0x61) {
           return data.sublist(i + 8);
        }
     }
     // Fallback: strip standard 44 byte header
     if (data.length > 44) return data.sublist(44);
     return data;
  }
  
  Future<void> _playNext() async {
      if (_isPlaying || _audioChunks.isEmpty) return;
      _isPlaying = true;
      final data = _audioChunks.removeAt(0);
      try {
        if (kIsWeb) {
           await _audioPlayer.play(UrlSource('data:audio/wav;base64,${base64Encode(data)}'));
        } else {
           await _audioPlayer.play(BytesSource(data));
        }
        await _audioPlayer.onPlayerComplete.first;
      } catch (e) {
        debugPrint('Audio play error: $e');
      } finally {
        _isPlaying = false;
        if (_audioChunks.isNotEmpty) {
           _playNext();
        } else {
           onPlaybackComplete?.call();
        }
      }
  }

  Uint8List _addWavHeader(Uint8List pcmData, {int sampleRate = 24000}) {
      int channels = 1;
      int bitDepth = 16;
      int byteRate = sampleRate * channels * (bitDepth ~/ 8);
      int dataSize = pcmData.length;
      int fileSize = 36 + dataSize;
      
      final header = ByteData(44);
      header.setUint8(0, 0x52); // 'R'
      header.setUint8(1, 0x49); // 'I'
      header.setUint8(2, 0x46); // 'F'
      header.setUint8(3, 0x46); // 'F'
      header.setUint32(4, fileSize, Endian.little);
      header.setUint8(8, 0x57); // 'W'
      header.setUint8(9, 0x41); // 'A'
      header.setUint8(10, 0x56); // 'V'
      header.setUint8(11, 0x45); // 'E'
      header.setUint8(12, 0x66); // 'f'
      header.setUint8(13, 0x6D); // 'm'
      header.setUint8(14, 0x74); // 't'
      header.setUint8(15, 0x20); // ' '
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little);
      header.setUint16(22, channels, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, byteRate, Endian.little);
      header.setUint16(32, channels * (bitDepth ~/ 8), Endian.little);
      header.setUint16(34, bitDepth, Endian.little);
      header.setUint8(36, 0x64); // 'd'
      header.setUint8(37, 0x61); // 'a'
      header.setUint8(38, 0x74); // 't'
      header.setUint8(39, 0x61); // 'a'
      header.setUint32(40, dataSize, Endian.little);

      final wavBytes = BytesBuilder();
      wavBytes.add(header.buffer.asUint8List());
      wavBytes.add(pcmData);
      return wavBytes.toBytes();
  }

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      isRecording = true;
      _recordedAudioChunks.clear();
      
      // If AI is talking, interrupt it.
      _httpClient?.close();
      _audioPlayer.stop();
      _audioChunks.clear();
      _isPlaying = false;

      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      stream.listen((data) {
        if (isRecording) {
          _recordedAudioChunks.add(data);
        }
      });
    }
  }

  Future<void> stopRecording() async {
    isRecording = false;
    await _audioRecorder.stop();
    
    if (_recordedAudioChunks.isEmpty) return;
    
    // Combine chunks
    int totalLen = _recordedAudioChunks.fold(0, (len, chunk) => len + chunk.length);
    final combined = Uint8List(totalLen);
    int offset = 0;
    for (var chunk in _recordedAudioChunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    final wavData = _addWavHeader(combined, sampleRate: 16000);
    
    _sendToGeminiRest([
      {
        "inlineData": {
          "mimeType": "audio/wav",
          "data": base64Encode(wavData)
        }
      }
    ]);
  }
  
  void sendTextMessage(String text) {
    if (isConnected) {
       _sendToGeminiTTS(text);
    }
  }

  Future<void> _sendToGeminiRest(List<Map<String, dynamic>> parts) async {
    _httpClient?.close();
    _httpClient = http.Client();
    
    try {
      final request = http.Request('POST', Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$_modelName:streamGenerateContent?alt=sse&key=$_apiKey'));
      request.headers['Content-Type'] = 'application/json';
      
      final mergedParts = <Map<String, dynamic>>[];
      if (_systemPrompt.isNotEmpty) {
        mergedParts.add({"text": "System Instruction: $_systemPrompt\n\n"});
      }
      mergedParts.addAll(parts);

      request.body = jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": mergedParts
          }
        ]
      });

      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
         final errorBody = await response.stream.bytesToString();
         debugPrint('API Error ${response.statusCode}: $errorBody');
         return;
      }

      String fullResponseText = '';

      response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (line.startsWith('data: ')) {
          try {
            final dataStr = line.substring(6);
            if (dataStr.trim().isEmpty) return;
            final data = jsonDecode(dataStr);
            if (data['candidates'] != null && data['candidates'].isNotEmpty) {
              final contentParts = data['candidates'][0]['content']['parts'] as List;
              for (var part in contentParts) {
                if (part['text'] != null) {
                  onMessage?.call(part['text']);
                  fullResponseText += part['text'];
                }
              }
            }
          } catch (e) {}
        }
      }, onDone: () {
        if (fullResponseText.isNotEmpty) {
           _sendToGeminiTTS(fullResponseText);
        }
      }, onError: (e) {});
    } catch (e) {
      debugPrint('Failed to send REST request: $e');
    }
  }

  Future<void> _sendToGeminiTTS(String textToSpeak) async {
      await _fallbackToLocalTTS(textToSpeak);
  }


  Future<void> _fallbackToLocalTTS(String text) async {
      String cleanText = text.replaceAll(RegExp(r'\*+'), '')
                             .replaceAll(RegExp(r'#+'), '')
                             .replaceAll(RegExp(r'```.*?```', dotAll: true), 'code block')
                             .replaceAll(RegExp(r'`.*?`'), '');
                             
      List<String> chunks = cleanText.split(RegExp(r'(?<=[.!?\n])\s+'));
      
      for (String chunk in chunks) {
          if (!isConnected) break;
          if (chunk.trim().isEmpty) continue;
          
          Completer<void> completer = Completer<void>();
          _flutterTts.setCompletionHandler(() {
              if (!completer.isCompleted) completer.complete();
          });
          _flutterTts.setErrorHandler((msg) {
              if (!completer.isCompleted) completer.complete();
          });
          
          await _flutterTts.speak(chunk);
          await completer.future;
      }
      
      if (isConnected) {
          onPlaybackComplete?.call();
      }
  }

  void disconnect() {
    _channel?.sink.close();
    _httpClient?.close();
    _audioRecorder.dispose();
    _flutterTts.stop();
    isConnected = false;
    onPlaybackComplete = null;
    try {
      _audioPlayer.dispose();
    } catch (e) {
      debugPrint('AudioPlayer dispose error: $e');
    }
  }
}
