import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_bookmark.dart';
import '../services/local_storage_service.dart';

/// Local-only verse provider for highlights
/// No backend dependency - all data stored locally
class VerseProvider with ChangeNotifier {
  List<LocalHighlight> savedVerses = [];
  bool isLoading = false;
  bool hasMoreSavedVerses = false; // No pagination needed for local storage
  bool isIniting = true;
  bool _hasInitialized = false;

  VerseProvider();

  Future<void> init() async {
    // Prevent multiple initializations
    if (_hasInitialized) return;
    _hasInitialized = true;
    
    isIniting = true;
    notifyListeners();
    
    await fetchSavedVerses(reset: true);
    
    isIniting = false;
    notifyListeners();
  }

  void reset() {
    savedVerses = [];
    isLoading = false;
    hasMoreSavedVerses = false;
  }

  Future<void> saveVerse(String verseId, String text, {String note = ''}) async {
    // Check if already saved
    if (savedVerses.any((verse) => verse.verseId == verseId)) {
      return;
    }

    final highlight = await LocalStorageService.saveHighlight(
      verseId: verseId,
      content: text,
      note: note.isNotEmpty ? note : null,
    );

    savedVerses.insert(0, highlight);
    notifyListeners();
  }

  bool isVerseSaved(String verseId) {
    return savedVerses.any((verse) => verse.verseId == verseId);
  }

  String? getSavedVerseUserVerseID(String verseId) {
    final savedVerse = savedVerses.firstWhere(
      (verse) => verse.verseId == verseId,
      orElse: () => LocalHighlight(
        id: '',
        verseId: '',
        content: '',
        createdAt: DateTime.now(),
      ),
    );
    return savedVerse.id.isNotEmpty ? savedVerse.id : null;
  }

  Future<void> fetchSavedVerses({bool reset = false, bool loading = true}) async {
    if (reset) {
      savedVerses = [];
    }

    if (loading) isLoading = true;
    notifyListeners();

    try {
      final highlights = await LocalStorageService.getHighlights();
      savedVerses = highlights;
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> unsaveVerse(String highlightId) async {
    await LocalStorageService.deleteHighlight(highlightId);
    savedVerses.removeWhere((verse) => verse.id == highlightId);
    notifyListeners();
  }

  Future<void> unsaveVerseByVerseId(String verseId) async {
    await LocalStorageService.deleteHighlightByVerseId(verseId);
    savedVerses.removeWhere((verse) => verse.verseId == verseId);
    notifyListeners();
  }
}
