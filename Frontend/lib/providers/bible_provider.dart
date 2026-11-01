import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:TheWord/services/local_storage_service.dart';

class CachedChapterContent {
  final List<Map<String, dynamic>> verses;
  final String? copyright;
  final int cachedAtMs;

  CachedChapterContent({
    required this.verses,
    this.copyright,
    int? cachedAtMs,
  }) : cachedAtMs = cachedAtMs ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'verses': verses,
        'copyright': copyright,
        'cachedAtMs': cachedAtMs,
      };

  factory CachedChapterContent.fromJson(Map<String, dynamic> json) {
    final rawVerses = (json['verses'] as List? ?? const []);
    return CachedChapterContent(
      verses:
          rawVerses.map((v) => Map<String, dynamic>.from(v as Map)).toList(),
      copyright: json['copyright'] as String?,
      cachedAtMs: json['cachedAtMs'] as int?,
    );
  }
}

class BibleProvider with ChangeNotifier {
  final String bereanBibleId = 'bba9f40183526463-01';
  final String _baseUrl = 'https://api.bybl.dev/api';

  static const String _translationsCacheKey = 'cache_bible_translations_v2';
  static const String _translationsCacheTsKey =
      'cache_bible_translations_ts_v2';
  static const String _booksCachePrefix = 'cache_bible_books_v1_';
  static const String _chaptersCachePrefix = 'cache_bible_chapters_v1_';
  static const String _passageCachePrefix = 'cache_bible_passage_v2_';
  static const String _passageCacheIndexKey = 'cache_bible_passage_index_v2';

  static const int _maxMemoryPassages = 500;
  static const int _maxPersistentPassages = 120;
  static const int _translationsTtlMs = 7 * 24 * 60 * 60 * 1000; // 7 days

  List<dynamic> _translations = [];
  List<dynamic> _books = [];
  List<dynamic> _filteredBooks = [];
  String? _activeTranslationId;
  String _currentSearchQuery = '';

  // In-memory caches across the entire app session
  final Map<String, List<dynamic>> _booksByTranslation = {};
  final Map<String, List<dynamic>> _chapters = {};
  final LinkedHashMap<String, CachedChapterContent> _passageCache =
      LinkedHashMap<String, CachedChapterContent>();

  // In-flight request deduplication maps
  Future<void>? _translationsInFlight;
  final Map<String, Future<void>> _booksInFlight = {};
  final Map<String, Future<List<dynamic>>> _chaptersInFlight = {};
  final Map<String, Future<CachedChapterContent?>> _passageInFlight = {};

  Set<String> _readChapters = {};

  bool isLoadingBooks = false;
  bool isLoadingChapters = false;

  List<dynamic> get translations => _translations;
  List<dynamic> get books => _books;
  List<dynamic> get filteredBooks =>
      _filteredBooks.isNotEmpty || _currentSearchQuery.isNotEmpty
          ? _filteredBooks
          : _books;
  Map<String, List<dynamic>> get chapters => _chapters;
  Set<String> get readChapters => _readChapters;

  BibleProvider() {
    _loadReadChapters();
    _hydratePersistentCaches();
  }

  String _normalizeBibleId(String translationId) {
    if (translationId.isEmpty ||
        translationId.toUpperCase() == 'BBA9F40183526463-01' ||
        translationId == '317e03834065a236-01') {
      return bereanBibleId;
    }
    return translationId;
  }

  String _chapterListKey(String translationId, String bookId) {
    final bibleId = _normalizeBibleId(translationId);
    return '$bibleId:$bookId';
  }

  String _passageKey(String translationId, String chapterId) {
    final bibleId = _normalizeBibleId(translationId);
    return '$bibleId:$chapterId';
  }

  Future<void> _hydratePersistentCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Hydrate translations if not yet loaded
      if (_translations.isEmpty) {
        final rawTranslations = prefs.getString(_translationsCacheKey);
        if (rawTranslations != null && rawTranslations.isNotEmpty) {
          final decoded = json.decode(rawTranslations);
          if (decoded is List && decoded.isNotEmpty) {
            _translations = decoded;
            notifyListeners();
          }
        }
      }

