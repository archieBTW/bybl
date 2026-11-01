import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_chat.dart';
import '../models/user_settings_enums.dart';
import 'settings_service.dart';
import 'package:string_similarity/string_similarity.dart';

class ChatService {
  final String _apiBase = 'https://api.bybl.dev/api';

  /// When true, this instance is an isolated temporary session (e.g. for a
  /// chapter/verse summary modal). It keeps its own multi-turn conversation
  /// history in memory and never reads or writes main chat history/memory.
  final bool isTemporary;

  final List<Map<String, String>> _conversationHistory = [];

  static const String _savedChatsKey = 'saved_chats';
  static const String _currentChatIdKey = 'current_chat_id';
  static const String _memoryNotesKey = 'ai_companion_memory_notes';
  static const int _maxHistoryTurnsSent = 24;

  // Shared in-memory caches across main ChatService instances to avoid
  // repeated SharedPreferences disk reads and JSON decoding on every turn.
  static List<SavedChat>? _cachedSavedChats;
  static String? _cachedMemoryNotes;
  static final Set<String> _summariesInFlight = {};
  static final http.Client _sharedHttpClient = http.Client();

  String? _currentChatId;
  String? get currentChatId => _currentChatId;

  List<Map<String, String>> get conversationHistory =>
      List.unmodifiable(_conversationHistory);

  ChatService({this.isTemporary = false});

  factory ChatService.temporary() => ChatService(isTemporary: true);

  /// Invalidates the in-memory saved chats cache (e.g. after import or external update).
  static void invalidateCache() {
    _cachedSavedChats = null;
    _cachedMemoryNotes = null;
  }

