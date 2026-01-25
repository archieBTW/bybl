import 'dart:convert';

class SavedChat {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedChat({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavedChat.create() {
    final now = DateTime.now();
    return SavedChat(
      id: now.millisecondsSinceEpoch.toString(),
      title: 'New Chat',
      messages: [],
      createdAt: now,
      updatedAt: now,
    );
  }

  SavedChat copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedChat(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SavedChat.fromJson(Map<String, dynamic> json) {
    return SavedChat(
      id: json['id'] as String,
      title: json['title'] as String,
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory SavedChat.fromJsonString(String jsonString) {
    return SavedChat.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// Generate a title from the first user message
  String generateTitle() {
    final firstUserMessage = messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => ChatMessage(role: 'user', content: 'New Chat'),
    );
    final content = firstUserMessage.content;
    if (content.length <= 30) return content;
    return '${content.substring(0, 30)}...';
  }
}

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  ChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }
}
