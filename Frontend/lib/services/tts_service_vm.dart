import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class TtsService {
  // Singleton instance
  static final TtsService _instance = TtsService._internal();

  factory TtsService() {
    return _instance;
  }

  TtsService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;
  String? _appDocPath;

  // Isolate communication
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  final Map<int, Completer<String?>> _pendingRequests = {};
  int _requestIdCounter = 0;

  Future<void>? _initFuture;

  Future<void> init() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    final docDir = await getApplicationDocumentsDirectory();
    _appDocPath = docDir.path;

    // Check/Extract assets first (fast check)
    await _prepareAssets(_appDocPath!);

    // Spawn Isolate
    final initCompleter = Completer<void>();
    _receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        // Send config to isolate
        _sendPort!.send({'command': 'init', 'appDocPath': _appDocPath});
      } else if (message is Map) {
        final cmd = message['command'];
        if (cmd == 'init_done') {
          if (message['success'] == true) {
            _isInitialized = true;
            print("TTS Isolate Initialized.");
            initCompleter.complete();
          } else {
            print("TTS Isolate Init Failed: ${message['error']}");
            initCompleter.completeError(message['error']);
          }
        } else if (cmd == 'generated') {
          final id = message['id'] as int;
          final path = message['path'] as String?;
          if (_pendingRequests.containsKey(id)) {
            _pendingRequests[id]?.complete(path);
            _pendingRequests.remove(id);
          }
        }
      }
    });

    _isolate = await Isolate.spawn(_ttsIsolateEntry, _receivePort.sendPort);
    await initCompleter.future;
  }

  // Asset preparation logic
  // Force update assets every launch to ensure new tokens.txt is used
  Future<void> _prepareAssets(String docPath) async {
    print("--- ASSET PREPARATION START ---");
    try {
      final modelData = await rootBundle.load('assets/models/model.onnx');
      final tokensData = await rootBundle.load('assets/models/tokens.txt');
      final lexiconData = await rootBundle.load('assets/models/lexicon.txt');
      final espeakData =
          await rootBundle.load('assets/models/espeak-ng-data.zip');

      print("Load successful. Writing to device...");

      await Isolate.run(() => _writeAssets(
          docPath,
          modelData.buffer.asUint8List(),
          tokensData.buffer.asUint8List(),
          lexiconData.buffer.asUint8List(),
          espeakData.buffer.asUint8List()));
    } catch (e) {
      print("Asset extraction failed: $e");
    }
  }

  static Future<void> _writeAssets(
      String docPath,
      Uint8List modelBytes,
      Uint8List tokensBytes,
      Uint8List lexiconBytes,
      Uint8List espeakBytes) async {
    final modelDir = Directory(p.join(docPath, 'sherpa_models'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    // 1. Write Model (Binary, write as-is)
    await File(p.join(modelDir.path, 'model.onnx'))
        .writeAsBytes(modelBytes, flush: true);

    // 2. Write Tokens (Sanitize Windows CRLF -> LF)
    final tokensString = utf8.decode(tokensBytes);
    final sanitizedTokens = tokensString.replaceAll('\r\n', '\n');
    await File(p.join(modelDir.path, 'tokens.txt'))
        .writeAsString(sanitizedTokens, flush: true);

    // 3. Write Lexicon (Sanitize Windows CRLF -> LF)
    final lexiconString = utf8.decode(lexiconBytes);
    final sanitizedLexicon = lexiconString.replaceAll('\r\n', '\n');
    await File(p.join(modelDir.path, 'lexicon.txt'))
        .writeAsString(sanitizedLexicon, flush: true);

    // Debug: Verify the clean files
    print(
        ">>> Tokens written. First line: '${sanitizedTokens.split('\n').first}'");
    print(
        ">>> Lexicon written. First line: '${sanitizedLexicon.split('\n').first}'");

    // 4. Extract Espeak
    // (Note: We changed the path slightly to be safer - ensure your code points to this location)
    final espeakDir = Directory(p.join(modelDir.path, 'espeak-ng-data'));
    if (espeakDir.existsSync()) {
      espeakDir.deleteSync(recursive: true);
    }
    espeakDir.createSync(recursive: true);

    print("Extracting espeak...");
    final archive = ZipDecoder().decodeBytes(espeakBytes);
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        // Create full path
        final fullPath = p.join(modelDir.path, filename);
        // Create parent directories if they don't exist
        File(fullPath).parent.createSync(recursive: true);
        File(fullPath).writeAsBytesSync(data);
      }
    }

    print("TTS assets ready.");
  }

  // static Future<void> _writeAssets(
  //     String docPath,
  //     Uint8List modelBytes,
  //     Uint8List tokensBytes,
  //     Uint8List lexiconBytes,
  //     Uint8List espeakBytes) async {
  //   final modelDir = Directory(p.join(docPath, 'sherpa_models'));
  //   if (await modelDir.exists()) await modelDir.delete(recursive: true);
  //   await modelDir.create(recursive: true);

  //   await File(p.join(modelDir.path, 'model.onnx')).writeAsBytes(modelBytes);
  //   await File(p.join(modelDir.path, 'tokens.txt')).writeAsBytes(tokensBytes);
  //   // [NEW] Write the lexicon
  //   await File(p.join(modelDir.path, 'lexicon.txt')).writeAsBytes(lexiconBytes);

  //   // ... (Espeak extraction logic remains the same) ...

  //   await File(p.join(modelDir.path, 'assets_v14.txt')).create();
  // }

  // --- Isolate Entry Point ---
  static void _ttsIsolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    OfflineTts? tts;
    String? appDocPath;

    receivePort.listen((message) async {
      if (message is Map) {
        final cmd = message['command'];

        if (cmd == 'init') {
          try {
            appDocPath = message['appDocPath'];
            initBindings(); // Initialize Sherpa Native Bindings

            final modelDir = p.join(appDocPath!, 'sherpa_models');

            // ----------------------------------------------------------------------
            // 1. Locate Lexicon (if available)
            // ----------------------------------------------------------------------
            String? lexiconPath;
            final possibleLexicon = File(p.join(modelDir, 'lexicon.txt'));
            if (possibleLexicon.existsSync()) {
              print("Found lexicon.txt at: ${possibleLexicon.path}");
              lexiconPath = possibleLexicon.path;
            }

            // ----------------------------------------------------------------------
            // 2. Locate Espeak Data Dir (Recursive Search for 'phontab')
            // ----------------------------------------------------------------------
            // This fixes issues where unzip creates double folders like espeak-ng-data/espeak-ng-data/
            String? dataDir;

            String? findPhontabDir(Directory dir) {
              try {
                final List<FileSystemEntity> entities =
                    dir.listSync(recursive: false);

                // Check current level
                for (var entity in entities) {
                  if (entity is File && p.basename(entity.path) == 'phontab') {
                    return dir.path;
                  }
                }

                // Check subdirectories
                for (var entity in entities) {
                  if (entity is Directory) {
                    String? result = findPhontabDir(entity);
                    if (result != null) return result;
                  }
                }
              } catch (e) {
                print("Error searching dir: $e");
              }
              return null;
            }

            dataDir = findPhontabDir(Directory(modelDir));

            // Fallback: If recursive search failed, try the standard path just in case
            if (dataDir == null) {
              final standardPath = p.join(modelDir, 'espeak-ng-data');
              if (Directory(standardPath).existsSync()) {
                dataDir = standardPath;
              }
            }

            // ----------------------------------------------------------------------
            // 3. Configure & Initialize
            // ----------------------------------------------------------------------
            print("--- TTS CONFIG ---");
            print("Model: ${p.join(modelDir, 'model.onnx')}");
            print("Lexicon: $lexiconPath");
            print("DataDir (Computed): $dataDir");
            print("------------------");

            final config = OfflineTtsConfig(
              model: OfflineTtsModelConfig(
                vits: OfflineTtsVitsModelConfig(
                  model: p.join(modelDir, 'model.onnx'),
                  tokens: p.join(modelDir, 'tokens.txt'),
                  dataDir: dataDir ?? '', // Must be valid path or empty string
                  lexicon: lexiconPath ?? '',
                  lengthScale: 1.0,
                ),
                numThreads: 4,
                debug: true,
                provider: 'cpu',
              ),
              ruleFsts: '',
              silenceScale: 0.6,
            );

            tts = OfflineTts(config);

            // Sanity Check: Try generating silence to ensure C++ loaded correctly
            try {
              tts!.generate(text: "Test", sid: 0, speed: 1.0);
              mainSendPort.send({'command': 'init_done', 'success': true});
            } catch (e) {
              throw Exception("Model loaded, but generation test failed: $e");
            }
          } catch (e) {
            print("TTS Init Error: $e");
            mainSendPort.send({
              'command': 'init_done',
              'success': false,
              'error': e.toString()
            });
          }
        } else if (cmd == 'generate') {
          final id = message['id'];
          final text = message['text'];
          final filename = message['filename'];

          try {
            if (tts == null) throw Exception("TTS not initialized");

            final result = tts!.generate(text: text, sid: 0, speed: 1.0);
            if (result.samples.isEmpty) {
              mainSendPort
                  .send({'command': 'generated', 'id': id, 'path': null});
              return;
            }

            final wavFile = File(p.join(appDocPath!, filename));
            await _writeWavFileStatic(
                wavFile, result.samples, result.sampleRate);

            mainSendPort
                .send({'command': 'generated', 'id': id, 'path': wavFile.path});
          } catch (e) {
            print("Worker generation error: $e");
            mainSendPort.send({'command': 'generated', 'id': id, 'path': null});
          }
        }
      }
    });
  }

  // --- Isolate Entry Point ---
  // static void _ttsIsolateEntry(SendPort mainSendPort) {
  //   final receivePort = ReceivePort();
  //   mainSendPort.send(receivePort.sendPort);

  //   OfflineTts? tts;
  //   String? appDocPath;

  //   receivePort.listen((message) async {
  //     if (message is Map) {
  //       final cmd = message['command'];

  //       if (cmd == 'init') {
  //         try {
  //           appDocPath = message['appDocPath'];
  //           initBindings();

  //           final modelDir = p.join(appDocPath!, 'sherpa_models');

  //           // Debug: List files to verify extraction
  //           try {
  //             print("Debug: Listing files in $modelDir");
  //             final files = Directory(modelDir).listSync(recursive: true);
  //             for (var f in files) {
  //               print(" - ${f.path}");
  //             }
  //           } catch (e) {
  //             print("Debug: Failed to list files: $e");
  //           }

  //           // ----------------------------------------------------------------------
  //           // Data Dir & Lexicon Logic
  //           // ----------------------------------------------------------------------
  //           String? lexiconPath;
  //           // Check if user provided lexicon.txt (Robust Fix)
  //           final possibleLexicon = File(p.join(modelDir, 'lexicon.txt'));
  //           if (possibleLexicon.existsSync()) {
  //             print(
  //                 "Found lexicon.txt at: ${possibleLexicon.path}. Using it instead of espeak-ng-data (if possible).");
  //             lexiconPath = possibleLexicon.path;
  //           }

  //           // Dynamically find espeak-ng-data path (Fallback or Complement)
  //           String? foundDataDir;
  //           String? findEspeakDir(Directory dir) {
  //             try {
  //               final entities = dir.listSync(followLinks: false);
  //               for (final entity in entities) {
  //                 if (entity is File && p.basename(entity.path) == 'phontab') {
  //                   return dir.path;
  //                 }
  //               }
  //               for (final entity in entities) {
  //                 if (entity is Directory) {
  //                   final res = findEspeakDir(entity);
  //                   if (res != null) return res;
  //                 }
  //               }
  //             } catch (e) {/* ignore */}
  //             return null;
  //           }

  //           foundDataDir = findEspeakDir(Directory(modelDir));
  //           if (foundDataDir == null) {
  //             foundDataDir =
  //                 p.join(modelDir, 'espeak-ng-data'); // Default guess
  //           }

  //           // Verify content of dataDir (only if not using lexicon exclusively)
  //           if (lexiconPath == null) {
  //             // Only verify if we are relying on espeak-ng-data
  //             try {
  //               final dataDirFiles = Directory(foundDataDir!).listSync();
  //               print("Espeak DataDir Content (${dataDirFiles.length} files):");
  //               if (dataDirFiles.isEmpty) {
  //                 print("WARNING: espeak-ng-data directory is EMPTY!");
  //               }
  //               // Check specifically for phontab
  //               if (!File(p.join(foundDataDir!, 'phontab')).existsSync()) {
  //                 print(
  //                     "CRITICAL: phontab not found in $foundDataDir even though we thought we found it?");
  //               }
  //             } catch (e) {
  //               print("Error listing dataDir: $e");
  //             }
  //           } else {
  //             print(
  //                 "Lexicon.txt found, skipping espeak-ng-data content verification.");
  //           }

  //           final config = OfflineTtsConfig(
  //             model: OfflineTtsModelConfig(
  //               vits: OfflineTtsVitsModelConfig(
  //                 model: p.join(modelDir, 'model.onnx'),
  //                 tokens: p.join(modelDir, 'tokens.txt'),
  //                 dataDir: foundDataDir, // Still provide it if we found it
  //                 lexicon: lexiconPath ?? '', // Provide lexicon if found
  //                 lengthScale: 1.0,
  //               ),
  //               numThreads: 4,
  //               debug: false,
  //               provider: 'cpu', // Fallback to CPU to avoid NNAPI/API21 issues
  //             ),
  //             ruleFsts: '',
  //           );

  //           tts = OfflineTts(config);
  //           mainSendPort.send({'command': 'init_done', 'success': true});
  //         } catch (e) {
  //           print("TTS Init Error: $e");
  //           mainSendPort.send({
  //             'command': 'init_done',
  //             'success': false,
  //             'error': e.toString()
  //           });
  //         }
  //       } else if (cmd == 'generate') {
  //         final id = message['id'];
  //         final text = message['text'];
  //         final filename = message['filename'];

  //         try {
  //           if (tts == null) throw Exception("TTS not initialized");

  //           final result = tts!.generate(text: text, sid: 0, speed: 1.0);
  //           if (result.samples.isEmpty) {
  //             mainSendPort
  //                 .send({'command': 'generated', 'id': id, 'path': null});
  //             return;
  //           }

  //           final wavFile = File(p.join(appDocPath!, filename));
  //           await _writeWavFileStatic(
  //               wavFile, result.samples, result.sampleRate);

  //           mainSendPort
  //               .send({'command': 'generated', 'id': id, 'path': wavFile.path});
  //         } catch (e) {
  //           print("Worker generation error: $e");
  //           mainSendPort.send({'command': 'generated', 'id': id, 'path': null});
  //         }
  //       }
  //     }
  //   });
  // }