  Future<String> buildSystemPrompt(
    String? userQuery, {
    bool useFullMemory = true,
  }) async {
    final settingsService = SettingsService();

    final denom = await settingsService.loadDenomination();
    final context = await settingsService.loadAIContext();
    final userName = await settingsService.loadAIUserName();

    final effectiveUseMemory = useFullMemory && !isTemporary;

    final buffer = StringBuffer(
      "You are Bible Companion, a thoughtful Christian AI assistant inside the bybl Bible app. ",
    );

    if (userName != null && userName.trim().isNotEmpty) {
      buffer.write(
        "The user's name is ${userName.trim()}. Address them naturally by name when appropriate. ",
      );
    }

    buffer.write("You are assisting a user who identifies as ${denom.label}. ");
    buffer.write("Provide answers that are ${context.label}. ");

    if (context == AIContext.academic) {
      buffer.write(
        "Focus on historical context, original languages, and critical scholarship. ",
      );
    } else if (context == AIContext.devotional ||
        context == AIContext.pastoral) {
      buffer.write(
        "Focus on spiritual application, encouragement, and faithful interpretation. ",
      );
    }

    if (isTemporary || !effectiveUseMemory) {
      buffer.write(
        "You are currently in a focused passage/verse study & summarization modal. "
        "Maintain continuity with the passage and summary already discussed in this modal session so follow-up questions are answered directly and accurately in context. ",
      );
    }

    buffer.write("Always provide relevant Scripture references to give context. ");
    buffer.write(
      "However, if the user asks for a summary of an entire chapter, do NOT output the full chapter text; only cite key verses. ",
    );
    buffer.write(
      "When analyzing texts, provide relevant original Greek or Hebrew keywords and their meanings to deepen understanding. ",
    );
    buffer.write("Never curse. ");

    if (denom == Denomination.catholic) {
      buffer.write("Be respectful of Catholic tradition and the Deuterocanon. ");
    } else if (denom == Denomination.evangelical) {
      buffer.write(
        "Emphasize the authority of Scripture and personal relationship with God. ",
      );
    } else if (denom == Denomination.atheist) {
      buffer.write(
        "Be respectful of skepticism and focus on literary/historical analysis without assuming belief. ",
      );
    } else if (denom == Denomination.orthodox ||
        denom == Denomination.copticOrthodox) {
      buffer.write(
        "Emphasize the Church Fathers, the Septuagint, and Holy Tradition. ",
      );
    } else if (denom == Denomination.seventhDayAdventist) {
      buffer.write(
        "Be respectful of the Sabbath, wholeness, and the Second Coming. ",
      );
    } else if (denom == Denomination.latterDaySaint) {
      buffer.write(
        "Be respectful of Latter-day Saint beliefs and terminology. ",
      );
    } else if (denom == Denomination.messianicJewish) {
      buffer.write(
        "Emphasize the Jewish roots of the faith and the connection between the Tanakh and the New Testament. ",
      );
    } else if (denom == Denomination.quaker) {
      buffer.write("Emphasize the Inner Light, simplicity, and peace. ");
    } else if (denom == Denomination.anglican ||
        denom == Denomination.mainlineProtestant) {
      buffer.write("Balance scripture, tradition, and reason. ");
    } else if (denom == Denomination.reformed ||
        denom == Denomination.presbyterian) {
      buffer.write(
        "Emphasize the sovereignty of God, covenant theology, and the doctrines of grace. ",
      );
    } else if (denom == Denomination.pentecostal ||
        denom == Denomination.assemblyOfGod) {
      buffer.write(
        "Emphasize the work of the Holy Spirit, spiritual gifts, and personal experience of God. ",
      );
    } else if (denom == Denomination.lutheran) {
      buffer.write(
        "Emphasize justification by grace through faith and the distinction between Law and Gospel. ",
      );
    } else if (denom == Denomination.baptist) {
      buffer.write(
        "Emphasize believer's baptism, local church autonomy, and the priesthood of all believers. ",
      );
    } else if (denom == Denomination.methodist ||
        denom == Denomination.nazarene) {
      buffer.write("Emphasize holiness, sanctification, and prevenient grace. ");
    } else if (denom == Denomination.churchOfChrist) {
      buffer.write(
        "Emphasize a return to New Testament Christianity and silence where the Bible is silent. ",
      );
    } else if (denom == Denomination.anabaptist) {
      buffer.write("Emphasize discipleship, non-violence, and community. ");
    } else if (denom == Denomination.jewish) {
      buffer.write(
        "Be respectful of Jewish tradition, the Torah, and Talmudic commentary. Contextualize from a perspective of interfaith dialogue. ",
      );
    } else if (denom == Denomination.muslim) {
      buffer.write(
        "Be respectful of Islamic beliefs while explaining the Christian perspective clearly and kindly. ",
      );
    } else if (denom == Denomination.agnostic) {
      buffer.write(
        "Be explanatory and accessible, assuming good faith curiosity without demanding commitment. ",
      );
    } else if (denom == Denomination.nondenominational) {
      buffer.write(
        "Focus on ${context == AIContext.academic ? "ecumenical" : "broad evangelical"} Christian themes without denominational distinctives. ",
      );
    }

    buffer.write(
      "Cite Bible books/chapters/verses (use lesser-known ones when helpful). "
      "Don't repeat the user's request at the top of your reply, don't label the response, and don't repeat your own answers.",
    );

    if (effectiveUseMemory) {
      try {
        final memoryContext = await _buildCrossChatMemoryContext(userQuery);
        if (memoryContext.isNotEmpty) {
          buffer.write("\n\n$memoryContext");
        }
      } catch (e) {
        debugPrint('Error loading cross-chat memory: $e');
      }
    }

    return buffer.toString();
  }

  /// Builds fast, zero-network-latency cross-chat memory combining:
  /// 1. Persistent user memory notes extracted across sessions
  /// 2. Immediate recency memory from the most recent past chats (even if an LLM summary hasn't run yet)
  /// 3. Local keyword + similarity search across older chats for query-relevant context
  Future<String> _buildCrossChatMemoryContext(String? userQuery) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedMemoryNotes ??= prefs.getString(_memoryNotesKey) ?? '';

