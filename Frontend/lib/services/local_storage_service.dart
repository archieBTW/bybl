import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_bookmark.dart';

class LocalStorageService {
  static const String _bookmarksKey = 'local_bookmarks';
  static const String _highlightsKey = 'local_highlights';

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

  /// Delete a bookmark
  static Future<void> deleteBookmark(String bookmarkId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    bookmarks.removeWhere((b) => b.id == bookmarkId);
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

  /// Save a highlight locally
  static Future<LocalHighlight> saveHighlight({
    required String verseId,
    required String content,
    String? note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final highlights = await getHighlights();
    
    // Check if already highlighted
    final existing = highlights.where((h) => h.verseId == verseId).firstOrNull;
    if (existing != null) {
      return existing; // Already exists
    }
    
    final highlight = LocalHighlight.create(
      verseId: verseId,
      content: content,
      note: note,
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
  static Future<void> updateHighlightNote(String highlightId, String? note) async {
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

  // ─────────────────────────────── EXPORT/IMPORT ───────────────────────────────

  static const String _savedChatsKey = 'saved_chats';

  /// Export all data as JSON string (bookmarks, highlights, chat history, and settings)
  static Future<String> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    final highlights = await getHighlights();
    
    // Get chat history
    final chatsJson = prefs.getStringList(_savedChatsKey) ?? [];
    final chats = chatsJson.map((json) => jsonDecode(json)).toList();
    
    // Get settings
    final settings = {
      'themeMode': prefs.getString('themeMode'),
      'currentColor': prefs.getInt('currentColor'),
      'highlightColor': prefs.getInt('highlightColor'),
      'translationId': prefs.getString('translationId'),
      'translationName': prefs.getString('translationName'),
      'geminiModel': prefs.getString('geminiModel'),
      // Note: We don't export the API key for security
    };
    
    final data = {
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
      'highlights': highlights.map((h) => h.toJson()).toList(),
      'chats': chats,
      'settings': settings,
    };
    
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Import data from JSON string
  static Future<Map<String, int>> importData(String jsonString) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    
    int bookmarksImported = 0;
    int highlightsImported = 0;
    int chatsImported = 0;
    bool settingsImported = false;
    
    // Import bookmarks
    if (data['bookmarks'] != null) {
      final existingBookmarks = await getBookmarks();
      final existingChapterIds = existingBookmarks.map((b) => b.chapterId).toSet();
      
      for (final bookmarkJson in data['bookmarks']) {
        final bookmark = LocalBookmark.fromJson(bookmarkJson);
        if (!existingChapterIds.contains(bookmark.chapterId)) {
          existingBookmarks.add(bookmark);
          bookmarksImported++;
        }
      }
      
      final bookmarksJson = existingBookmarks.map((b) => b.toJsonString()).toList();
      await prefs.setStringList(_bookmarksKey, bookmarksJson);
    }
    
    // Import highlights
    if (data['highlights'] != null) {
      final existingHighlights = await getHighlights();
      final existingVerseIds = existingHighlights.map((h) => h.verseId).toSet();
      
      for (final highlightJson in data['highlights']) {
        final highlight = LocalHighlight.fromJson(highlightJson);
        if (!existingVerseIds.contains(highlight.verseId)) {
          existingHighlights.add(highlight);
          highlightsImported++;
        }
      }
      
      final highlightsJson = existingHighlights.map((h) => h.toJsonString()).toList();
      await prefs.setStringList(_highlightsKey, highlightsJson);
    }
    
    // Import chat history
    if (data['chats'] != null) {
      final existingChatsJson = prefs.getStringList(_savedChatsKey) ?? [];
      final existingChats = existingChatsJson.map((json) => jsonDecode(json) as Map<String, dynamic>).toList();
      final existingChatIds = existingChats.map((c) => c['id']).toSet();
      
      for (final chatJson in data['chats']) {
        if (!existingChatIds.contains(chatJson['id'])) {
          existingChats.add(chatJson as Map<String, dynamic>);
          chatsImported++;
        }
      }
      
      final chatsJsonList = existingChats.map((c) => jsonEncode(c)).toList();
      await prefs.setStringList(_savedChatsKey, chatsJsonList);
    }
    
    // Import settings
    if (data['settings'] != null) {
      final settings = data['settings'] as Map<String, dynamic>;
      
      if (settings['themeMode'] != null) {
        await prefs.setString('themeMode', settings['themeMode']);
      }
      if (settings['currentColor'] != null) {
        await prefs.setInt('currentColor', settings['currentColor']);
      }
      if (settings['highlightColor'] != null) {
        await prefs.setInt('highlightColor', settings['highlightColor']);
      }
      if (settings['translationId'] != null) {
        await prefs.setString('translationId', settings['translationId']);
      }
      if (settings['translationName'] != null) {
        await prefs.setString('translationName', settings['translationName']);
      }
      if (settings['geminiModel'] != null) {
        await prefs.setString('geminiModel', settings['geminiModel']);
      }
      
      settingsImported = true;
    }
    
    return {
      'bookmarks': bookmarksImported,
      'highlights': highlightsImported,
      'chats': chatsImported,
      'settings': settingsImported ? 1 : 0,
    };
  }
}