// Static WAV writer for isolate (Robust Version)
  static Future<void> _writeWavFileStatic(
      File file, Float32List samples, int sampleRate) async {
    // 1. Diagnostics: Check if audio data is valid or just noise/silence
    double maxVal = 0.0;
    for (var s in samples) {
      if (s.abs() > maxVal) maxVal = s.abs();
    }
    print(
        "Writing WAV: SampleRate=$sampleRate Hz, Duration=${samples.length / sampleRate}s, MaxAmplitude=$maxVal");

    // 2. Prepare integer samples (16-bit PCM)
    final int16Samples = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      var s = samples[i];
      // Hard clip to prevent overflow static
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      // Convert to 16-bit integer (Little Endian standard)
      int16Samples[i] = (s * 32767).toInt();
    }

    // 3. Construct WAV Header manually
    final int channels = 1;
    final int byteRate = sampleRate * channels * 2;
    final int blockAlign = channels * 2;
    final int bitsPerSample = 16;
    final int dataSize = int16Samples.length * 2;
    final int chunkSize = 36 + dataSize;

    final header = Uint8List(44);
    final view = ByteData.view(header.buffer);

    view.setUint32(0, 0x52494646, Endian.big); // RIFF
    view.setUint32(4, chunkSize, Endian.little);
    view.setUint32(8, 0x57415645, Endian.big); // WAVE

    view.setUint32(12, 0x666d7420, Endian.big); // fmt
    view.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    view.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);

    view.setUint32(36, 0x64617461, Endian.big); // data
    view.setUint32(40, dataSize, Endian.little);

    // 4. Write to file safely
    final raf = await file.open(mode: FileMode.write);
    await raf.writeFrom(header);

    // Explicitly write Int16 samples as Little Endian bytes
    // (Avoiding buffer.asUint8List() to rule out system endianness issues)
    final audioByteData = ByteData(int16Samples.length * 2);
    for (int i = 0; i < int16Samples.length; i++) {
      audioByteData.setInt16(i * 2, int16Samples[i], Endian.little);
    }
    await raf.writeFrom(audioByteData.buffer.asUint8List());

    await raf.close();
  }

  // Static WAV writer for isolate
  // static Future<void> _writeWavFileStatic(
  //     File file, Float32List samples, int sampleRate) async {
  //   final int16Samples = Int16List(samples.length);
  //   for (int i = 0; i < samples.length; i++) {
  //     var s = samples[i];
  //     if (s > 1.0) s = 1.0;
  //     if (s < -1.0) s = -1.0;
  //     int16Samples[i] = (s * 32767).toInt();
  //   }

  //   final int channels = 1;
  //   final int byteRate = sampleRate * channels * 2;
  //   final int blockAlign = channels * 2;
  //   final int bitsPerSample = 16;
  //   final int dataSize = int16Samples.length * 2;
  //   final int chunkSize = 36 + dataSize;

  //   final header = Uint8List(44);
  //   final view = ByteData.view(header.buffer);

  //   view.setUint32(0, 0x52494646, Endian.big);
  //   view.setUint32(4, chunkSize, Endian.little);
  //   view.setUint32(8, 0x57415645, Endian.big);

  //   view.setUint32(12, 0x666d7420, Endian.big);
  //   view.setUint32(16, 16, Endian.little);
  //   view.setUint16(20, 1, Endian.little);
  //   view.setUint16(22, channels, Endian.little);
  //   view.setUint32(24, sampleRate, Endian.little);
  //   view.setUint32(28, byteRate, Endian.little);
  //   view.setUint16(32, blockAlign, Endian.little);
  //   view.setUint16(34, bitsPerSample, Endian.little);

  //   view.setUint32(36, 0x64617461, Endian.big);
  //   view.setUint32(40, dataSize, Endian.little);

  //   final raf = await file.open(mode: FileMode.write);
  //   await raf.writeFrom(header);
  //   await raf.writeFrom(int16Samples.buffer.asUint8List());
  //   await raf.close();
  // }

  /// Generates audio for the text and returns the path to the WAV file.
  Future<String?> generateAudio(String text, {String? outputFileName}) async {
    if (!_isInitialized || _sendPort == null) return null;

    final id = _requestIdCounter++;
    final completer = Completer<String?>();
    _pendingRequests[id] = completer;

    String normalizedText = _normalizeText(text);
    // normalizedText = normalizedText.replaceAll('chapter', 'chap-tur');

    final fileName = outputFileName ??
        'temp_speech_${DateTime.now().millisecondsSinceEpoch}.wav';

    _sendPort!.send({
      'command': 'generate',
      'id': id,
      'text': normalizedText,
      'filename': fileName
    });

    return completer.future;
  }

  Future<void> playAudio(String filePath, {Function()? onCompletion}) async {
    if (!File(filePath).existsSync()) {
      if (onCompletion != null) onCompletion();
      return;
    }

    final completer = Completer<void>();
    final subscription = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });

    try {
      await _player.play(DeviceFileSource(filePath));
      await completer.future;
    } catch (e) {
      print("Error during playback: $e");
    } finally {
      subscription.cancel();
    }

    if (onCompletion != null) {
      onCompletion();
    }
  }

  Future<void> speak(String text, {Function()? onCompletion}) async {
    final wavPath =
        await generateAudio(text, outputFileName: 'temp_speech.wav');
    if (wavPath != null) {
      await playAudio(wavPath, onCompletion: onCompletion);
    } else {
      if (onCompletion != null) onCompletion();
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  String _normalizeText(String text) {
    // 1. Keep strict punctuation (You likely already did this)
    // We allow . , ? ! ; : and -
    String res = text.replaceAll(RegExp(r'[^\w\s\-\.\,\?\!\;\:]'), '');

    // 2. Convert to lowercase (Standard for VITS)
    res = res.toLowerCase();

    // 3. Numbers to words
    res = res.replaceAllMapped(RegExp(r'\b\d+\b'), (match) {
      final numStr = match.group(0)!;
      final num = int.tryParse(numStr);
      if (num != null) return _numberToWords(num);
      return numStr;
    });

    // ---------------------------------------------------------
    // THE FIX: Force hard breaks before sentence-starting conjunctions
    // ---------------------------------------------------------

    // Pattern: Period -> (any whitespace) -> "and"
    // We replace it with: Period -> Newline -> "and"
    // This forces the TTS to stop, breathe, and start the new line.
    res = res.replaceAll(RegExp(r'\.\s+and\b'), '.\nand');

    // Do the same for "but" if you notice it there too
    res = res.replaceAll(RegExp(r'\.\s+but\b'), '.\nbut');

    // Optional: Double the period for extra dramatic pause if Newline isn't enough
    // res = res.replaceAll(RegExp(r'\.\s+and\b'), '.. and');

    return res;
  }

  String _numberToWords(int number) {
    if (number == 0) return "zero";

    final units = [
      "",
      "one",
      "two",
      "three",
      "four",
      "five",
      "six",
      "seven",
      "eight",
      "nine",
      "ten",
      "eleven",
      "twelve",
      "thirteen",
      "fourteen",
      "fifteen",
      "sixteen",
      "seventeen",
      "eighteen",
      "nineteen"
    ];
    final tens = [
      "",
      "",
      "twenty",
      "thirty",
      "forty",
      "fifty",
      "sixty",
      "seventy",
      "eighty",
      "ninety"
    ];

    if (number < 20) return units[number];

    if (number < 100) {
      return "${tens[number ~/ 10]}${number % 10 != 0 ? " " + units[number % 10] : ""}";
    }

    if (number < 1000) {
      return "${units[number ~/ 100]} hundred${number % 100 != 0 ? " " + _numberToWords(number % 100) : ""}";
    }

    return number.toString();
  }
}
