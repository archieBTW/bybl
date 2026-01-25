import 'dart:async';
import 'dart:convert';
import 'package:TheWord/screens/main_app.dart';
import 'package:TheWord/screens/settings_screen.dart';
import 'package:TheWord/shared/widgets/highlight_text.dart';
import 'package:TheWord/shared/widgets/api_key_setup_prompt.dart';
import 'package:TheWord/services/local_storage_service.dart';
import 'package:TheWord/models/local_bookmark.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import '../services/chat_service.dart';
import '../shared/widgets/ai_disclaimer.dart';

class ReaderScreen extends StatefulWidget {
  String chapterId;
  final String chapterName;
  final List<dynamic> chapterIds;
  final List<dynamic> chapterNames;
  final String bookName;
  final String translationName;
  final String translationId;
  final String bookId;

  ReaderScreen(
      {required this.chapterId,
      required this.chapterName,
      required this.chapterIds,
      required this.chapterNames,
      required this.bookName,
      required this.translationName,
      required this.translationId,
      required this.bookId});

  @override
  ReaderScreenState createState() => ReaderScreenState();
}

class ReaderScreenState extends State<ReaderScreen> {
  // final String scriptureApiKey = dotenv.env['BIBLE_KEY'] ?? '';
  // final String esvApiKey = dotenv.env['ESV_KEY'] ?? '';

  late PageController _pageController;

  Map<String, List<Map<String, dynamic>>> _chapterContents = {};
  Map<String, String?> _chapterCopyrights = {};

  bool isLoading = true;
  bool isSummaryLoading = false;

  bool isReading = false;
  bool isPaused = false;
  bool isSkipping = false;
  int? currentVerseIndex;

  int currentPageIndex = 0;
  String chapterName = '';
  bool pageChanging = false;

  FlutterTts flutterTts = FlutterTts();

  ChatService chatService = ChatService();

  final GlobalKey<SelectableTextHighlightState> highlightKey =
      GlobalKey<SelectableTextHighlightState>();

  final Map<String, ScrollController> _scrollControllers = {};

  @override
  void initState() {
    super.initState();
    print('init------------------');
    chapterName = widget.chapterName;

    final initialIndex = widget.chapterIds.indexOf(widget.chapterId);
    currentPageIndex = initialIndex >= 0 ? initialIndex : 0;

    _pageController = PageController(
      initialPage: currentPageIndex,
    );

    _fetchChapterContent(widget.chapterId);
    _preloadAdjacentChapters(widget.chapterId);

    flutterTts.setCompletionHandler(() {
      if (!isSkipping) {
        _readNextVerse();
      }
      isSkipping = false;
    });

    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
    flutterTts.setLanguage('en-US');
    flutterTts.awaitSpeakCompletion(true);
  }

