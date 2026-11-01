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
    return LocalBookmark.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

class LocalHighlight {
  final String id;
  final String verseId;
  final String content;
  final String? note;
  final int? colorValue;
  final DateTime createdAt;

  LocalHighlight({
    required this.id,
    required this.verseId,
    required this.content,
    this.note,
    this.colorValue,
    required this.createdAt,
  });

  factory LocalHighlight.create({
    required String verseId,
    required String content,
    String? note,
    int? colorValue,
  }) {
    return LocalHighlight(
      id: '${DateTime.now().microsecondsSinceEpoch}_$verseId',
      verseId: verseId,
      content: content,
      note: note,
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );
  }

  LocalHighlight copyWith({
    String? id,
    String? verseId,
    String? content,
    String? note,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return LocalHighlight(
      id: id ?? this.id,
      verseId: verseId ?? this.verseId,
      content: content ?? this.content,
      note: note ?? this.note,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verseId': verseId,
      'content': content,
      'note': note,
      if (colorValue != null) 'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LocalHighlight.fromJson(Map<String, dynamic> json) {
    return LocalHighlight(
      id: json['id'] as String,
      verseId: json['verseId'] as String,
      content: json['content'] as String,
      note: json['note'] as String?,
      colorValue: json['colorValue'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory LocalHighlight.fromJsonString(String jsonString) {
    return LocalHighlight.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

class BibleReferenceFormatter {
  static const Map<String, String> _usfmToBookName = {
    'GEN': 'Genesis',
    'EXO': 'Exodus',
    'LEV': 'Leviticus',
    'NUM': 'Numbers',
    'DEU': 'Deuteronomy',
    'JOS': 'Joshua',
    'JDG': 'Judges',
    'RUT': 'Ruth',
    '1SA': '1 Samuel',
    '2SA': '2 Samuel',
    '1KI': '1 Kings',
    '2KI': '2 Kings',
    '1CH': '1 Chronicles',
    '2CH': '2 Chronicles',
    'EZR': 'Ezra',
    'NEH': 'Nehemiah',
    'EST': 'Esther',
    'JOB': 'Job',
    'PSA': 'Psalms',
    'PRO': 'Proverbs',
    'ECC': 'Ecclesiastes',
    'SNG': 'Song of Solomon',
    'ISA': 'Isaiah',
    'JER': 'Jeremiah',
    'LAM': 'Lamentations',
    'EZK': 'Ezekiel',
    'DAN': 'Daniel',
    'HOS': 'Hosea',
    'JOL': 'Joel',
    'AMO': 'Amos',
    'OBA': 'Obadiah',
    'JON': 'Jonah',
    'MIC': 'Micah',
    'NAM': 'Nahum',
    'NAH': 'Nahum',
    'HAB': 'Habakkuk',
    'ZEP': 'Zephaniah',
    'HAG': 'Haggai',
    'ZEC': 'Zechariah',
    'MAL': 'Malachi',
    'MAT': 'Matthew',
    'MRK': 'Mark',
    'LUK': 'Luke',
    'JHN': 'John',
    'ACT': 'Acts',
    'ROM': 'Romans',
    '1CO': '1 Corinthians',
    '2CO': '2 Corinthians',
    'GAL': 'Galatians',
    'EPH': 'Ephesians',
    'PHP': 'Philippians',
    'COL': 'Colossians',
    '1TH': '1 Thessalonians',
    '2TH': '2 Thessalonians',
    '1TI': '1 Timothy',
    '2TI': '2 Timothy',
    'TIT': 'Titus',
    'PHM': 'Philemon',
    'HEB': 'Hebrews',
    'JAS': 'James',
    '1PE': '1 Peter',
    '2PE': '2 Peter',
    '1JN': '1 John',
    '2JN': '2 John',
    '3JN': '3 John',
    'JUD': 'Jude',
    'REV': 'Revelation',
    'TOB': 'Tobit',
    'JDT': 'Judith',
    'WIS': 'Wisdom',
    'SIR': 'Sirach',
    'BAR': 'Baruch',
    '1MA': '1 Maccabees',
    '2MA': '2 Maccabees',
  };

  /// Converts a USFM verse or chapter ID (e.g. "GEN.1.1", "PSA.23:4", "1CO.13.4")
  /// into a human-readable reference like "Genesis 1:1" or "1 Corinthians 13:4".
  static String format(String rawId, {List<dynamic>? books}) {
    final trimmed = rawId.trim();
    if (trimmed.isEmpty) return rawId;

    final parts = trimmed.split(RegExp(r'[.: ]+'));
    if (parts.isEmpty) return rawId;

    final code = parts[0].toUpperCase();
    String? bookName = _usfmToBookName[code];

    if (bookName == null && books != null) {
      for (final b in books) {
        if (b is Map && b['id']?.toString().toUpperCase() == code) {
          bookName = b['name']?.toString();
          break;
        }
      }
    }

    bookName ??= code;

    if (parts.length == 2) {
      return '$bookName ${parts[1]}';
    } else if (parts.length >= 3) {
      return '$bookName ${parts[1]}:${parts.sublist(2).join('-')}';
    }
    return bookName;
  }
}