    final chats = await getSavedChats();
    final pastChats = chats
        .where((c) => c.id != _currentChatId && c.messages.isNotEmpty)
        .toList();

    final sections = <String>[];

    if (_cachedMemoryNotes != null && _cachedMemoryNotes!.trim().isNotEmpty) {
      sections.add(
        "Persistent user memory & study profile:\n${_cachedMemoryNotes!.trim()}",
      );
    }

    if (pastChats.isNotEmpty) {
      // 1. Always include up to 3 most recent past chats for seamless continuity across chats
      final recentChats = pastChats.take(3).toList();
      final recentIds = recentChats.map((c) => c.id).toSet();

      final recentLines = <String>[];
      for (final chat in recentChats) {
        final digest = _getChatMemoryDigest(chat);
        if (digest.isNotEmpty) {
          recentLines.add("- [${chat.title}]: $digest");
        }
      }

      // 2. Search older chats locally for high relevance to the current userQuery (0ms network latency)
      final relevantLines = <String>[];
      if (userQuery != null &&
          userQuery.trim().isNotEmpty &&
          pastChats.length > 3) {
        final olderChats =
            pastChats.where((c) => !recentIds.contains(c.id)).toList();
        final scored = <Map<String, dynamic>>[];

        for (final chat in olderChats) {
          final digest = _getChatMemoryDigest(chat);
          if (digest.isEmpty) continue;
          final score =
              _computeLocalRelevance(userQuery, '${chat.title} $digest');
          if (score > 0.18) {
            scored.add({
              'score': score,
              'title': chat.title,
              'digest': digest,
            });
          }
        }

        scored.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double),
        );

