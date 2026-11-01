import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:TheWord/screens/settings_screen.dart';
import 'package:TheWord/shared/widgets/highlight_text.dart';
import 'package:TheWord/shared/widgets/api_key_setup_prompt.dart';
import 'package:TheWord/services/local_storage_service.dart';
import 'package:TheWord/models/local_bookmark.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../providers/settings_provider.dart';
import '../providers/bible_provider.dart';
import '../services/chat_service.dart';
import '../shared/widgets/ai_disclaimer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ReaderScreen extends StatefulWidget {
  String chapterId;
  final String chapterName;
  final List<dynamic> chapterIds;
  final List<dynamic> chapterNames;
  final String bookName;
  final String translationName;
  final String translationId;
  final String bookId;
  final String? targetVerseId;

  ReaderScreen({
    required this.chapterId,
    required this.chapterName,
    required this.chapterIds,
    required this.chapterNames,
    required this.bookName,
    required this.translationName,
    required this.translationId,
    required this.bookId,
    this.targetVerseId,
  });

  @override
  ReaderScreenState createState() => ReaderScreenState();
}

class ReaderScreenState extends State<ReaderScreen> {
  late PageController _pageController;

  late String _bookId;
  late String _bookName;
  late List<dynamic> _chapterIds;
  late List<dynamic> _chapterNames;
  late String _translationId;
  late String _translationName;

  Map<String, List<Map<String, dynamic>>> _chapterContents = {};
  Map<String, String?> _chapterCopyrights = {};

  bool isLoading = true;
  bool isSummaryLoading = false;
  bool _isBookmarked = false;

  bool isReading = false;
  bool isPaused = false;
  bool isSkipping = false;
  int? currentVerseIndex;

  int currentPageIndex = 0;
  String chapterName = '';
  bool pageChanging = false;

  FlutterTts flutterTts = FlutterTts();
  ChatService chatService = ChatService();

  final Map<String, GlobalKey<SelectableTextHighlightState>> _highlightKeys =
      {};
  final Map<String, ScrollController> _scrollControllers = {};
  Timer? _postSwipeTimer;

  final FocusNode _keyboardFocusNode = FocusNode();
  double _trackpadScrollDeltaX = 0;
  Timer? _trackpadResetTimer;
  DateTime _lastTrackpadPageChange = DateTime.fromMillisecondsSinceEpoch(0);
  double _overscrollAccumulated = 0;

  GlobalKey<SelectableTextHighlightState> _getHighlightKey(String chapterId) {
    return _highlightKeys.putIfAbsent(
      chapterId,
      () => GlobalKey<SelectableTextHighlightState>(),
    );
  }

  void _handleTrackpadHorizontalScroll(PointerScrollEvent event) {
    if (pageChanging) return;

    final now = DateTime.now();
    if (now.difference(_lastTrackpadPageChange).inMilliseconds < 450) {
      return;
    }

    _trackpadScrollDeltaX += event.scrollDelta.dx;

    _trackpadResetTimer?.cancel();
    _trackpadResetTimer = Timer(const Duration(milliseconds: 200), () {
      _trackpadScrollDeltaX = 0;
    });

    const threshold = 35.0;
    if (_trackpadScrollDeltaX.abs() >= threshold) {
      final direction = _trackpadScrollDeltaX > 0 ? 1 : -1;
      _trackpadScrollDeltaX = 0;
      _lastTrackpadPageChange = now;
      _changePage(direction);
    }
  }

