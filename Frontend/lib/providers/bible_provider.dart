import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:sentry_flutter/sentry_flutter.dart';

class BibleProvider with ChangeNotifier {
  final String bereanBibleId = 'bba9f40183526463-01';
  final String _baseUrl = 'https://api.bybl.dev/api';

  List<dynamic> _translations = [];
  List<dynamic> _books = [];
  List<dynamic> _filteredBooks = [];
  Map<String, List<dynamic>> _chapters = {};

  bool isLoadingBooks = false;
  bool isLoadingChapters = false;

  List<dynamic> get translations => _translations;
  List<dynamic> get books => _books;
  List<dynamic> get filteredBooks =>
      _filteredBooks.isNotEmpty ? _filteredBooks : _books;
  Map<String, List<dynamic>> get chapters => _chapters;

  Future<void> fetchTranslations() async {
    final response = await http.get(Uri.parse('$_baseUrl/bible/translations'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final seenNames = <String>{};
      _translations = [];

      for (var t in data['data']) {
        final name = t['name'];
        if (!seenNames.contains(name)) {
          seenNames.add(name);
          _translations.add(t);
        }
      }

      if (!seenNames.contains('New International Version')) {
        _translations.add({
          'id': 'NIV',
          'name': 'New International Version',
        });
      }

      notifyListeners();
    } else {
      throw Exception('Failed to load translations');
    }
  }

  Future<void> fetchBooks(String translationId) async {
    isLoadingBooks = true;
    _books = [];
    _filteredBooks = [];
    notifyListeners();

    try {
      final bibleId = (translationId.toUpperCase() == 'bba9f40183526463-01')
          ? bereanBibleId
          : translationId;

      final response =
          await http.get(Uri.parse('$_baseUrl/bible/$bibleId/books'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _books = data['data'];
        _filteredBooks = _books;
        print("Books fetched successfully: ${_books.length} books found.");
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

  Future<void> fetchChapters(String translationId, String bookId) async {
    isLoadingChapters = true;
    notifyListeners();

    try {
      final bibleId = (translationId == 'bba9f40183526463-01')
          ? bereanBibleId
          : translationId;

      final response = await http.get(
        Uri.parse('$_baseUrl/bible/$bibleId/books/$bookId/chapters'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> chapters = data['data'];
        chapters = chapters.where((c) => c['number'] != 'intro').toList();
        _chapters[bookId] = chapters;
        print(
            "Chapters for book $bookId fetched successfully: ${chapters.length} chapters found.");
      } else {
        throw Exception('Failed to load chapters');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
    } finally {
      isLoadingChapters = false;
      notifyListeners();
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

  List<dynamic>? getChapters(String bookId) {
    return _chapters[bookId];
  }

  void filterBooks(String query) {
    if (query.isEmpty) {
      _filteredBooks = _books;
    } else {
      _filteredBooks = _books.where((book) {
        return book['name'].toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    notifyListeners();
  }
}
