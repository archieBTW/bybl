import 'dart:convert';

class LocalBookmark {
  final String id;
  final String chapterId;
  final String bookName;
  final String chapterName;
  final String translationName;
  final String translationId;
  final String bookId;
  final DateTime createdAt;

  LocalBookmark({
    required this.id,
    required this.chapterId,
    required this.bookName,
    required this.chapterName,
    required this.translationName,
    required this.translationId,
    required this.bookId,
    required this.createdAt,
  });

  factory LocalBookmark.create({
    required String chapterId,
    required String bookName,
    required String chapterName,
    required String translationName,
    required String translationId,
    required String bookId,
  }) {
    return LocalBookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chapterId: chapterId,
      bookName: bookName,
      chapterName: chapterName,
      translationName: translationName,
      translationId: translationId,
      bookId: bookId,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chapterId': chapterId,
      'bookName': bookName,
      'chapterName': chapterName,
      'translationName': translationName,
      'translationId': translationId,
      'bookId': bookId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalBookmark.fromJson(Map<String, dynamic> json) {
    return LocalBookmark(
      id: json['id'] as String,
      chapterId: json['chapterId'] as String,
      bookName: json['bookName'] as String,
      chapterName: json['chapterName'] as String,
      translationName: json['translationName'] as String,
      translationId: json['translationId'] as String,
      bookId: json['bookId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory LocalBookmark.fromJsonString(String jsonString) {
    return LocalBookmark.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

class LocalHighlight {
  final String id;
  final String verseId;
  final String content;
  final String? note;
  final DateTime createdAt;

  LocalHighlight({
    required this.id,
    required this.verseId,
    required this.content,
    this.note,
    required this.createdAt,
  });

  factory LocalHighlight.create({
    required String verseId,
    required String content,
    String? note,
  }) {
    return LocalHighlight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      verseId: verseId,
      content: content,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verseId': verseId,
      'content': content,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalHighlight.fromJson(Map<String, dynamic> json) {
    return LocalHighlight(
      id: json['id'] as String,
      verseId: json['verseId'] as String,
      content: json['content'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory LocalHighlight.fromJsonString(String jsonString) {
    return LocalHighlight.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}