  @override
  void initState() {
    super.initState();
    _bookId = widget.bookId;
    _bookName = widget.bookName;
    _chapterIds = List<dynamic>.from(widget.chapterIds);
    _chapterNames = List<dynamic>.from(widget.chapterNames);
    _translationId = widget.translationId;
    _translationName = widget.translationName;
    chapterName = widget.chapterName;

    final initialIndex = _chapterIds.indexOf(widget.chapterId);
    currentPageIndex = initialIndex >= 0 ? initialIndex : 0;

    _pageController = PageController(initialPage: currentPageIndex);

    _refreshBookmarkState();

    // Synchronously hydrate any already-cached chapters from BibleProvider
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    if (bibleProvider.books.isEmpty) {
      unawaited(bibleProvider.fetchBooks(_translationId));
    }
    if (bibleProvider.translations.isEmpty) {
      unawaited(bibleProvider.fetchTranslations());
    }

    _hydrateCachedChaptersForCurrentBook();

    if (_chapterContents.containsKey(widget.chapterId) &&
        _chapterContents[widget.chapterId]!.isNotEmpty) {
      isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _markChapterAsRead();
      });
    } else {
      _fetchChapterContent(widget.chapterId);
    }
    _preloadAdjacentChapters(widget.chapterId);

    flutterTts.setCompletionHandler(() {
      if (!isSkipping && isReading && !isPaused) {
        _readNextVerse();
      }
      isSkipping = false;
    });

    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
    flutterTts.awaitSpeakCompletion(true);
  }

  void _hydrateCachedChaptersForCurrentBook() {
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    for (final rawId in _chapterIds) {
      final id = rawId.toString();
      final cached = bibleProvider.getCachedChapter(_translationId, id);
      if (cached != null && cached.verses.isNotEmpty) {
        _chapterContents[id] = cached.verses;
        _chapterCopyrights[id] = cached.copyright;
      }
    }
  }

  Future<void> _refreshBookmarkState() async {
    final bookmarked =
        await LocalStorageService.isBookmarked(widget.chapterId);
    if (mounted && bookmarked != _isBookmarked) {
      setState(() {
        _isBookmarked = bookmarked;
      });
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _trackpadResetTimer?.cancel();
    _postSwipeTimer?.cancel();
    _pageController.dispose();
    flutterTts.stop();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ScrollController _getScrollController(String chapterId) {
    return _scrollControllers.putIfAbsent(chapterId, () => ScrollController());
  }

  bool get _isPageScrolling {
    if (!_pageController.hasClients) return false;
    return _pageController.position.isScrollingNotifier.value;
  }

  Future<void> _fetchChapterContent(
    String chapterId, {
    bool showLoading = true,
  }) async {
    final translationId = _translationId;
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);

    // 1. Check local screen map first
    if (_chapterContents.containsKey(chapterId) &&
        _chapterContents[chapterId]!.isNotEmpty) {
      if (mounted && showLoading && isLoading) {
        setState(() => isLoading = false);
      }
      if (chapterId == widget.chapterId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _markChapterAsRead();
          }
        });
      }
      return;
    }

    // 2. Check BibleProvider synchronous in-memory cache
    final memCached = bibleProvider.getCachedChapter(translationId, chapterId);
    if (memCached != null && memCached.verses.isNotEmpty) {
      _chapterContents[chapterId] = memCached.verses;
      _chapterCopyrights[chapterId] = memCached.copyright;
      if (mounted && showLoading && chapterId == widget.chapterId && isLoading) {
        setState(() {
          isLoading = false;
        });
      }
      if (chapterId == widget.chapterId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _markChapterAsRead();
          }
        });
      }
      return;
    }

    if (showLoading && mounted && !isLoading) {
      setState(() => isLoading = true);
    }

    try {
      final result =
          await bibleProvider.getOrFetchChapter(translationId, chapterId);

      if (result != null && result.verses.isNotEmpty) {
        _chapterContents[chapterId] = result.verses;
        _chapterCopyrights[chapterId] = result.copyright;
        if (mounted) {
          final loadedIdx = _chapterIds.indexOf(chapterId);
          final isAdjacentOrCurrent = loadedIdx == currentPageIndex ||
              (loadedIdx >= 0 && (loadedIdx - currentPageIndex).abs() <= 1);
          // Avoid rebuilding PageView mid-swipe for background preloads
          if (showLoading || (isAdjacentOrCurrent && !_isPageScrolling)) {
            setState(() {});
          }
        }
      }
    } finally {
      if (mounted && showLoading && chapterId == widget.chapterId) {
        if (isLoading) {
          setState(() => isLoading = false);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _markChapterAsRead();
          }
        });
      }
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
    final chapterId = widget.chapterId;
    final verses = _chapterContents[chapterId];
    if (verses == null || verses.isEmpty) return;

    if (index >= verses.length) {
      _fetchNextChapter();
      return;
    }

    if (index == 0) {
      await _announceChapter(chapterName);
      if (mounted) {
        setState(() => isSkipping = false);
      }
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

    String textToSpeak = chapterName;
    if (!textToSpeak.toLowerCase().startsWith('chapter') &&
        !textToSpeak.toLowerCase().contains(_bookName.toLowerCase())) {
      textToSpeak = "Chapter $textToSpeak";
    }

    await flutterTts.speak(textToSpeak);
  }

  Future<void> _fetchNextChapter() async {
    int currentIndex = _chapterIds.indexOf(widget.chapterId);
    if (currentIndex < 0) return;

    final nextIndex = currentIndex + 1;
    if (nextIndex >= _chapterIds.length) {
      final transitioned = await _transitionToAdjacentBook(1);
      if (!transitioned && mounted) {
        setState(() => isReading = false);
      }
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Transitions to the next (+1) or previous (-1) book when turning past
  /// the last chapter or before the first chapter of the current book.
  Future<bool> _transitionToAdjacentBook(int direction) async {
    if (pageChanging) return false;
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    if (bibleProvider.books.isEmpty) {
      await bibleProvider.fetchBooks(_translationId);
    }
    final books = bibleProvider.books;
    if (books.isEmpty) return false;

    final currentBookIdx =
        books.indexWhere((b) => b['id'].toString() == _bookId);
    if (currentBookIdx < 0) return false;

    final targetBookIdx = currentBookIdx + direction;
    if (targetBookIdx < 0 || targetBookIdx >= books.length) {
      return false;
    }

    setState(() {
      pageChanging = true;
      isLoading = true;
    });

    try {
      final targetBook = books[targetBookIdx];
      final targetBookId = targetBook['id'].toString();
      final targetBookName = targetBook['name'].toString();

      final chapters =
          await bibleProvider.fetchChapters(_translationId, targetBookId);
      if (chapters.isEmpty || !mounted) {
        setState(() {
          pageChanging = false;
          isLoading = false;
        });
        return false;
      }

      final newChapterIds = chapters.map((c) => c['id'].toString()).toList();
      final newChapterNames =
          chapters.map((c) => 'Chapter ${c['number']}').toList();
      final targetChapterIndex =
          direction > 0 ? 0 : newChapterIds.length - 1;
      final targetChapterId = newChapterIds[targetChapterIndex];
      final targetChapterName = newChapterNames[targetChapterIndex];

      if (isReading) {
        flutterTts.stop();
      }

      final oldController = _pageController;
      _pageController = PageController(initialPage: targetChapterIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });

      setState(() {
        _bookId = targetBookId;
        _bookName = targetBookName;
        _chapterIds = newChapterIds;
        _chapterNames = newChapterNames;
        currentPageIndex = targetChapterIndex;
        widget.chapterId = targetChapterId;
        chapterName = targetChapterName;
        currentVerseIndex = isReading ? 0 : null;
      });

      _hydrateCachedChaptersForCurrentBook();
      await _refreshBookmarkState();
      await _fetchChapterContent(targetChapterId);
      _preloadAdjacentChapters(targetChapterId);

      if (mounted) {
        setState(() {
          isLoading = false;
          pageChanging = false;
        });
        if (isReading) {
          _resumeReading();
        }
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          isLoading = false;
          pageChanging = false;
        });
      }
      return false;
    }
  }

  // Method for chapter navigation (arrows, swipe, trackpad, keyboard)
  void _changePage(int direction) async {
    if (pageChanging) return;

    int newIndex = currentPageIndex;
    if (direction == -1 && currentPageIndex > 0) {
      newIndex = currentPageIndex - 1;
    } else if (direction == 1 && currentPageIndex < _chapterIds.length - 1) {
      newIndex = currentPageIndex + 1;
    } else if (direction == -1 && currentPageIndex == 0) {
      await _transitionToAdjacentBook(-1);
      return;
    } else if (direction == 1 &&
        currentPageIndex >= _chapterIds.length - 1) {
      await _transitionToAdjacentBook(1);
      return;
    } else {
      return;
    }

    pageChanging = true;
    _changeToChapter(newIndex, animate: true);
  }

  void _changeToChapter(int index, {bool animate = false}) async {
    if (index < 0 || index >= _chapterIds.length) return;
    if (_pageController.hasClients) {
      if (animate && (index - currentPageIndex).abs() == 1) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _pageController.jumpToPage(index);
      }
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
            itemCount: _chapterNames.length,
            itemBuilder: (context, index) {
              final isCurrent = index == currentPageIndex;
              return ListTile(
                title: Text(
                  _chapterNames[index].toString(),
                  style: TextStyle(
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isCurrent ? const Icon(Icons.check, size: 18) : null,
                onTap: () {
                  Navigator.of(context).pop();
                  _changeToChapter(index);
                },
              );
            },
          ),
        );
      },
    );
  }

  String _shortTranslationLabel(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'BIBLE';
    final lower = trimmed.toLowerCase();
    if (lower.contains('berean')) return 'BSB';
    if (lower.contains('king james') && lower.contains('new')) return 'NKJV';
    if (lower.contains('king james')) return 'KJV';
    if (lower.contains('american standard')) return 'ASV';
    if (lower.contains('world english')) return 'WEB';
    if (lower.contains('english Majority') || lower.contains('emtv')) {
      return 'EMTV';
    }
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'^[A-Za-z]').hasMatch(w))
        .toList();
    if (words.length >= 2 && words.length <= 5) {
      return words.map((w) => w[0].toUpperCase()).join();
    }
    return trimmed.length > 6
        ? trimmed.substring(0, 6).toUpperCase()
        : trimmed.toUpperCase();
  }

  List<Map<String, dynamic>> _groupTranslationsForSheet(
      List<dynamic> translations) {
    final english = <Map<String, dynamic>>[];
    final others = <Map<String, dynamic>>[];
    for (final raw in translations) {
      if (raw is! Map) continue;
      final t = Map<String, dynamic>.from(raw);
      final langName = (t['language']?['name'] ?? '').toString().toLowerCase();
      final isEng = langName == 'english' ||
          langName.isEmpty ||
          t['language']?['id'] == 'eng';
      if (isEng) {
        english.add(t);
      } else {
        others.add(t);
      }
    }
    english.sort(
        (a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    others.sort(
        (a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    return [...english, ...others];
  }

  Future<void> _switchTranslationInReader(
      String newTranslationId, String newTranslationName) async {
    if (newTranslationId == _translationId) return;

    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);

    await settingsProvider.updateTranslation(
        newTranslationId, newTranslationName);
    unawaited(bibleProvider.fetchBooks(newTranslationId));

    setState(() {
      _translationId = newTranslationId;
      _translationName = newTranslationName;
      _chapterContents.clear();
      _chapterCopyrights.clear();
      isLoading = true;
    });

    _hydrateCachedChaptersForCurrentBook();
    await _fetchChapterContent(widget.chapterId);
    _preloadAdjacentChapters(widget.chapterId);
  }

  void _showTranslationSwitcher() {
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    if (bibleProvider.translations.isEmpty) {
      bibleProvider.fetchTranslations();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final provider = Provider.of<BibleProvider>(context);
            final allSorted = _groupTranslationsForSheet(provider.translations);
            final filtered = searchQuery.trim().isEmpty
                ? allSorted
                : allSorted.where((t) {
                    final name = (t['name'] ?? '').toString().toLowerCase();
                    final lang =
                        (t['language']?['name'] ?? '').toString().toLowerCase();
                    final q = searchQuery.toLowerCase();
                    return name.contains(q) || lang.contains(q);
                  }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Switch Translation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search translations...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (val) {
                          setSheetState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text('No translations found'),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final t = filtered[idx];
                                  final id = t['id'].toString();
                                  final name = (t['name'] ?? '').toString();
                                  final lang =
                                      (t['language']?['name'] ?? '').toString();
                                  final isCurrent = id == _translationId;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: isCurrent
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: lang.isNotEmpty &&
                                            lang.toLowerCase() != 'english'
                                        ? Text(lang)
                                        : null,
                                    trailing: isCurrent
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green)
                                        : null,
                                    onTap: () {
                                      Navigator.of(sheetContext).pop();
                                      _switchTranslationInReader(id, name);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTypographyControls() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            final isDark = settings.currentThemeMode == ThemeMode.dark;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Reading Appearance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Font Family Selector (Sans vs Serif)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: !settings.readerUseSerif
                                ? (isDark ? Colors.white12 : Colors.black12)
                                : null,
                            side: BorderSide(
                              color: !settings.readerUseSerif
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.grey.withOpacity(0.4),
                              width: !settings.readerUseSerif ? 1.8 : 1.0,
                            ),
                          ),
                          onPressed: () {
                            settings.updateReaderTypography(useSerif: false);
                          },
                          child: Text(
                            'Sans-Serif',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: settings.readerUseSerif
                                ? (isDark ? Colors.white12 : Colors.black12)
                                : null,
                            side: BorderSide(
                              color: settings.readerUseSerif
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.grey.withOpacity(0.4),
                              width: settings.readerUseSerif ? 1.8 : 1.0,
                            ),
                          ),
                          onPressed: () {
                            settings.updateReaderTypography(useSerif: true);
                          },
                          child: Text(
                            'Serif',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Font Size Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Text Size',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${settings.readerFontSize.round()} pt',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: settings.readerFontSize <= 14
                            ? null
                            : () => settings.updateReaderTypography(
                                  fontSize: settings.readerFontSize - 1,
                                ),
                      ),
                      Expanded(
                        child: Slider(
                          value: settings.readerFontSize.clamp(14.0, 28.0),
                          min: 14.0,
                          max: 28.0,
                          divisions: 14,
                          onChanged: (val) {
                            settings.updateReaderTypography(fontSize: val);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: settings.readerFontSize >= 28
                            ? null
                            : () => settings.updateReaderTypography(
                                  fontSize: settings.readerFontSize + 1,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Line Spacing Selector
                  const Text(
                    'Line Spacing',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildLineSpacingChip(
                        context: context,
                        label: 'Compact',
                        value: 1.35,
                        currentValue: settings.readerLineHeight,
                        isDark: isDark,
                        onTap: () =>
                            settings.updateReaderTypography(lineHeight: 1.35),
                      ),
                      const SizedBox(width: 8),
                      _buildLineSpacingChip(
                        context: context,
                        label: 'Comfortable',
                        value: 1.55,
                        currentValue: settings.readerLineHeight,
                        isDark: isDark,
                        onTap: () =>
                            settings.updateReaderTypography(lineHeight: 1.55),
                      ),
                      const SizedBox(width: 8),
                      _buildLineSpacingChip(
                        context: context,
                        label: 'Relaxed',
                        value: 1.85,
                        currentValue: settings.readerLineHeight,
                        isDark: isDark,
                        onTap: () =>
                            settings.updateReaderTypography(lineHeight: 1.85),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLineSpacingChip({
    required BuildContext context,
    required String label,
    required double value,
    required double currentValue,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isSelected = (currentValue - value).abs() < 0.08;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor:
              isSelected ? (isDark ? Colors.white12 : Colors.black12) : null,
          side: BorderSide(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : Colors.grey.withOpacity(0.4),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Future<void> _preloadAdjacentChapters(String chapterId) async {
    final index = _chapterIds.indexOf(chapterId);
    if (index < 0) return;

    final idsToPreload = [
      if (index + 1 < _chapterIds.length) _chapterIds[index + 1].toString(),
      if (index - 1 >= 0) _chapterIds[index - 1].toString(),
      if (index + 2 < _chapterIds.length) _chapterIds[index + 2].toString(),
      if (index - 2 >= 0) _chapterIds[index - 2].toString(),
      if (index + 3 < _chapterIds.length) _chapterIds[index + 3].toString(),
    ];

    for (final id in idsToPreload) {
      if (!_chapterContents.containsKey(id) || _chapterContents[id]!.isEmpty) {
        unawaited(_fetchChapterContent(id, showLoading: false));
      }
    }
  }

  /// Auto-marks the current chapter as read silently with no button and no toast.
  void _markChapterAsRead() async {
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    if (bibleProvider.readChapters.contains(widget.chapterId)) {
      return;
    }
    await bibleProvider.markChapterAsRead(widget.chapterId);
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await LocalStorageService.deleteBookmarkByChapterId(widget.chapterId);
      if (mounted) {
        setState(() {
          _isBookmarked = false;
        });
      }
    } else {
      final bookmark = LocalBookmark.create(
        chapterId: widget.chapterId,
        bookName: _bookName,
        chapterName: chapterName,
        translationName: _translationName,
        translationId: _translationId,
        bookId: _bookId,
      );
      await LocalStorageService.saveBookmark(bookmark);
      if (mounted) {
        setState(() {
          _isBookmarked = true;
        });
      }
    }
  }

  void _summarizeContent() {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final bibleProvider = Provider.of<BibleProvider>(
      context,
      listen: false,
    );
    final hasApiKey = settingsProvider.geminiApiKey != null &&
        settingsProvider.geminiApiKey!.isNotEmpty;

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

    final currentHighlightState =
        _highlightKeys[widget.chapterId]?.currentState;
    final selectedTexts = currentHighlightState?.getSelectedTexts() ?? [];
    final selectedIds = currentHighlightState?.getSelectedVerseIds() ?? [];

    final contentToSummarize = selectedTexts.isNotEmpty
        ? selectedTexts.join(' ')
        : (_chapterContents[widget.chapterId] ?? [])
            .map((v) => v['text'])
            .join(' ');

    String modalTitle = 'Summary of $_bookName • $chapterName';
    if (selectedIds.length == 1) {
      final ref = BibleReferenceFormatter.format(
        selectedIds.first,
        books: bibleProvider.books,
      );
      modalTitle = 'Summary of $ref';
    } else if (selectedIds.length > 1) {
      final firstRef = BibleReferenceFormatter.format(
        selectedIds.first,
        books: bibleProvider.books,
      );
      final lastParts = selectedIds.last.split('.');
      final lastNum = lastParts.isNotEmpty ? lastParts.last : selectedIds.last;
      modalTitle = 'Summary of $firstRef–$lastNum';
    }

    final prompt =
        "Summarize and provide context and interpretations for the following verses:\n$contentToSummarize";

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => StreamedSummaryModal(
          prompt: prompt,
          title: modalTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDark = settingsProvider.currentThemeMode == ThemeMode.dark;
    final fgColor = isDark ? Colors.white : Colors.black;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            iconSize: 22,
            padding: const EdgeInsets.only(left: 8),
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          toolbarHeight: 44,
          backgroundColor: theme.scaffoldBackgroundColor,
          iconTheme: IconThemeData(color: fgColor),
          titleSpacing: 0,
          title: Text(
            _bookName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
          actions: [
            // Quick Translation Switcher pill
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _showTranslationSwitcher,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _shortTranslationLabel(_translationName),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: fgColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 16, color: fgColor),
                    ],
                  ),
                ),
              ),
            ),
            // Typography (Aa) button
            IconButton(
              tooltip: 'Reading Appearance',
              onPressed: _showTypographyControls,
              icon: Text(
                'Aa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: settingsProvider.readerUseSerif ? 'Georgia' : null,
                  color: fgColor,
                ),
              ),
            ),
            // Audio TTS Play/Stop button
            IconButton(
              color: fgColor,
              tooltip: isReading ? 'Stop Audio' : 'Read Aloud',
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
        body: Focus(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _changePage(-1);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _changePage(1);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: const AppScrollBehavior(),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.depth == 0) {
                            if (notification is OverscrollNotification) {
                              _overscrollAccumulated += notification.overscroll;
                              if (_overscrollAccumulated > 65 &&
                                  currentPageIndex >= _chapterIds.length - 1) {
                                _overscrollAccumulated = 0;
                                _transitionToAdjacentBook(1);
                              } else if (_overscrollAccumulated < -65 &&
                                  currentPageIndex <= 0) {
                                _overscrollAccumulated = 0;
                                _transitionToAdjacentBook(-1);
                              }
                            } else if (notification is ScrollEndNotification) {
                              _overscrollAccumulated = 0;
                            }
                          }
                          return false;
                        },
                        child: PageView.builder(
                          controller: _pageController,
                          allowImplicitScrolling: true,
                          physics: const PageScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          itemCount: _chapterIds.length,
                          onPageChanged: (index) {
                            final newChapterId = _chapterIds[index].toString();
                            final newChapterName =
                                _chapterNames[index].toString();

                            if (isReading) {
                              flutterTts.stop();
                            }

                            final bibleProvider = Provider.of<BibleProvider>(
                              context,
                              listen: false,
                            );
                            if (!_chapterContents.containsKey(newChapterId) ||
                                _chapterContents[newChapterId]!.isEmpty) {
                              final memCached = bibleProvider.getCachedChapter(
                                _translationId,
                                newChapterId,
                              );
                              if (memCached != null &&
                                  memCached.verses.isNotEmpty) {
                                _chapterContents[newChapterId] =
                                    memCached.verses;
                                _chapterCopyrights[newChapterId] =
                                    memCached.copyright;
                              }
                            }

                            final alreadyLoaded =
                                _chapterContents.containsKey(newChapterId) &&
                                    _chapterContents[newChapterId]!.isNotEmpty;

                            setState(() {
                              currentPageIndex = index;
                              widget.chapterId = newChapterId;
                              chapterName = newChapterName;
                              currentVerseIndex = isReading ? 0 : null;
                              isLoading = !alreadyLoaded;
                              pageChanging = false;
                            });

                            // Defer non-visual background work until after the swipe settle animation completes
                            _postSwipeTimer?.cancel();
                            _postSwipeTimer =
                                Timer(const Duration(milliseconds: 260), () {
                              if (!mounted) return;
                              _refreshBookmarkState();
                              if (alreadyLoaded) {
                                _markChapterAsRead();
                                _preloadAdjacentChapters(newChapterId);
                                if (isReading) {
                                  _resumeReading();
                                }
                              } else {
                                _fetchChapterContent(newChapterId).then((_) {
                                  if (!mounted) return;
                                  _preloadAdjacentChapters(newChapterId);
                                  if (isReading) {
                                    _resumeReading();
                                  }
                                });
                              }
                            });
                          },
                          itemBuilder: (context, index) {
                            final chapterId = _chapterIds[index].toString();
                            final bibleProvider = Provider.of<BibleProvider>(
                              context,
                              listen: false,
                            );
                            final cached = bibleProvider.getCachedChapter(
                              _translationId,
                              chapterId,
                            );
                            final verses = _chapterContents[chapterId] ??
                                cached?.verses ??
                                [];
                            final copyright = _chapterCopyrights[chapterId] ??
                                cached?.copyright;
                            final isCurrent = chapterId == widget.chapterId;
                            if (verses.isEmpty) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            return RepaintBoundary(
                              child: Listener(
                                onPointerSignal: (pointerSignal) {
                                  if (pointerSignal is PointerScrollEvent) {
                                    if (pointerSignal.scrollDelta.dx.abs() >
                                        pointerSignal.scrollDelta.dy.abs()) {
                                      GestureBinding
                                          .instance.pointerSignalResolver
                                          .register(pointerSignal, (event) {
                                        _handleTrackpadHorizontalScroll(
                                            event as PointerScrollEvent);
                                      });
                                    }
                                  }
                                },
                                child: SelectableTextHighlight(
                                  key: _getHighlightKey(chapterId),
                                  chapterId: chapterId,
                                  bookName: _bookName,
                                  translationId: _translationId,
                                  verses: verses,
                                  copyright: copyright,
                                  scrollController:
                                      _getScrollController(chapterId),
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    fontSize: settingsProvider.readerFontSize,
                                    height: settingsProvider.readerLineHeight,
                                    fontFamily: settingsProvider.readerUseSerif
                                        ? 'Georgia'
                                        : null,
                                  ),
                                  currentVerseIndex:
                                      (chapterId == widget.chapterId)
                                          ? currentVerseIndex
                                          : -1,
                                  targetVerseId:
                                      (isCurrent && widget.targetVerseId != null)
                                          ? widget.targetVerseId
                                          : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (isReading)
                    Container(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
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
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: theme.scaffoldBackgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              // Active Bookmark Toggle
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _isBookmarked ? Colors.amber[600] : null,
                    ),
                    onPressed: _toggleBookmark,
                    tooltip: _isBookmarked ? 'Remove Bookmark' : 'Bookmark',
                  ),
                  Text(
                    _isBookmarked ? 'Bookmarked' : 'Bookmark',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          _isBookmarked ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),

              IconButton(
                icon: const Icon(Icons.arrow_circle_left, size: 40),
                onPressed: () => _changePage(-1),
                tooltip: 'Previous Chapter',
              ),

              InkWell(
                onTap: _showChapterSelection,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 8.0),
                  child: Text(
                    chapterName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.arrow_circle_right, size: 40),
                onPressed: () => _changePage(1),
                tooltip: 'Next Chapter',
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
        child: SingleChildScrollView(child: MarkdownBody(data: content)),
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
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  String _pendingChunkBuffer = '';

  @override
  void initState() {
    super.initState();
    _chatService = ChatService.temporary();
    _messages.add({'role': 'assistant', 'content': ''});
    _startStream(widget.prompt);
  }

  void _flushPendingChunks({bool force = false}) {
    if (_pendingChunkBuffer.isEmpty && !force) return;
    if (!mounted) return;
    final buffered = _pendingChunkBuffer;
    _pendingChunkBuffer = '';
    _lastUiUpdate = DateTime.now();

    setState(() {
      if (buffered.isNotEmpty && _messages.isNotEmpty) {
        final lastMsg = _messages.last;
        lastMsg['content'] = (lastMsg['content'] ?? '') + buffered;
      }
    });
    _scrollToBottom();
  }

  void _startStream(String promptText) {
    _pendingChunkBuffer = '';
    _subscription?.cancel();
    _subscription = _chatService
        .streamResponse(promptText, useHistory: true, isMainChat: false)
        .listen(
      (chunk) {
        _pendingChunkBuffer += chunk;
        final now = DateTime.now();
        if (now.difference(_lastUiUpdate).inMilliseconds >= 32) {
          _flushPendingChunks();
        }
      },
      onDone: () {
        _flushPendingChunks(force: true);
        if (mounted) {
          setState(() => _isStreaming = false);
        }
      },
      onError: (e) {
        _flushPendingChunks(force: true);
        if (mounted) {
          setState(() {
            _isStreaming = false;
            final lastMsg = _messages.last;
            lastMsg['content'] = (lastMsg['content'] ?? '') + "\nError: $e";
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _chatService.clearHistory();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleFollowUp() {
    final text = _textController.text.trim();
    if (text.isEmpty || _isStreaming) return;

    _textController.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messages.add({'role': 'assistant', 'content': ''});
      _isStreaming = true;
    });

    _startStream(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (_isStreaming) {
          _scrollController.jumpTo(maxExtent);
        } else {
          _scrollController.animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final modalBackgroundColor =
        isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final userBubbleColor = isDark ? const Color(0xFF3D3D3D) : Colors.blue[50];
    final textFieldFillColor =
        isDark ? const Color(0xFF1E1E1E) : Colors.grey[100];

    final iconColor = isDark ? Colors.white : theme.primaryColor;

    return AlertDialog(
      title: Text(widget.title ?? 'Summary'),
      backgroundColor: modalBackgroundColor,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      content: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.6,
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty ||
                      (_messages.length == 1 &&
                          _messages.first['content']!.isEmpty &&
                          _isStreaming)
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 10),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        final content = msg['content'] ?? '';

                        if (!isUser && content.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        if (isUser) {
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MarkdownBody(
                                  data: content,
                                  styleSheet: MarkdownStyleSheet.fromTheme(
                                    theme,
                                  ).copyWith(
                                    p: theme.textTheme.bodyMedium,
                                    blockquote:
                                        theme.textTheme.bodyMedium!.copyWith(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    code: theme.textTheme.bodyMedium!.copyWith(
                                      backgroundColor: Colors.transparent,
                                    ),
                                    codeblockDecoration: const BoxDecoration(
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const AiDisclaimer(compact: true),
                                const Divider(height: 24),
                              ],
                            ),
                          );
                        }
                      },
                    ),
            ),
            if (_isStreaming &&
                (_messages.length > 1 ||
                    (_messages.isNotEmpty &&
                        _messages.first['content']!.isNotEmpty)))
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