  @override
  void dispose() {
    flutterTts.stop();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ScrollController _getScrollController(String chapterId) {
    return _scrollControllers.putIfAbsent(chapterId, () => ScrollController());
  }

  String? _lastPreloadedChapterId;

  Future<void> _fetchChapterContent(String chapterId,
      {bool showLoading = true}) async {
    print(chapterId);
    // final settingsProvider =
    // Provider.of<SettingsProvider>(context, listen: false);
    final translationId = widget.translationId;

    if (_chapterContents.containsKey(chapterId)) {
      if (chapterId == widget.chapterId) {
        setState(() => isLoading = false);
      }
      return;
    }

    if (showLoading) {
      setState(() => isLoading = true);
    }

    try {
      final response = await http.get(Uri.parse(
        'https://api.bybl.dev/api/passage/$translationId?q=$chapterId',
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawContent = data['data']['content'];
        
        // Extract copyright information from the API response
        final copyright = data['data']['copyright'] as String?;
        _chapterCopyrights[chapterId] = copyright;

        if (rawContent is! List) {
          _chapterContents[chapterId] = [];
        } else {
          final verses = _extractScriptureApiVerses(rawContent);

          if (translationId.toUpperCase() == 'ESV') {
            for (final v in verses) {
              final parts = (v['id'] as String).split('.');
              v['id'] = parts.isNotEmpty ? parts.last : v['id'];
            }
          }

          _chapterContents[chapterId] = verses;
        }
      } else {
        _chapterContents[chapterId] = [];
        _chapterCopyrights[chapterId] = null;
      }
    } catch (e, stack) {
      _chapterContents[chapterId] = [];
      _chapterCopyrights[chapterId] = null;
    } finally {
      if (showLoading && chapterId == widget.chapterId) {
        setState(() => isLoading = false);
      }
    }
  }

  _fetchChapterVersesFromBackend(String chapterId, String translationId) async {
    final reference = chapterId.replaceAll('.', ' ');
    final isEsv = translationId.toUpperCase() == 'ESV';
    final uri = Uri.parse(
      isEsv
          ? 'https://api.bybl.dev/api/passage/$translationId?q=$reference'
          : 'https://api.bybl.dev/api/bible/$translationId/chapters/$chapterId?content-type=json',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch chapter content');
    }

    final data = json.decode(response.body);

    if (isEsv) {
      final passages = (data['data'] as List)
          .map((item) => item['content'] as String)
          .join('\n')
          .trim();
      return _parseEsvVerses(passages);
    } else {
      final rawContent = data['data']['content'];
      return _extractScriptureApiVerses(rawContent);
    }
  }

  List<Map<String, dynamic>> _extractScriptureApiVerses(dynamic raw) {
    final verses = <Map<String, dynamic>>[];
    String? activeId; // track current verse-id

    for (final para in (raw as List)) {
      if (para is! Map || para['name'] != 'para') continue;

      for (final item in (para['items'] as List)) {
        // ── ① a normal “verse” wrapper ─────────────────────────────
        if (item['name'] == 'verse' && item['attrs'] is Map) {
          activeId = item['attrs']['sid'] ?? item['attrs']['verseId'];
          final buf = StringBuffer();
          for (final t in (item['items'] as List? ?? const [])) {
            if (t['type'] == 'text') buf.write(t['text'] ?? '');
          }
          final txt = buf
              .toString()
              .trim()
              .replaceFirst(RegExp(r'^\s*\[?\d+\]?'), ''); // drop [7]

          if (activeId != null && txt.isNotEmpty) {
            _appendOrMergeVerse(verses, activeId!, txt);
          }
          continue;
        }

        // ── ② a stand-alone text node (often Scripture-API “partial”) ──
        if (item['type'] == 'text') {
          final txt = (item['text'] ?? '').trim();
          if (txt.isEmpty) continue;

          // explicit verseId wins, otherwise fall back to current
          final vId = (item['attrs']?['verseId'] ?? activeId) as String?;
          if (vId != null && vId.isNotEmpty) {
            _appendOrMergeVerse(verses, vId, txt);
            activeId = vId; // keep tracking
          }
        }
      }
    }
    return verses;
  }

  List<Map<String, dynamic>> _parseEsvVerses(String esvText) {
    final List<Map<String, dynamic>> verses = [];

    // Replace new-lines with spaces so we can split cleanly
    final cleaned = esvText.replaceAll('\n', ' ').trim();

    // Match any sequence like 1 … 2 … 3 …
    final regex = RegExp(r'\s*(\d+)\s+');
    final matches = regex.allMatches(cleaned);

    for (int i = 0; i < matches.length; i++) {
      final start = matches.elementAt(i).end;
      final end = (i + 1 < matches.length)
          ? matches.elementAt(i + 1).start
          : cleaned.length;

      final verseNum = matches.elementAt(i).group(1)!; // "3"
      final verseText = cleaned.substring(start, end).trim(); // text of verse

      if (verseText.isNotEmpty) {
        verses.add({'id': verseNum, 'text': verseText});
      }
    }

    // Fallback (entire chapter as one verse) – rarely needed
    if (verses.isEmpty && cleaned.isNotEmpty) {
      verses.add({'id': '1', 'text': cleaned});
    }

    return verses;
  }

// ──────────────────────────────────────────────────────────────────────────────
// 2.  Helper used by _extractScriptureApiVerses
//     Converts IDs like "NUM 2:3"  →  "NUM.2.3"
//     so SelectableTextHighlight works the same way it always has.
// ──────────────────────────────────────────────────────────────────────────────
  void _appendOrMergeVerse(
      List<Map<String, dynamic>> verses, String rawId, String verseText) {
    // normalise: spaces & colons → dots
    final normId = rawId.replaceAll(RegExp(r'[: ]'), '.');

    final existingIdx = verses.indexWhere((v) => v['id'] == normId);
    if (existingIdx != -1) {
      verses[existingIdx]['text'] =
          '${verses[existingIdx]['text']} $verseText'.trim();
    } else {
      verses.add({'id': normId, 'text': verseText});
    }
  }

  void _startReading() {
    final content = _chapterContents[widget.chapterId];
    if (content == null || content.isEmpty) return;

    setState(() {
      isReading = true;
      isPaused = false;
      currentVerseIndex = 0;
    });
    _readVerse(0);
  }

  void _readVerse(int index) async {
    final verses = _chapterContents[widget.chapterId];
    if (verses == null || verses.isEmpty) return;

    if (index >= verses.length) {
      _fetchNextChapter();
      return;
    }

    if (index == 0) {
      await _announceChapter(chapterName);
    }

    final text = verses[index]['text'] ?? '';
    if (text.trim().isEmpty) {
      _readNextVerse();
      return;
    }

    setState(() => currentVerseIndex = index);
    await flutterTts.speak(text);
  }

  void _readNextVerse() {
    final verses = _chapterContents[widget.chapterId];
    if (verses == null || verses.isEmpty) return;

    final newIndex = currentVerseIndex != null ? currentVerseIndex! + 1 : 0;
    if (newIndex < verses.length) {
      _readVerse(newIndex);
    } else {
      _fetchNextChapter();
    }
  }

  void _pauseReading() {
    flutterTts.stop();
    setState(() {
      isReading = false;
      isPaused = true;
    });
  }

  void _resumeReading() {
    final index = currentVerseIndex != null ? currentVerseIndex! : 0;
    setState(() {
      isReading = true;
      isPaused = false;
    });
    _readVerse(index);
  }

  void _skipReading() {
    flutterTts.stop();
    setState(() => isSkipping = true);
    _readNextVerse();
  }

  Future<void> _announceChapter(String chapterName) async {
    setState(() => isSkipping = true);
    await flutterTts.speak(chapterName);
  }

  Future<void> _fetchNextChapter() async {
    int currentIndex = widget.chapterIds.indexOf(widget.chapterId);
    if (currentIndex < 0) return;

    final nextIndex = currentIndex + 1;
    if (nextIndex >= widget.chapterIds.length) {
      setState(() => isReading = false);
      return;
    }

    final nextChapterId = widget.chapterIds[nextIndex];
    final nextChapterName = widget.chapterNames[nextIndex];

    await _fetchChapterContent(nextChapterId);

    setState(() {
      widget.chapterId = nextChapterId;
      chapterName = nextChapterName;
      currentVerseIndex = 0;
      _pageController.jumpToPage(nextIndex);
      isSkipping = false;
    });

    _readVerse(0);
  }

  // Existing method for left/right arrow navigation
  void _changePage(int direction) async {
    setState(() {
      isLoading = true;
      pageChanging = true;
    });
    if (direction == -1 && currentPageIndex > 0) {
      currentPageIndex--;
    } else if (direction == 1 &&
        currentPageIndex < widget.chapterIds.length - 1) {
      currentPageIndex++;
    } else {
      setState(() {
        isLoading = false;
        pageChanging = false;
      });
      return;
    }

    _changeToChapter(currentPageIndex);
  }

  void _changeToChapter(int index) async {
    if (index < 0 || index >= widget.chapterIds.length) return;

    final newChapterId = widget.chapterIds[index];
    final newChapterName = widget.chapterNames[index];

    if (isReading) {
      flutterTts.stop();
    }

    setState(() {
      widget.chapterId = newChapterId;
      chapterName = newChapterName;
      currentVerseIndex = 0;
      currentPageIndex = index;
      isLoading = true;
    });

    await _fetchChapterContent(newChapterId);
    _pageController.jumpToPage(index);

    if (isReading) {
      _resumeReading();
    }
  }

  void _showChapterSelection() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Container(
          color: theme.scaffoldBackgroundColor,
          child: ListView.builder(
            itemCount: widget.chapterNames.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(widget.chapterNames[index]),
                onTap: () {
                  Navigator.of(context).pop(); // close bottom sheet
                  _changeToChapter(index);
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _preloadAdjacentChapters(String chapterId) async {
    // print('preload-----------------------');
    // if (_lastPreloadedChapterId == chapterId) return;
    _lastPreloadedChapterId = chapterId;

    final index = widget.chapterIds.indexOf(chapterId);
    final idsToPreload = [
      if (index - 2 >= 0) widget.chapterIds[index - 2],
      if (index - 1 >= 0) widget.chapterIds[index - 1],
      if (index + 1 < widget.chapterIds.length) widget.chapterIds[index + 1],
      if (index + 2 < widget.chapterIds.length) widget.chapterIds[index + 2],
    ];

    for (final id in idsToPreload) {
      if (!_chapterContents.containsKey(id)) {
        // Don't block, don't show spinner
        unawaited(_fetchChapterContent(id, showLoading: false));
      }
    }
  }

  void _summarizeContent() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final hasApiKey = settingsProvider.geminiApiKey != null && 
                      settingsProvider.geminiApiKey!.isNotEmpty;

    // Check for API key first
    if (!hasApiKey) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Key Required'),
          content: SingleChildScrollView(
            child: ApiKeySetupPrompt(
              onGoToSettings: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
        ),
      );
      return;
    }

    final selectedTexts = highlightKey.currentState?.getSelectedTexts() ?? [];

    final contentToSummarize = selectedTexts.isNotEmpty
        ? selectedTexts.join(' ')
        : (_chapterContents[widget.chapterId] ?? [])
            .map((v) => v['text'])
            .join(' ');

    final prompt =
        "Summarize and provide context and interpretations for the following verses:\n$contentToSummarize";

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => StreamedSummaryModal(
          prompt: prompt,
          title: 'Summary of $chapterName',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                        iconSize: 24,
                        padding: const EdgeInsets.only(left: 12),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          // Navigator.of(context).pushNamedAndRemoveUntil(
                          // '/main', (route) => false);
                          Navigator.of(context).pop();
                        })
                  ],
                ),
                toolbarHeight: 30,
                backgroundColor: theme.scaffoldBackgroundColor,
                iconTheme: IconThemeData(
                  color: (settingsProvider.currentThemeMode == ThemeMode.dark)
                      ? Colors.white
                      : Colors.black,
                ),
                actions: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 14.0),
                            child: Center(
                              child: SizedBox(
                                height: 36,
                                child: Center(
                                  child: Text(
                                    widget.bookName,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          color: (settingsProvider.currentThemeMode ==
                                  ThemeMode.dark)
                              ? Colors.white
                              : Colors.black,
                          icon: Icon(isReading ? Icons.stop : Icons.play_arrow),
                          onPressed: () {
                            if (isReading) {
                              _pauseReading();
                            } else {
                              _startReading();
                            }
                          },
                        ),
                      ],
              ),
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Column(
              children: [
                // PageView for chapters
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.chapterIds.length,
                    onPageChanged: (index) {
                      if (isReading) {
                        flutterTts.stop();
                      }
                      final newChapterId = widget.chapterIds[index];
                      final newChapterName = widget.chapterNames[index];

                      setState(() {
                        currentPageIndex = index;
                        widget.chapterId = newChapterId;
                        chapterName = newChapterName;
                        isReading
                            ? currentVerseIndex = 0
                            : currentVerseIndex = null;
                        isLoading = true;
                      });
                      _fetchChapterContent(newChapterId).then((_) {
                        _preloadAdjacentChapters(newChapterId);
                        setState(() {
                          isLoading = false;
                          pageChanging = false;
                        });
                        if (isReading) {
                          _resumeReading();
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      final chapterId = widget.chapterIds[index];
                      final verses = _chapterContents[chapterId] ?? [];
                      final copyright = _chapterCopyrights[chapterId];
                      final isCurrent = chapterId == widget.chapterId;
                      if (verses.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return SelectableTextHighlight(
                        key: isCurrent ? highlightKey : null,
                        chapterId: chapterId,
                        bookName: widget.bookName,
                        translationId: widget.translationId,
                        verses: verses,
                        copyright: copyright,
                        style:
                            theme.textTheme.bodyMedium!.copyWith(fontSize: 20),
                        currentVerseIndex: (chapterId == widget.chapterId)
                            ? currentVerseIndex
                            : -1,
                      );
                    },
                  ),
                ),

                if (isReading)
                  Container(
                    color: Colors.grey[200],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.pause),
                          onPressed: _pauseReading,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: _skipReading,
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (isSummaryLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
                color: theme.scaffoldBackgroundColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    // Bookmark
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bookmark_add),
                          onPressed: () async {
                            final bookmark = LocalBookmark.create(
                              chapterId: widget.chapterId,
                              bookName: widget.bookName,
                              chapterName: chapterName,
                              translationName: widget.translationName,
                              translationId: widget.translationId,
                              bookId: widget.bookId,
                            );
                            
                            await LocalStorageService.saveBookmark(bookmark);
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Bookmark saved')),
                              );
                            }
                          },
                          tooltip: 'Bookmark',
                        ),
                        const Text('Bookmark', style: TextStyle(fontSize: 12)),
                      ],
                    ),