      // Hydrate persistent passage cache into memory for instant 0ms chapter opens
      final index = prefs.getStringList(_passageCacheIndexKey) ?? const [];
      for (final key in index) {
        if (_passageCache.containsKey(key)) continue;
        final rawPassage = prefs.getString('$_passageCachePrefix$key');
        if (rawPassage != null && rawPassage.isNotEmpty) {
          try {
            final parsed = CachedChapterContent.fromJson(
              json.decode(rawPassage) as Map<String, dynamic>,
            );
            if (parsed.verses.isNotEmpty) {
              _passageCache[key] = parsed;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Cache hydration error: $e');
    }
  }

  Future<void> _loadReadChapters() async {
    final chapters = await LocalStorageService.getReadChapters();
    _readChapters = chapters.toSet();
    notifyListeners();
  }

  Future<void> markChapterAsRead(String chapterId) async {
    if (!_readChapters.contains(chapterId)) {
      await LocalStorageService.markChapterAsRead(chapterId);
      _readChapters.add(chapterId);
      notifyListeners();
    }
  }

  Future<void> fetchTranslations({bool forceRefresh = false}) async {
    if (!forceRefresh && _translations.isNotEmpty) {
      return;
    }
    if (_translationsInFlight != null) {
      return _translationsInFlight!;
    }

    _translationsInFlight = _doFetchTranslations(forceRefresh: forceRefresh);
    try {
      await _translationsInFlight;
    } finally {
      _translationsInFlight = null;
    }
  }

  Future<void> _doFetchTranslations({required bool forceRefresh}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedJson = prefs.getString(_translationsCacheKey);
      final cachedTs = prefs.getInt(_translationsCacheTsKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = json.decode(cachedJson);
          if (decoded is List && decoded.isNotEmpty) {
            _translations = decoded;
            notifyListeners();
            if (now - cachedTs < _translationsTtlMs) {
              return;
            }
          }
        } catch (_) {}
      }
    }

    final response = await http.get(Uri.parse('$_baseUrl/bible/translations'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final seenNames = <String, int>{};
      final parsedTranslations = <dynamic>[];

      for (var t in data['data']) {
        final id = t['id']?.toString() ?? '';
        if (id.toUpperCase() == 'ESV' || id.toUpperCase() == 'NIV') {
          continue;
        }
        final name = t['name']?.toString() ?? '';
        if (!seenNames.containsKey(name)) {
          seenNames[name] = parsedTranslations.length;
          parsedTranslations.add(t);
        } else if (id == bereanBibleId) {
          parsedTranslations[seenNames[name]!] = t;
        }
      }

      _translations = parsedTranslations;
      notifyListeners();

      try {
        await prefs.setString(
            _translationsCacheKey, json.encode(_translations));
        await prefs.setInt(
            _translationsCacheTsKey, DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
    } else if (_translations.isEmpty) {
      throw Exception('Failed to load translations');
    }
  }

  Future<void> fetchBooks(String translationId,
      {bool forceRefresh = false}) async {
    final bibleId = _normalizeBibleId(translationId);
    _activeTranslationId = bibleId;

    // 1. Check in-memory cache first (0ms, no spinner)
    if (!forceRefresh &&
        _booksByTranslation.containsKey(bibleId) &&
        _booksByTranslation[bibleId]!.isNotEmpty) {
      _books = _booksByTranslation[bibleId]!;
      _applyBookFilter();
      isLoadingBooks = false;
      notifyListeners();
      return;
    }

    // 2. Deduplicate concurrent in-flight requests for the same translation
    if (_booksInFlight.containsKey(bibleId)) {
      return _booksInFlight[bibleId]!;
    }

    final future = _doFetchBooks(bibleId, forceRefresh: forceRefresh);
    _booksInFlight[bibleId] = future;
    try {
      await future;
    } finally {
      _booksInFlight.remove(bibleId);
    }
  }

  Future<void> _doFetchBooks(String bibleId,
      {required bool forceRefresh}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check persistent cache before showing spinner or making HTTP call
      if (!forceRefresh) {
        final cached = prefs.getString('$_booksCachePrefix$bibleId');
        if (cached != null && cached.isNotEmpty) {
          final decoded = json.decode(cached);
          if (decoded is List && decoded.isNotEmpty) {
            _booksByTranslation[bibleId] = decoded;
            if (_activeTranslationId == bibleId) {
              _books = decoded;
              _applyBookFilter();
              isLoadingBooks = false;
              notifyListeners();
            }
            return;
          }
        }
      }

      isLoadingBooks = true;
      notifyListeners();

      final response =
          await http.get(Uri.parse('$_baseUrl/bible/$bibleId/books'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fetchedBooks = data['data'] as List<dynamic>;
        _booksByTranslation[bibleId] = fetchedBooks;
        if (_activeTranslationId == bibleId) {
          _books = fetchedBooks;
          _applyBookFilter();
        }
        try {
          await prefs.setString(
              '$_booksCachePrefix$bibleId', json.encode(fetchedBooks));
        } catch (_) {}
      } else {
        throw Exception('Failed to load books');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
    } finally {
      isLoadingBooks = false;
      notifyListeners();
    }
  }

  Future<List<dynamic>> fetchChapters(
    String translationId,
    String bookId, {
    bool forceRefresh = false,
  }) async {
    final bibleId = _normalizeBibleId(translationId);
    final key = _chapterListKey(bibleId, bookId);

    // 1. In-memory cache hit
    if (!forceRefresh &&
        _chapters.containsKey(key) &&
        _chapters[key]!.isNotEmpty) {
      _chapters[bookId] = _chapters[key]!;
      return _chapters[key]!;
    }

    // 2. Deduplicate in-flight request
    if (_chaptersInFlight.containsKey(key)) {
      return _chaptersInFlight[key]!;
    }

    final future =
        _doFetchChapters(bibleId, bookId, key, forceRefresh: forceRefresh);
    _chaptersInFlight[key] = future;
    try {
      return await future;
    } finally {
      _chaptersInFlight.remove(key);
    }
  }

  Future<List<dynamic>> _doFetchChapters(
    String bibleId,
    String bookId,
    String key, {
    required bool forceRefresh,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (!forceRefresh) {
        final cached = prefs.getString('$_chaptersCachePrefix$key');
        if (cached != null && cached.isNotEmpty) {
          final decoded = json.decode(cached);
          if (decoded is List && decoded.isNotEmpty) {
            _chapters[key] = decoded;
            _chapters[bookId] = decoded;
            notifyListeners();
            return decoded;
          }
        }
      }

      isLoadingChapters = true;
      notifyListeners();

      final response = await http.get(
        Uri.parse('$_baseUrl/bible/$bibleId/books/$bookId/chapters'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> chapters = data['data'];
        chapters = chapters.where((c) => c['number'] != 'intro').toList();
        _chapters[key] = chapters;
        _chapters[bookId] = chapters;
        try {
          await prefs.setString(
              '$_chaptersCachePrefix$key', json.encode(chapters));
        } catch (_) {}
        return chapters;
      } else {
        throw Exception('Failed to load chapters');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      return _chapters[key] ?? _chapters[bookId] ?? [];
    } finally {
      isLoadingChapters = false;
      notifyListeners();
    }
  }

  List<dynamic>? getChapters(String bookId, {String? translationId}) {
    final effectiveTranslationId =
        translationId ?? _activeTranslationId ?? bereanBibleId;
    final key = _chapterListKey(effectiveTranslationId, bookId);
    return _chapters[key] ?? _chapters[bookId];
  }

  /// Synchronous lookup of a cached chapter's verses and copyright in memory.
  CachedChapterContent? getCachedChapter(
      String translationId, String chapterId) {
    final key = _passageKey(translationId, chapterId);
    final cached = _passageCache.remove(key);
    if (cached != null) {
      // Re-insert to mark as most-recently used (LRU)
      _passageCache[key] = cached;
    }
    return cached;
  }

  /// Returns cached chapter content if available (in-memory or SharedPreferences),
  /// or fetches from the API with in-flight request deduplication.
  Future<CachedChapterContent?> getOrFetchChapter(
    String translationId,
    String chapterId,
  ) async {
    final cached = getCachedChapter(translationId, chapterId);
    if (cached != null && cached.verses.isNotEmpty) {
      return cached;
    }

    final key = _passageKey(translationId, chapterId);
    if (_passageInFlight.containsKey(key)) {
      return _passageInFlight[key]!;
    }

    final future = _doFetchAndCacheChapter(translationId, chapterId, key);
    _passageInFlight[key] = future;
    try {
      return await future;
    } finally {
      _passageInFlight.remove(key);
    }
  }

  Future<CachedChapterContent?> _doFetchAndCacheChapter(
    String translationId,
    String chapterId,
    String key,
  ) async {
    final bibleId = _normalizeBibleId(translationId);

    // Check persistent cache in case _hydratePersistentCaches hasn't finished yet
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawCached = prefs.getString('$_passageCachePrefix$key');
      if (rawCached != null && rawCached.isNotEmpty) {
        final parsed = CachedChapterContent.fromJson(
          json.decode(rawCached) as Map<String, dynamic>,
        );
        if (parsed.verses.isNotEmpty) {
          _putMemoryPassageCache(key, parsed);
          return parsed;
        }
      }
    } catch (_) {}

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/passage/$bibleId?q=$chapterId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rawContent = data['data']?['content'];
        final copyright = data['data']?['copyright'] as String?;

        if (rawContent is List) {
          final verses = extractScriptureApiVerses(rawContent);
          if (bibleId.toUpperCase() == 'ESV') {
            for (final v in verses) {
              final parts = (v['id'] as String).split('.');
              v['id'] = parts.isNotEmpty ? parts.last : v['id'];
            }
          }

          final entry = CachedChapterContent(
            verses: verses,
            copyright: copyright,
          );

          if (verses.isNotEmpty) {
            _putMemoryPassageCache(key, entry);
            unawaited(_persistPassageEntry(key, entry));
          }
          return entry;
        }
      }
    } catch (e, stack) {
      debugPrint('🔥 Error fetching chapter $key: $e\n$stack');
    }
    return null;
  }

  void _putMemoryPassageCache(String key, CachedChapterContent entry) {
    _passageCache.remove(key);
    _passageCache[key] = entry;
    while (_passageCache.length > _maxMemoryPassages) {
      _passageCache.remove(_passageCache.keys.first);
    }
  }

  Future<void> _persistPassageEntry(
      String key, CachedChapterContent entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '$_passageCachePrefix$key', json.encode(entry.toJson()));

      final index =
          List<String>.from(prefs.getStringList(_passageCacheIndexKey) ?? []);
      index.remove(key);
      index.add(key);

      while (index.length > _maxPersistentPassages) {
        final evictedKey = index.removeAt(0);
        await prefs.remove('$_passageCachePrefix$evictedKey');
      }

      await prefs.setStringList(_passageCacheIndexKey, index);
    } catch (_) {}
  }

  List<Map<String, dynamic>> extractScriptureApiVerses(dynamic raw) {
    final verses = <Map<String, dynamic>>[];
    String? activeId;
    bool pendingStanzaBreak = false;

    String normVerseId(String id) => id.replaceAll(RegExp(r'[: ]'), '.');

    for (final para in (raw as List)) {
      if (para is! Map || para['name'] != 'para') continue;

      final paraStyle = para['attrs'] is Map
          ? (para['attrs']['style']?.toString() ?? 'p')
          : 'p';

      // 'b' is a blank poetic stanza break paragraph in USFM/api.bible
      if (paraStyle == 'b') {
        pendingStanzaBreak = true;
        continue;
      }

      final paraVid = para['attrs'] is Map
          ? (para['attrs']['vid'] ?? para['attrs']['sid'])?.toString()
          : null;
      if (paraVid != null && paraVid.isNotEmpty) {
        activeId = normVerseId(paraVid);
      }

      final buf = StringBuffer();

      void flushBuffer() {
        final txt = buf.toString().trim();
        buf.clear();
        if (activeId != null && activeId!.isNotEmpty && txt.isNotEmpty) {
          _appendOrMergeVerse(
            verses,
            activeId!,
            txt,
            style: paraStyle,
            stanzaBreak: pendingStanzaBreak,
          );
          pendingStanzaBreak = false;
        }
      }

      void processItems(List<dynamic> items) {
        for (final item in items) {
          if (item is! Map) continue;

          if (item['name'] == 'verse' && item['attrs'] is Map) {
            flushBuffer();
            final rawVid =
                (item['attrs']['sid'] ?? item['attrs']['verseId'])?.toString();
            activeId = (rawVid != null && rawVid.isNotEmpty)
                ? normVerseId(rawVid)
                : null;
            final vBuf = StringBuffer();
            for (final t in (item['items'] as List? ?? const [])) {
              if (t is Map && t['type'] == 'text') {
                vBuf.write(t['text'] ?? '');
              }
            }
            final txt = vBuf.toString().trim().replaceFirst(
                  RegExp(r'^\s*\[?\d+\]?'),
                  '',
                );

            if (activeId != null && txt.isNotEmpty) {
              _appendOrMergeVerse(
                verses,
                activeId!,
                txt,
                style: paraStyle,
                stanzaBreak: pendingStanzaBreak,
              );
              pendingStanzaBreak = false;
            }
            continue;
          }

          if (item['name'] == 'note') continue;

          if (item['type'] == 'text') {
            final rawTxt = (item['text'] ?? '').toString();
            if (rawTxt.isEmpty) continue;

            final rawVId = item['attrs']?['verseId']?.toString();
            final vId = (rawVId != null && rawVId.isNotEmpty)
                ? normVerseId(rawVId)
                : activeId;
            if (vId != null && vId.isNotEmpty) {
              if (activeId != null && vId != activeId) {
                flushBuffer();
              }
              activeId = vId;
              buf.write(rawTxt);
            }
            continue;
          }

          if (item['items'] is List) {
            processItems(item['items'] as List);
          }
        }
      }

      if (para['items'] is List) {
        processItems(para['items'] as List);
      }
      flushBuffer();
    }
    return verses;
  }

  void _appendOrMergeVerse(
    List<Map<String, dynamic>> verses,
    String rawId,
    String verseText, {
    String style = 'p',
    bool stanzaBreak = false,
  }) {
    final normId = rawId.replaceAll(RegExp(r'[: ]'), '.');
    final lineEntry = <String, dynamic>{
      'text': verseText,
      'style': style,
      if (stanzaBreak) 'stanzaBreak': true,
    };

    final existingIdx = verses.indexWhere((v) => v['id'] == normId);
    if (existingIdx != -1) {
      verses[existingIdx]['text'] =
          '${verses[existingIdx]['text']} $verseText'.trim();
      final existingLines = List<Map<String, dynamic>>.from(
        (verses[existingIdx]['lines'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
      existingLines.add(lineEntry);
      verses[existingIdx]['lines'] = existingLines;
    } else {
      verses.add({
        'id': normId,
        'text': verseText,
        'lines': <Map<String, dynamic>>[lineEntry],
      });
    }
  }

  Future<Map<String, dynamic>> fetchPassage({
    required String translationId,
    required String reference,
  }) async {
    final uri = Uri.parse('$_baseUrl/passage/$translationId?q=$reference');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load passage');
    }
  }

  void _applyBookFilter() {
    if (_currentSearchQuery.isEmpty) {
      _filteredBooks = _books;
    } else {
      _filteredBooks = _books.where((book) {
        return book['name']
            .toString()
            .toLowerCase()
            .contains(_currentSearchQuery.toLowerCase());
      }).toList();
    }
  }

  void filterBooks(String query) {
    _currentSearchQuery = query;
    _applyBookFilter();
    notifyListeners();
  }
}
