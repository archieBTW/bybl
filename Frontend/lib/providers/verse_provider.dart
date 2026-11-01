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

  Future<void> saveVerse(
    String verseId,
    String text, {
    String note = '',
    int? colorValue,
  }) async {
    final existingIdx =
        savedVerses.indexWhere((verse) => verse.verseId == verseId);
    if (existingIdx != -1) {
      if (colorValue != null &&
          savedVerses[existingIdx].colorValue != colorValue) {
        final updated = await LocalStorageService.saveHighlight(
          verseId: verseId,
          content: text,
          note: note.isNotEmpty ? note : savedVerses[existingIdx].note,
          colorValue: colorValue,
        );
        savedVerses[existingIdx] = updated;
        notifyListeners();
      }
      return;
    }

    final highlight = await LocalStorageService.saveHighlight(
      verseId: verseId,
      content: text,
      note: note.isNotEmpty ? note : null,
      colorValue: colorValue,
    );

    savedVerses.insert(0, highlight);
    notifyListeners();
  }

  bool isVerseSaved(String verseId) {
    return savedVerses.any((verse) => verse.verseId == verseId);
  }

  int? getVerseColorValue(String verseId) {
    for (final verse in savedVerses) {
      if (verse.verseId == verseId) {
        return verse.colorValue;
      }
    }
    return null;
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

  Future<void> fetchSavedVerses(
      {bool reset = false, bool loading = true}) async {
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

  Future<void> updateVerseNote(String highlightId, String? note) async {
    await LocalStorageService.updateHighlightNote(highlightId, note);

    final index = savedVerses.indexWhere((verse) => verse.id == highlightId);
    if (index != -1) {
      final old = savedVerses[index];
      savedVerses[index] = LocalHighlight(
        id: old.id,
        verseId: old.verseId,
        content: old.content,
        note: note,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
  }
}