        for (final item in scored.take(3)) {
          relevantLines.add("- [${item['title']}]: ${item['digest']}");
        }
      }

      if (recentLines.isNotEmpty) {
        sections.add(
          "Recent conversations with this user (use naturally for continuity when relevant):\n${recentLines.join('\n')}",
        );
      }
      if (relevantLines.isNotEmpty) {
        sections.add(
          "Relevant older conversations with this user:\n${relevantLines.join('\n')}",
        );
      }
    }

    if (sections.isEmpty) return '';
    return "=== CROSS-CHAT MEMORY ===\n${sections.join('\n\n')}\n=== END MEMORY ===";
  }

  /// Returns the saved LLM summary for a chat, or builds an instant fallback
  /// digest directly from the chat's messages if the summary hasn't been generated yet.
  String _getChatMemoryDigest(SavedChat chat) {
    if (chat.summary != null && chat.summary!.trim().isNotEmpty) {
      return chat.summary!.trim();
    }
    if (chat.messages.isEmpty) return '';

    final snippets = <String>[];
    final relevantMessages = chat.messages.length > 6
        ? chat.messages.sublist(chat.messages.length - 6)
        : chat.messages;

    for (final msg in relevantMessages) {
      final clean = msg.content.replaceAll('\n', ' ').trim();
      if (clean.isEmpty) continue;
      final truncated =
          clean.length > 140 ? '${clean.substring(0, 140)}...' : clean;
      final prefix = msg.role == 'user' ? 'User asked' : 'Assistant replied';
      snippets.add('$prefix: "$truncated"');
    }
    return snippets.join(' | ');
  }

  double _computeLocalRelevance(String query, String candidate) {
    final qLower = query.toLowerCase().trim();
    final cLower = candidate.toLowerCase().trim();
    if (qLower.isEmpty || cLower.isEmpty) return 0.0;

    final stopWords = <String>{
      'the', 'and', 'for', 'that', 'this', 'with', 'from', 'what', 'how',
      'why', 'who', 'when', 'where', 'are', 'was', 'were', 'have', 'has',
      'had', 'can', 'could', 'would', 'should', 'about', 'into', 'your',
      'you', 'bible', 'verse', 'chapter', 'tell', 'mean', 'does', 'did',
    };

    final queryTokens = qLower
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 2 && !stopWords.contains(t))
        .toSet();

    double tokenScore = 0.0;
    if (queryTokens.isNotEmpty) {
      int matches = 0;
      for (final token in queryTokens) {
        if (cLower.contains(token)) matches++;
      }
      tokenScore = matches / queryTokens.length;
    }

    final diceScore = StringSimilarity.compareTwoStrings(
      qLower.length > 120 ? qLower.substring(0, 120) : qLower,
      cLower.length > 300 ? cLower.substring(0, 300) : cLower,
    );

    return (tokenScore * 0.7) + (diceScore * 0.3);
  }

  // ─────────────────────────────── CHAT PERSISTENCE ───────────────────────────

  /// Get all saved chats, sorted by most recent first (cached in memory)
  Future<List<SavedChat>> getSavedChats({bool forceReload = false}) async {
    if (!forceReload && _cachedSavedChats != null) {
      return List<SavedChat>.from(_cachedSavedChats!);
    }

    final prefs = await SharedPreferences.getInstance();
    final chatsJson = prefs.getStringList(_savedChatsKey) ?? [];
    final chats =
        chatsJson.map((json) => SavedChat.fromJsonString(json)).toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _cachedSavedChats = chats;
    return List<SavedChat>.from(chats);
  }

  /// Save a chat to local storage
  Future<void> saveChat(SavedChat chat, {bool skipSummary = false}) async {
    if (isTemporary) return;

    final prefs = await SharedPreferences.getInstance();
    final chats = await getSavedChats();

    final existingIndex = chats.indexWhere((c) => c.id == chat.id);
    if (existingIndex != -1) {
      chats[existingIndex] = chat;
    } else {
      chats.add(chat);
    }

    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _cachedSavedChats = chats;

    final chatsJson = chats.map((c) => c.toJsonString()).toList();
    await prefs.setStringList(_savedChatsKey, chatsJson);

    if (!skipSummary) {
      unawaited(_generateSummaryAndMemoryInBackground(chat));
    }
  }

  /// Delete a chat from local storage
  Future<void> deleteChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final chats = await getSavedChats();
    chats.removeWhere((c) => c.id == chatId);
    _cachedSavedChats = chats;
    final chatsJson = chats.map((c) => c.toJsonString()).toList();
    await prefs.setStringList(_savedChatsKey, chatsJson);
  }

  /// Clear all saved chats
  Future<void> clearAllChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedChatsKey);
    await prefs.remove(_currentChatIdKey);
    await prefs.remove(_memoryNotesKey);
    _cachedSavedChats = [];
    _cachedMemoryNotes = '';
    _currentChatId = null;
    _clearHistory();
  }

  /// Load a specific chat by ID and set it as current
  Future<SavedChat?> loadChat(String chatId) async {
    final chats = await getSavedChats();
    final chat = chats.where((c) => c.id == chatId).firstOrNull;

    if (chat != null) {
      _currentChatId = chat.id;
      _loadHistoryFromChat(chat);

      if (!isTemporary) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentChatIdKey, chatId);
      }
    }

    return chat;
  }

  /// Start a new chat
  Future<SavedChat> startNewChat({bool clearHistory = true}) async {
    final chat = SavedChat.create();
    _currentChatId = chat.id;
    if (clearHistory) {
      _clearHistory();
    }

    if (!isTemporary) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentChatIdKey, chat.id);
    }

    return chat;
  }

  /// Load the last active chat or create a new one
  Future<SavedChat> loadOrCreateCurrentChat() async {
    final prefs = await SharedPreferences.getInstance();
    final currentChatId = prefs.getString(_currentChatIdKey);

    if (currentChatId != null) {
      final chat = await loadChat(currentChatId);
      if (chat != null) return chat;
    }

    return await startNewChat();
  }

  /// Save the current chat state with messages
  Future<void> saveCurrentChat(
    List<String> displayMessages, {
    String? title,
    bool skipSummary = false,
  }) async {
    if (isTemporary) return;

    if (_currentChatId == null) {
      final chat = await startNewChat(clearHistory: false);
      _currentChatId = chat.id;
    }

    final messages = _convertDisplayMessagesToChat(displayMessages);
    final chats = await getSavedChats();
    final existingIndex = chats.indexWhere((c) => c.id == _currentChatId);

    SavedChat updatedChat;
    if (existingIndex != -1) {
      String newTitle = chats[existingIndex].title;
      if (title != null) {
        newTitle = title;
      } else if (newTitle == 'New Chat' && messages.isNotEmpty) {
        newTitle = _generateTitle(messages);
      }

      updatedChat = chats[existingIndex].copyWith(
        messages: messages,
        title: newTitle,
        updatedAt: DateTime.now(),
      );
    } else {
      updatedChat = SavedChat(
        id: _currentChatId!,
        title: title ??
            (messages.isNotEmpty ? _generateTitle(messages) : 'New Chat'),
        messages: messages,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    await saveChat(updatedChat, skipSummary: skipSummary);
  }

  String _generateTitle(List<ChatMessage> messages) {
    final firstUserMessage = messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () => ChatMessage(role: 'user', content: 'New Chat'),
    );
    final content = firstUserMessage.content;
    if (content.length <= 35) return content;
    return '${content.substring(0, 35)}...';
  }

  List<ChatMessage> _convertDisplayMessagesToChat(
      List<String> displayMessages) {
    return displayMessages.map((msg) {
      if (msg.startsWith('**You**:')) {
        return ChatMessage(
          role: 'user',
          content: msg.replaceFirst('**You**: ', ''),
        );
      } else {
        return ChatMessage(
          role: 'assistant',
          content: msg
              .replaceFirst('**Bible Companion**: ', '')
              .replaceFirst('**Archie**: ', ''),
        );
      }
    }).toList();
  }

  List<String> convertChatToDisplayMessages(SavedChat chat) {
    return chat.messages.map((msg) {
      if (msg.role == 'user') {
        return '**You**: ${msg.content}';
      } else {
        return '**Bible Companion**: ${msg.content}';
      }
    }).toList();
  }

  void _loadHistoryFromChat(SavedChat chat) {
    _clearHistory();

    for (final message in chat.messages) {
      _conversationHistory.add({
        'role': message.role,
        'content': message.content,
      });
    }
  }

  void _clearHistory() {
    _conversationHistory.clear();
  }

  void clearHistory() {
    _clearHistory();
  }

  void addToHistory(String role, String content) {
    _conversationHistory.add({
      'role': role,
      'content': content,
    });
  }

  /// Returns a windowed view of conversation history so very long chats stay fast
  /// while preserving the initial context and the latest turns.
  List<Map<String, String>> _getWindowedHistory(
      List<Map<String, String>> fullHistory) {
    if (fullHistory.length <= _maxHistoryTurnsSent) {
      return fullHistory;
    }
    return [
      fullHistory[0],
      fullHistory[1],
      ...fullHistory.sublist(fullHistory.length - (_maxHistoryTurnsSent - 2)),
    ];
  }

  /// Streams a response from the AI.
  /// Set [useHistory] to false for one-shot requests that shouldn't track history.
  /// Set [isMainChat] to false for temporary modal sessions (like chapter/verse summaries)
  /// so they use their own isolated history without pulling in or saving to main chat memory.
  Stream<String> streamResponse(
    String userMessage, {
    bool useHistory = true,
    bool isMainChat = true,
  }) async* {
    final effectiveMainChat = isMainChat && !isTemporary;
    if (useHistory) {
      addToHistory('user', userMessage);
    }

    final prefs = await SharedPreferences.getInstance();
    final geminiApiKey = prefs.getString('geminiApiKey');
    String geminiModel = prefs.getString('geminiModel') ?? 'gemini-3.8-flash';
    if (geminiModel.contains('3.1') || geminiModel.contains('1.5')) {
      geminiModel = 'gemini-3.8-flash';
    }

    Stream<String> responseStream;

    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      responseStream = _streamGeminiResponse(
        userMessage,
        geminiApiKey,
        geminiModel,
        useHistory: useHistory,
        isMainChat: effectiveMainChat,
      );
    } else {
      responseStream = _streamBackendResponse(
        userMessage,
        prefs.getString('token'),
        useHistory: useHistory,
        isMainChat: effectiveMainChat,
      );
    }

    final buffer = StringBuffer();
    try {
      await for (final chunk in responseStream) {
        buffer.write(chunk);
        yield chunk;
      }

      final fullReply = buffer.toString();
      if (useHistory && fullReply.trim().isNotEmpty) {
        addToHistory('assistant', fullReply);
      } else if (useHistory && fullReply.trim().isEmpty) {
        if (_conversationHistory.isNotEmpty &&
            _conversationHistory.last['role'] == 'user') {
          _conversationHistory.removeLast();
        }
      }
    } catch (e) {
      // Remove the dangling user message on failure so retries don't duplicate it
      if (useHistory &&
          _conversationHistory.isNotEmpty &&
          _conversationHistory.last['role'] == 'user') {
        _conversationHistory.removeLast();
      }
      rethrow;
    }
  }

  Stream<String> _streamGeminiResponse(
    String userMessage,
    String apiKey,
    String modelName, {
    bool useHistory = true,
    bool isMainChat = true,
  }) async* {
    try {
      final systemPrompt = await buildSystemPrompt(
        userMessage,
        useFullMemory: isMainChat,
      );
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        systemInstruction: Content.text(systemPrompt),
      );

      Stream<GenerateContentResponse> response;

      if (useHistory) {
        final previousMessages = _conversationHistory.length > 1
            ? _getWindowedHistory(
                _conversationHistory.sublist(
                    0, _conversationHistory.length - 1),
              )
            : const <Map<String, String>>[];

        final geminiHistory = previousMessages
            .where((msg) =>
                msg['content'] != null && msg['content']!.trim().isNotEmpty)
            .map((msg) {
          if (msg['role'] == 'user') {
            return Content.text(msg['content']!);
          } else {
            return Content.model([TextPart(msg['content']!)]);
          }
        }).toList();

        final chat = model.startChat(history: geminiHistory);
        response = chat.sendMessageStream(Content.text(userMessage));
      } else {
        response = model.generateContentStream([Content.text(userMessage)]);
      }

      await for (final chunk in response) {
        final text = chunk.text ?? '';
        if (text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e, stack) {
      debugPrint('🔥 Gemini Error: $e\n$stack');
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('high demand') ||
          errorMessage.contains('503')) {
        yield 'The AI model is currently experiencing high demand. Please try again in a moment.';
      } else {
        yield 'Sorry, I encountered an error connecting to Gemini. Please check your API key and try again.';
      }
    }
  }

  Stream<String> _streamBackendResponse(
    String userMessage,
    String? token, {
    bool useHistory = true,
    bool isMainChat = true,
  }) async* {
    final windowedHistory = _getWindowedHistory(_conversationHistory);
    final messagesToSend = useHistory
        ? await _buildMessagePayload(windowedHistory, userMessage, isMainChat)
        : await _buildMessagePayload([
            {'role': 'user', 'content': userMessage}
          ], userMessage, false);

    final request = http.Request(
      'POST',
      Uri.parse('$_apiBase/chat/stream'),
    )
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..body = jsonEncode({'messages': messagesToSend});

    http.StreamedResponse response;

    try {
      response = await _sharedHttpClient.send(request);
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      yield* _fallbackResponse(
        userMessage,
        useHistory: useHistory,
        isMainChat: isMainChat,
      );
      return;
    }

    if (response.statusCode != 200) {
      yield* _fallbackResponse(
        userMessage,
        useHistory: useHistory,
        isMainChat: isMainChat,
      );
      return;
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final chunk = line.substring(6);
      if (chunk == '[DONE]') break;
      yield chunk;
    }
  }

  Stream<String> _fallbackResponse(
    String userMessage, {
    bool useHistory = true,
    bool isMainChat = true,
  }) async* {
    final reply = await getResponse(
      userMessage,
      useHistory: useHistory,
      alreadyAddedToHistory: true,
      isMainChat: isMainChat,
    );
    yield reply;
  }

  /// Gets a response from the AI.
  Future<String> getResponse(
    String userMessage, {
    bool useHistory = true,
    bool alreadyAddedToHistory = false,
    bool isMainChat = true,
  }) async {
    final effectiveMainChat = isMainChat && !isTemporary;
    final prefs = await SharedPreferences.getInstance();
    final geminiApiKey = prefs.getString('geminiApiKey');
    String geminiModel = prefs.getString('geminiModel') ?? 'gemini-3.8-flash';
    if (geminiModel.contains('3.1') || geminiModel.contains('1.5')) {
      geminiModel = 'gemini-3.8-flash';
    }

    if (useHistory && !alreadyAddedToHistory) {
      addToHistory('user', userMessage);
    }

    String reply;

    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      reply = await _getGeminiResponse(
        userMessage,
        geminiApiKey,
        geminiModel,
        useHistory: useHistory,
        isMainChat: effectiveMainChat,
      );
    } else {
      final token = prefs.getString('token');
      final windowedHistory = _getWindowedHistory(_conversationHistory);
      final messagesToSend = useHistory
          ? await _buildMessagePayload(
              windowedHistory,
              userMessage,
              effectiveMainChat,
            )
          : await _buildMessagePayload([
              {'role': 'user', 'content': userMessage}
            ], userMessage, false);

      final response = await _sharedHttpClient.post(
        Uri.parse('$_apiBase/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'messages': messagesToSend}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get response: ${response.body}');
      }

      final data = json.decode(response.body);
      reply = data['response'] as String;
    }

    reply = reply
        .replaceFirst(RegExp(r'^Bible Companion:?\s*'), '')
        .replaceFirst(RegExp(r'^Archie:?\s*'), '');

    if (useHistory && !alreadyAddedToHistory) {
      addToHistory('assistant', reply);
    }

    return reply;
  }

  Future<String> _getGeminiResponse(
    String userMessage,
    String apiKey,
    String modelName, {
    bool useHistory = true,
    bool isMainChat = true,
  }) async {
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        systemInstruction: Content.text(
          await buildSystemPrompt(userMessage, useFullMemory: isMainChat),
        ),
      );

      if (useHistory) {
        final previousMessages = _conversationHistory.length > 1
            ? _getWindowedHistory(
                _conversationHistory.sublist(
                    0, _conversationHistory.length - 1),
              )
            : const <Map<String, String>>[];

        final geminiHistory = previousMessages
            .where((msg) =>
                msg['content'] != null && msg['content']!.trim().isNotEmpty)
            .map((msg) {
          if (msg['role'] == 'user') {
            return Content.text(msg['content']!);
          } else {
            return Content.model([TextPart(msg['content']!)]);
          }
        }).toList();

        final chat = model.startChat(history: geminiHistory);
        final response = await chat.sendMessage(Content.text(userMessage));
        return response.text ?? '';
      } else {
        final response =
            await model.generateContent([Content.text(userMessage)]);
        return response.text ?? '';
      }
    } catch (e, stack) {
      debugPrint('🔥 Gemini Error: $e\n$stack');
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('high demand') ||
          errorMessage.contains('503')) {
        return 'The AI model is currently experiencing high demand. Please try again in a moment.';
      } else {
        return 'Sorry, I encountered an error connecting to Gemini. Please check your API key and try again.';
      }
    }
  }

  Future<List<Map<String, String>>> _buildMessagePayload(
    List<Map<String, String>> history,
    String? userMessage,
    bool isMainChat,
  ) async {
    return [
      {
        'role': 'system',
        'content': await buildSystemPrompt(
          userMessage,
          useFullMemory: isMainChat,
        ),
      },
      ...history,
    ];
  }

  /// Generates a concise chat summary AND updates persistent cross-chat user
  /// memory notes in the background without blocking UI or requiring embeddings.
  Future<void> _generateSummaryAndMemoryInBackground(SavedChat chat) async {
    if (chat.messages.length < 2) return;
    if (_summariesInFlight.contains(chat.id)) return;
    _summariesInFlight.add(chat.id);

    try {
      final prefs = await SharedPreferences.getInstance();
      final geminiApiKey = prefs.getString('geminiApiKey');
      if (geminiApiKey == null || geminiApiKey.isEmpty) return;

      String geminiModel = prefs.getString('geminiModel') ?? 'gemini-3.8-flash';
      if (geminiModel.contains('3.1') || geminiModel.contains('1.5')) {
        geminiModel = 'gemini-3.8-flash';
      }

      final model = GenerativeModel(
        model: geminiModel,
        apiKey: geminiApiKey,
      );

      final recentMessages = chat.messages.length > 12
          ? chat.messages.sublist(chat.messages.length - 12)
          : chat.messages;
      final chatText =
          recentMessages.map((m) => "${m.role}: ${m.content}").join('\n');
      final existingNotes =
          (_cachedMemoryNotes ?? prefs.getString(_memoryNotesKey) ?? '').trim();

      final prompt = '''
Analyze the following Bible app conversation and return a JSON object with two fields:
1. "summary": A concise summary (under 60 words) of this specific chat's topics, Bible passages discussed, and key takeaways.
2. "memory_notes": Updated bullet points (max 150 words total) of lasting facts about the user across chats (e.g., Bible books/topics they are studying, personal context or ministry role they shared, recurring theological questions, prayer requests, or preferences). Merge new insights with the existing notes below and keep only useful lasting context.

Existing memory notes:
${existingNotes.isEmpty ? "(none)" : existingNotes}

Conversation:
$chatText

Respond ONLY with valid JSON: {"summary": "...", "memory_notes": "..."}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final rawText = (response.text ?? '').trim();
      if (rawText.isEmpty) return;

      String? summary;
      String? updatedNotes;

      try {
        final jsonStart = rawText.indexOf('{');
        final jsonEnd = rawText.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd > jsonStart) {
          final parsed = jsonDecode(rawText.substring(jsonStart, jsonEnd + 1))
              as Map<String, dynamic>;
          summary = parsed['summary']?.toString().trim();
          updatedNotes = parsed['memory_notes']?.toString().trim();
        }
      } catch (_) {
        // Fallback if model returned plain text instead of JSON
        summary = rawText.length > 300 ? rawText.substring(0, 300) : rawText;
      }

      if (updatedNotes != null && updatedNotes.isNotEmpty) {
        _cachedMemoryNotes = updatedNotes;
        await prefs.setString(_memoryNotesKey, updatedNotes);
      }

      if (summary != null && summary.isNotEmpty) {
        // Re-fetch latest version of this chat before saving summary so we don't overwrite newer messages
        final latestChats = await getSavedChats();
        final idx = latestChats.indexWhere((c) => c.id == chat.id);
        final targetChat = idx != -1 ? latestChats[idx] : chat;
        final updatedChat = targetChat.copyWith(summary: summary);
        await saveChat(updatedChat, skipSummary: true);
      }
    } catch (e) {
      debugPrint('Error generating background chat summary/memory: $e');
    } finally {
      _summariesInFlight.remove(chat.id);
    }
  }
}