                    IconButton(
                      icon: const Icon(Icons.arrow_circle_left, size: 40),
                      onPressed: () => _changePage(-1),
                    ),

                    InkWell(
                      onTap: _showChapterSelection,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          chapterName,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.arrow_circle_right, size: 40),
                      onPressed: () => _changePage(1),
                    ),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.summarize),
                          onPressed: _summarizeContent,
                          tooltip: 'Summarize',
                        ),
                        const Text('Summarize', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class SummaryModal extends StatelessWidget {
  final String content;

  const SummaryModal({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Summary'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: MarkdownBody(data: content),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class StreamedSummaryModal extends StatefulWidget {
  final String prompt;
  final String? title;

  const StreamedSummaryModal({super.key, required this.prompt, this.title});

  @override
  State<StreamedSummaryModal> createState() => _StreamedSummaryModalState();
}

class _StreamedSummaryModalState extends State<StreamedSummaryModal> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatService _chatService;
  StreamSubscription<String>? _subscription;
  bool _isStreaming = true;
  bool _hasAskedFollowUp = false;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
    
    // Initial summary message
    _messages.add({'role': 'assistant', 'content': ''});
    
    _subscription = _chatService.streamResponse(widget.prompt, useHistory: false).listen(
      (chunk) {
        setState(() {
          final lastMsg = _messages.last;
          lastMsg['content'] = (lastMsg['content'] ?? '') + chunk;
        });
        _scrollToBottom();
      },
      onDone: () {
        setState(() => _isStreaming = false);
      },
      onError: (e) {
        setState(() {
          _isStreaming = false;
          final lastMsg = _messages.last;
          lastMsg['content'] = (lastMsg['content'] ?? '') + "\nError: $e";
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleFollowUp() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messages.add({'role': 'assistant', 'content': ''});
      _isStreaming = true;
    });

    // If this is the first follow-up, we need to inject the original context
    if (!_hasAskedFollowUp) {
      _hasAskedFollowUp = true;
      // Add the initial prompt and the generated summary to the history
      // The summary is the content of the FIRST message in _messages
      final summaryContent = _messages.first['content'] ?? '';
      _chatService.addToHistory('user', widget.prompt);
      _chatService.addToHistory('assistant', summaryContent);
    }

    _subscription = _chatService.streamResponse(text, useHistory: true).listen(
      (chunk) {
        setState(() {
          final lastMsg = _messages.last;
          lastMsg['content'] = (lastMsg['content'] ?? '') + chunk;
        });
        _scrollToBottom();
      },
      onDone: () {
        setState(() => _isStreaming = false);
        _saveChat();
      },
      onError: (e) {
        setState(() {
          _isStreaming = false;
          final lastMsg = _messages.last;
          lastMsg['content'] = (lastMsg['content'] ?? '') + "\nError: $e";
        });
      },
    );
  }

  Future<void> _saveChat() async {
    // Reconstruct display messages for saving
    final displayMessages = _messages.map((m) {
      if (m['role'] == 'user') {
        return '**You**: ${m['content']}';
      } else {
        return '**Archie**: ${m['content']}';
      }
    }).toList();
    
    await _chatService.saveCurrentChat(displayMessages, title: widget.title);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100), // Faster for streaming
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate size once
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Explicit background colors for better contrast
    final modalBackgroundColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final userBubbleColor = isDark ? const Color(0xFF3D3D3D) : Colors.blue[50];
    final textFieldFillColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];
    
    // Ensure icon color is visible against the background
    final iconColor = isDark ? Colors.white : theme.primaryColor;

    return AlertDialog(
      title: const Text('Summary'),
      backgroundColor: modalBackgroundColor,
      surfaceTintColor: Colors.transparent, // Disable Material 3 tint
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0), // Removed top padding
      content: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.6,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty || (_messages.length == 1 && _messages.first['content']!.isEmpty && _isStreaming)
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 10), // Minimal top padding for list
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        final content = msg['content'] ?? '';
                        
                        // Don't render empty assistant messages
                        if (!isUser && content.isEmpty) return const SizedBox.shrink();

                        if (isUser) {
                          // User message bubble
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: userBubbleColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      content,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // Assistant message (Markdown)
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0), // Reduced vertical padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MarkdownBody(
                                  data: content,
                                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                    p: theme.textTheme.bodyMedium,
                                    blockquote: theme.textTheme.bodyMedium!.copyWith(
                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    code: theme.textTheme.bodySmall!.copyWith(
                                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const AiDisclaimer(compact: true),
                                const Divider(height: 24), // Reduced divider height
                              ],
                            ),
                          );
                        }
                      },
                    ),
            ),
            if (_isStreaming && (_messages.length > 1 || (_messages.isNotEmpty && _messages.first['content']!.isNotEmpty)))
               Padding(
                padding: const EdgeInsets.all(8.0),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent, 
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Ask a follow-up...',
                      hintStyle: TextStyle(color: theme.hintColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: textFieldFillColor,
                    ),
                    onSubmitted: (_) => _handleFollowUp(),
                    enabled: !_isStreaming,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: iconColor,
                  onPressed: _isStreaming ? null : _handleFollowUp,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
