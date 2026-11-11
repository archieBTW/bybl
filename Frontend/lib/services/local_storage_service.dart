import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_bookmark.dart';
import 'chat_service.dart';

class LocalStorageService {
  static const String _bookmarksKey = 'local_bookmarks';
  static const String _highlightsKey = 'local_highlights';
  static const String _readChaptersKey = 'local_read_chapters';

  // ─────────────────────────────── BOOKMARKS ───────────────────────────────

  /// Get all local bookmarks
  static Future<List<LocalBookmark>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getStringList(_bookmarksKey) ?? [];
    final bookmarks = bookmarksJson
        .map((json) => LocalBookmark.fromJsonString(json))
        .toList();
    bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookmarks;
  }

  /// Save a bookmark locally
  static Future<void> saveBookmark(LocalBookmark bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();

    // Check if already bookmarked
    if (bookmarks.any((b) => b.chapterId == bookmark.chapterId)) {
      return; // Already exists
    }

    bookmarks.add(bookmark);
    final bookmarksJson = bookmarks.map((b) => b.toJsonString()).toList();
    await prefs.setStringList(_bookmarksKey, bookmarksJson);
  }

  /// Delete a bookmark by ID
  static Future<void> deleteBookmark(String bookmarkId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((b) => b.id == bookmarkId);
    final bookmarksJson = bookmarks.map((b) => b.toJsonString()).toList();
    await prefs.setStringList(_bookmarksKey, bookmarksJson);
  }

  /// Delete a bookmark by chapterId
  static Future<void> deleteBookmarkByChapterId(String chapterId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((b) => b.chapterId == chapterId);
    final bookmarksJson = bookmarks.map((b) => b.toJsonString()).toList();
    await prefs.setStringList(_bookmarksKey, bookmarksJson);
  }

  /// Check if a chapter is bookmarked
  static Future<bool> isBookmarked(String chapterId) async {
    final bookmarks = await getBookmarks();
    return bookmarks.any((b) => b.chapterId == chapterId);
  }

  /// Get bookmarks grouped by book
  static Future<Map<String, List<LocalBookmark>>> getBookmarksGrouped() async {
    final bookmarks = await getBookmarks();
    final Map<String, List<LocalBookmark>> grouped = {};

    for (final bookmark in bookmarks) {
      final key = bookmark.bookName;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(bookmark);
    }

    return grouped;
  }

  /// Clear all bookmarks
  static Future<void> clearAllBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bookmarksKey);
  }

  // ─────────────────────────────── HIGHLIGHTS ───────────────────────────────

  /// Get all local highlights
  static Future<List<LocalHighlight>> getHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final highlightsJson = prefs.getStringList(_highlightsKey) ?? [];
    final highlights = highlightsJson
        .map((json) => LocalHighlight.fromJsonString(json))
        .toList();
    highlights.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return highlights;
  }

  /// Save or update a highlight locally
  static Future<LocalHighlight> saveHighlight({
    required String verseId,
    required String content,
    String? note,
    int? colorValue,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final highlights = await getHighlights();

    // Check if already highlighted
    final existingIdx = highlights.indexWhere((h) => h.verseId == verseId);
    if (existingIdx != -1) {
      final existing = highlights[existingIdx];
      if (colorValue != null && existing.colorValue != colorValue) {
        final updated = existing.copyWith(colorValue: colorValue);
        highlights[existingIdx] = updated;
        final highlightsJson = highlights.map((h) => h.toJsonString()).toList();
        await prefs.setStringList(_highlightsKey, highlightsJson);
        return updated;
      }
      return existing;
    }

    final highlight = LocalHighlight.create(
      verseId: verseId,
      content: content,
      note: note,
      colorValue: colorValue,
    );

    highlights.add(highlight);
    final highlightsJson = highlights.map((h) => h.toJsonString()).toList();
    await prefs.setStringList(_highlightsKey, highlightsJson);

    return highlight;
  }

  /// Delete a highlight
  static Future<void> deleteHighlight(String highlightId) async {
    final prefs = await SharedPreferences.getInstance();
    final highlights = await getHighlights();
    highlights.removeWhere((h) => h.id == highlightId);
    final highlightsJson = highlights.map((h) => h.toJsonString()).toList();
    await prefs.setStringList(_highlightsKey, highlightsJson);
  }

  /// Delete a highlight by verse ID
  static Future<void> deleteHighlightByVerseId(String verseId) async {
    final prefs = await SharedPreferences.getInstance();
    final highlights = await getHighlights();
    highlights.removeWhere((h) => h.verseId == verseId);
    final highlightsJson = highlights.map((h) => h.toJsonString()).toList();
    await prefs.setStringList(_highlightsKey, highlightsJson);
  }

  /// Check if a verse is highlighted
  static Future<bool> isHighlighted(String verseId) async {
    final highlights = await getHighlights();
    return highlights.any((h) => h.verseId == verseId);
  }

  /// Get highlight for a specific verse
  static Future<LocalHighlight?> getHighlight(String verseId) async {
    final highlights = await getHighlights();
    return highlights.where((h) => h.verseId == verseId).firstOrNull;
  }

  /// Update a highlight's note
  static Future<void> updateHighlightNote(
      String highlightId, String? note) async {
    final prefs = await SharedPreferences.getInstance();
    final highlights = await getHighlights();

    final index = highlights.indexWhere((h) => h.id == highlightId);
    if (index != -1) {
      final old = highlights[index];
      highlights[index] = LocalHighlight(
        id: old.id,
        verseId: old.verseId,
        content: old.content,
        note: note,
        colorValue: old.colorValue,
        createdAt: old.createdAt,
      );
      final highlightsJson = highlights.map((h) => h.toJsonString()).toList();
      await prefs.setStringList(_highlightsKey, highlightsJson);
    }
  }

  /// Clear all highlights
  static Future<void> clearAllHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_highlightsKey);
  }

  // ─────────────────────────────── READ CHAPTERS ───────────────────────────────

  /// Get all read chapters
  static Future<List<String>> getReadChapters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_readChaptersKey) ?? [];
  }

  /// Mark a chapter as read
  static Future<void> markChapterAsRead(String chapterId) async {
    final prefs = await SharedPreferences.getInstance();
    final readChapters = await getReadChapters();

    if (!readChapters.contains(chapterId)) {
      readChapters.add(chapterId);
      await prefs.setStringList(_readChaptersKey, readChapters);
    }
  }

  /// Check if a chapter is read
  static Future<bool> isChapterRead(String chapterId) async {
    final readChapters = await getReadChapters();
    return readChapters.contains(chapterId);
  }

  /// Clear all read chapters
  static Future<void> clearAllReadChapters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_readChaptersKey);
  }

  // ─────────────────────────────── EXPORT/IMPORT ───────────────────────────────

  static const String _savedChatsKey = 'saved_chats';

  /// Export all data as JSON string (bookmarks, highlights, notes, chat history, read chapters, memory notes, and all user preferences/API key)
  static Future<String> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    final highlights = await getHighlights();
    final readChapters = await getReadChapters();

    // Get chat history
    final chatsJson = prefs.getStringList(_savedChatsKey) ?? [];
    final chats = chatsJson.map((json) => jsonDecode(json)).toList();

    // Get memory notes
    final memoryNotes = prefs.getString('ai_companion_memory_notes');

    // Get preferences
    final primaryColor =
        prefs.getInt('primaryColor') ?? prefs.getInt('currentColor');
    final highlightColor = prefs.getInt('highlightColor');
    final themeMode = prefs.getString('themeMode');
    final translationId = prefs.getString('translationId');
    final translationName = prefs.getString('translationName');
    final geminiApiKey = prefs.getString('geminiApiKey');
    final geminiModel = prefs.getString('geminiModel');
    final readerFontSize = prefs.getDouble('readerFontSize');
    final readerLineHeight = prefs.getDouble('readerLineHeight');
    final readerUseSerif = prefs.getBool('readerUseSerif');
    final denomination = prefs.getString('denomination');
    final aiContext = prefs.getString('aiContext');
    final aiUserName = prefs.getString('aiUserName');

    final preferences = <String, dynamic>{
      if (geminiApiKey != null && geminiApiKey.isNotEmpty)
        'geminiApiKey': geminiApiKey,
      if (geminiModel != null) 'geminiModel': geminiModel,
      if (primaryColor != null) 'primaryColor': primaryColor,
      if (primaryColor != null) 'currentColor': primaryColor,
      if (highlightColor != null) 'highlightColor': highlightColor,
      if (themeMode != null) 'themeMode': themeMode,
      if (translationId != null) 'translationId': translationId,
      if (translationName != null) 'translationName': translationName,
      if (readerFontSize != null) 'readerFontSize': readerFontSize,
      if (readerLineHeight != null) 'readerLineHeight': readerLineHeight,
      if (readerUseSerif != null) 'readerUseSerif': readerUseSerif,
      if (denomination != null) 'denomination': denomination,
      if (aiContext != null) 'aiContext': aiContext,
      if (aiUserName != null) 'aiUserName': aiUserName,
    };

    final highlightsJsonList = highlights.map((h) => h.toJson()).toList();

    final data = <String, dynamic>{
      'version': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      'highlights': highlightsJsonList,
      'savedVerses': highlightsJsonList,
      'readChapters': readChapters,
      'chats': chats,
      if (memoryNotes != null && memoryNotes.isNotEmpty)
        'memoryNotes': memoryNotes,
      'preferences': preferences,
      // Keep 'settings' for backwards compatibility
      'settings': preferences,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Import data from JSON string
  static Future<Map<String, dynamic>> importData(String jsonString) async {
    final prefs = await SharedPreferences.getInstance();
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup JSON format');
    }
    final data = decoded;

    int bookmarksImported = 0;
    int highlightsImported = 0;
    int chatsImported = 0;
    int readChaptersImported = 0;
    bool preferencesImported = false;
    bool apiKeyImported = false;

    // 1. Import bookmarks
    if (data['bookmarks'] is List) {
      final existingBookmarks = await getBookmarks();
      final existingChapterIds =
          existingBookmarks.map((b) => b.chapterId).toSet();

      for (final item in data['bookmarks']) {
        if (item is Map<String, dynamic>) {
          try {
            final bookmark = LocalBookmark.fromJson(item);
            if (!existingChapterIds.contains(bookmark.chapterId)) {
              existingBookmarks.add(bookmark);
              existingChapterIds.add(bookmark.chapterId);
              bookmarksImported++;
            }
          } catch (_) {}
        }
      }

      final bookmarksJson =
          existingBookmarks.map((b) => b.toJsonString()).toList();
      await prefs.setStringList(_bookmarksKey, bookmarksJson);
    }

    // 2. Import highlights & notes & saved verses
    final rawHighlights = data['highlights'] ?? data['savedVerses'];
    if (rawHighlights is List) {
      final existingHighlights = await getHighlights();

      for (final item in rawHighlights) {
        if (item is Map<String, dynamic>) {
          try {
            final imported = LocalHighlight.fromJson(item);
            final existingIdx = existingHighlights
                .indexWhere((h) => h.verseId == imported.verseId);

            if (existingIdx == -1) {
              existingHighlights.add(imported);
              highlightsImported++;
            } else {
              // Merge: keep or update note and color if imported has values
              final existing = existingHighlights[existingIdx];
              final mergedNote =
                  (imported.note != null && imported.note!.trim().isNotEmpty)
                      ? imported.note
                      : existing.note;
              final mergedColor = imported.colorValue ?? existing.colorValue;
              final mergedContent = imported.content.isNotEmpty
                  ? imported.content
                  : existing.content;

              if (mergedNote != existing.note ||
                  mergedColor != existing.colorValue ||
                  mergedContent != existing.content) {
                existingHighlights[existingIdx] = existing.copyWith(
                  note: mergedNote,
                  colorValue: mergedColor,
                  content: mergedContent,
                );
                highlightsImported++;
              }
            }
          } catch (_) {}
        }
      }

      final highlightsJson =
          existingHighlights.map((h) => h.toJsonString()).toList();
      await prefs.setStringList(_highlightsKey, highlightsJson);
    }

    // 3. Import read chapters (reading progress)
    if (data['readChapters'] is List) {
      final existingRead = await getReadChapters();
      final set = existingRead.toSet();

      for (final ch in data['readChapters']) {
        if (ch is String && ch.isNotEmpty && !set.contains(ch)) {
          set.add(ch);
          readChaptersImported++;
        }
      }

      await prefs.setStringList(_readChaptersKey, set.toList());
    }

    // 4. Import chat history
    if (data['chats'] is List) {
      final existingChatsJson = prefs.getStringList(_savedChatsKey) ?? [];
      final existingChats = existingChatsJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      final existingChatIds = existingChats.map((c) => c['id']).toSet();

      for (final item in data['chats']) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString();
          if (id != null && !existingChatIds.contains(id)) {
            existingChats.add(item);
            existingChatIds.add(id);
            chatsImported++;
          }
        }
      }

      final chatsJsonList = existingChats.map((c) => jsonEncode(c)).toList();
      await prefs.setStringList(_savedChatsKey, chatsJsonList);
      ChatService.invalidateCache();
    }

    // 5. Import memory notes
    if (data['memoryNotes'] is String &&
        (data['memoryNotes'] as String).trim().isNotEmpty) {
      await prefs.setString(
          'ai_companion_memory_notes', (data['memoryNotes'] as String).trim());
    }

    // 6. Import preferences / settings (including API key)
    final rawPrefs = data['preferences'] ?? data['settings'];
    if (rawPrefs is Map<String, dynamic>) {
      // API Key
      final apiKey = rawPrefs['geminiApiKey']?.toString().trim();
      if (apiKey != null && apiKey.isNotEmpty) {
        await prefs.setString('geminiApiKey', apiKey);
        apiKeyImported = true;
      }

      // Gemini Model
      final geminiModel = rawPrefs['geminiModel']?.toString().trim();
      if (geminiModel != null && geminiModel.isNotEmpty) {
        await prefs.setString('geminiModel', geminiModel);
      }

      // Colors
      final primaryColor = rawPrefs['primaryColor'] ?? rawPrefs['currentColor'];
      if (primaryColor is int) {
        await prefs.setInt('primaryColor', primaryColor);
        await prefs.setInt('currentColor', primaryColor);
      }
      final highlightColor = rawPrefs['highlightColor'];
      if (highlightColor is int) {
        await prefs.setInt('highlightColor', highlightColor);
      }

      // Theme
      final themeMode = rawPrefs['themeMode']?.toString();
      if (themeMode != null && themeMode.isNotEmpty) {
        await prefs.setString('themeMode', themeMode);
      }

      // Translation
      final translationId = rawPrefs['translationId']?.toString();
      if (translationId != null && translationId.isNotEmpty) {
        await prefs.setString('translationId', translationId);
      }
      final translationName = rawPrefs['translationName']?.toString();
      if (translationName != null && translationName.isNotEmpty) {
        await prefs.setString('translationName', translationName);
      }

      // Reader preferences
      final readerFontSize = rawPrefs['readerFontSize'];
      if (readerFontSize is num) {
        await prefs.setDouble('readerFontSize', readerFontSize.toDouble());
      }
      final readerLineHeight = rawPrefs['readerLineHeight'];
      if (readerLineHeight is num) {
        await prefs.setDouble(
            'readerLineHeight', readerLineHeight.toDouble());
      }
      final readerUseSerif = rawPrefs['readerUseSerif'];
      if (readerUseSerif is bool) {
        await prefs.setBool('readerUseSerif', readerUseSerif);
      }

      // Theological / AI Companion Context
      final denomination = rawPrefs['denomination']?.toString();
      if (denomination != null && denomination.isNotEmpty) {
        await prefs.setString('denomination', denomination);
      }
      final aiContext = rawPrefs['aiContext']?.toString();
      if (aiContext != null && aiContext.isNotEmpty) {
        await prefs.setString('aiContext', aiContext);
      }
      final aiUserName = rawPrefs['aiUserName']?.toString();
      if (aiUserName != null && aiUserName.isNotEmpty) {
        await prefs.setString('aiUserName', aiUserName);
      }

      preferencesImported = true;
    }

    return {
      'bookmarks': bookmarksImported,
      'highlights': highlightsImported,
      'chats': chatsImported,
      'readChapters': readChaptersImported,
      'preferences': preferencesImported ? 1 : 0,
      'apiKey': apiKeyImported ? 1 : 0,
    };
  }
}
