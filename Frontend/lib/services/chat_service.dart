import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_chat.dart';
import '../models/user_settings_enums.dart'; // import enums
import 'settings_service.dart';

class ChatService {
  final String _apiBase = 'https://api.bybl.dev/api';

  final List<Map<String, String>> _conversationHistory = [];

  static const String _savedChatsKey = 'saved_chats';
  static const String _currentChatIdKey = 'current_chat_id';

  String? _currentChatId;
  String? get currentChatId => _currentChatId;

  // REMOVED static const _systemPrompt

  Future<String> _buildSystemPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(); // Instantiate to load enums

    final denom = await settingsService.loadDenomination();
    final context = await settingsService.loadAIContext();

    String prompt =
        "Your name is archie. You are a Christian AI pink angel/blob thing that lives inside of a bible app called bybl. ";

    prompt += "You are assisting a user who identifies as ${denom.label}. ";
    prompt += "Provide answers that are ${context.label}. ";

    if (context == AIContext.academic || context == AIContext.linguistic) {
      prompt +=
          "Focus on historical context, original languages, and critical scholarship. ";
    } else if (context == AIContext.devotional ||
        context == AIContext.pastoral) {
      prompt +=
          "Focus on spiritual application, encouragement, and faithful interpretation. ";
    }

    prompt += "Always provide the relevant NRSVue verses to give context. ";
    prompt +=
        "However, if the user asks for a summary of an entire chapter, do NOT provide the full chapter text; only cite a few key verses. ";
    prompt +=
        "When analyzing texts, provide the original Greek or Hebrew keywords and their meanings to deepen the user's understanding. ";
    prompt += "Never curse. ";

    if (denom == Denomination.catholic) {
      prompt += "Be respectful of Catholic tradition and the Deuterocanon. ";
    } else if (denom == Denomination.evangelical) {
      prompt +=
          "Emphasize the authority of Scripture and personal relationship with God. ";
    } else if (denom == Denomination.atheist) {
      prompt +=
          "Be respectful of skepticism and focus on literary/historical analysis without assuming belief. ";
    } else if (denom == Denomination.orthodox ||
        denom == Denomination.copticOrthodox) {
      prompt +=
          "Emphasize the Church Fathers, the Septuagint, and Holy Tradition. ";
    } else if (denom == Denomination.seventhDayAdventist) {
      prompt +=
          "Be respectful of the Sabbath, wholeness, and the Second Coming. ";
    } else if (denom == Denomination.latterDaySaint) {
      prompt += "Be respectful of Latter-day Saint beliefs and terminology. ";
    } else if (denom == Denomination.messianicJewish) {
      prompt +=
          "Emphasize the Jewish roots of the faith and the connection between the Tanakh and the New Testament. ";
    } else if (denom == Denomination.quaker) {
      prompt += "Emphasize the Inner Light, simplicity, and peace. ";
    } else if (denom == Denomination.anglican ||
        denom == Denomination.mainlineProtestant) {
      prompt += "Balance scripture, tradition, and reason. ";
    } else if (denom == Denomination.reformed ||
        denom == Denomination.presbyterian) {
      prompt +=
          "Emphasize the sovereignty of God, covenant theology, and the doctrines of grace. ";
    } else if (denom == Denomination.pentecostal ||
        denom == Denomination.assemblyOfGod) {
      prompt +=
          "Emphasize the work of the Holy Spirit, spiritual gifts, and personal experience of God. ";
    } else if (denom == Denomination.lutheran) {
      prompt +=
          "Emphasize justification by grace through faith and the distinction between Law and Gospel. ";
    } else if (denom == Denomination.baptist) {
      prompt +=
          "Emphasize believer's baptism, local church autonomy, and the priesthood of all believers. ";
    } else if (denom == Denomination.methodist ||
        denom == Denomination.nazarene) {
      prompt += "Emphasize holiness, sanctification, and prevenient grace. ";
    } else if (denom == Denomination.churchOfChrist) {
      prompt +=
          "Emphasize a return to New Testament Christianity and silence where the Bible is silent. ";
    } else if (denom == Denomination.anabaptist) {
      prompt += "Emphasize discipleship, non-violence, and community. ";
    } else if (denom == Denomination.jewish) {
      prompt +=
          "Be respectful of Jewish tradition, the Torah, and Talmudic commentary. Contextualize from a perspective of interfaith dialogue. ";
    } else if (denom == Denomination.muslim) {
      prompt +=
          "Be respectful of Islamic beliefs while explaining the Christian perspective clearly and kindly. ";
    } else if (denom == Denomination.agnostic) {
      prompt +=
          "Be explanatory and accessible, assuming good faith curiosity without demanding commitment. ";
    } else if (denom == Denomination.nondenominational) {
      prompt += "Focus on " +
          (context == AIContext.academic ? "ecumenical" : "broad evangelical") +
          " Christian themes without denominational distinctives. ";
    }

    prompt +=
        "Cite Bible books/chapters/verses (use lesser‑known ones when possible). Don't repeat the user's request at the top of your reply, don't label the response, and don't repeat your own answers.";

    return prompt;
  }

  // ─────────────────────────────── CHAT PERSISTENCE ───────────────────────────

  /// Get all saved chats, sorted by most recent first
  Future<List<SavedChat>> getSavedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final chatsJson = prefs.getStringList(_savedChatsKey) ?? [];
    final chats =
        chatsJson.map((json) => SavedChat.fromJsonString(json)).toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  /// Save a chat to local storage
  Future<void> saveChat(SavedChat chat) async {
    final prefs = await SharedPreferences.getInstance();
    final chats = await getSavedChats();

    // Find and update existing or add new
    final existingIndex = chats.indexWhere((c) => c.id == chat.id);
    if (existingIndex != -1) {
      chats[existingIndex] = chat;
    } else {
      chats.add(chat);
    }

    final chatsJson = chats.map((c) => c.toJsonString()).toList();
    await prefs.setStringList(_savedChatsKey, chatsJson);
  }

  /// Delete a chat from local storage
  Future<void> deleteChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final chats = await getSavedChats();
    chats.removeWhere((c) => c.id == chatId);
    final chatsJson = chats.map((c) => c.toJsonString()).toList();
    await prefs.setStringList(_savedChatsKey, chatsJson);
  }

  /// Clear all saved chats
  Future<void> clearAllChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedChatsKey);
    await prefs.remove(_currentChatIdKey);
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

      // Save current chat ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentChatIdKey, chatId);
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

    // Save the new empty chat - REMOVED to prevent blank chats in history
    // await saveChat(chat);

    // Save current chat ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentChatIdKey, chat.id);

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

    // No current chat or it was deleted, create new one
    return await startNewChat();
  }

  /// Save the current chat state with messages
  Future<void> saveCurrentChat(List<String> displayMessages,
      {String? title}) async {
    if (_currentChatId == null) {
      // Don't clear history here, as we likely have in-memory history we want to keep
      // (e.g. from a summary session that is just now being saved)
      final chat = await startNewChat(clearHistory: false);
      _currentChatId = chat.id;
    }

    final messages = _convertDisplayMessagesToChat(displayMessages);
    final chats = await getSavedChats();
    final existingIndex = chats.indexWhere((c) => c.id == _currentChatId);

    SavedChat updatedChat;
    if (existingIndex != -1) {
      // Keep existing title if not provided and valid, or update if provided
      // If title is provided, use it.
      // If not, and existing title is 'New Chat', try to generate.
      // If existing title is customized, keep it.

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

    await saveChat(updatedChat);
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
          content: msg.replaceFirst('**Archie**: ', ''),
        );
      }
    }).toList();
  }

  List<String> convertChatToDisplayMessages(SavedChat chat) {
    return chat.messages.map((msg) {
      if (msg.role == 'user') {
        return '**You**: ${msg.content}';
      } else {
        return '**Archie**: ${msg.content}';
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

  void addToHistory(String role, String content) {
    _conversationHistory.add({
      'role': role,
      'content': content,
    });
  }

  /// Streams a response from the AI.
  /// Set [useHistory] to false for one-shot requests (like summarization) that shouldn't
  /// track or use conversation history.
  Stream<String> streamResponse(String userMessage,
      {bool useHistory = true}) async* {
    if (useHistory) {
      addToHistory('user', userMessage);
    }

    final prefs = await SharedPreferences.getInstance();
    final geminiApiKey = prefs.getString('geminiApiKey');
    final geminiModel = prefs.getString('geminiModel') ?? 'gemini-2.5-flash';

    Stream<String> responseStream;

    // Use Gemini directly if API key is set
    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      responseStream = _streamGeminiResponse(
          userMessage, geminiApiKey, geminiModel,
          useHistory: useHistory);
    } else {
      responseStream = _streamBackendResponse(
          userMessage, prefs.getString('token'),
          useHistory: useHistory);
    }

    String buffer = '';
    await for (final chunk in responseStream) {
      buffer += chunk;
      yield chunk;
    }

    if (useHistory) {
      addToHistory('assistant', buffer);
    }
  }

  Stream<String> _streamGeminiResponse(
      String userMessage, String apiKey, String modelName,
      {bool useHistory = true}) async* {
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        systemInstruction: Content.text(await _buildSystemPrompt()),
      );

      Stream<GenerateContentResponse> response;

      if (useHistory) {
        // Convert existing history to Gemini Content objects
        // NOTE: We do NOT add the current userMessage here because startChat expects previous history
        // and sendMesssage/sendMessageStream takes the new message.
        // However, we just added the user message to _conversationHistory in streamResponse wrapper.
        // So we need to exclude the LAST message (which is the current one) from the history passed to startChat.

        final geminiHistory = _conversationHistory
            .take(
                _conversationHistory.length - 1) // Exclude current user message
            .where((msg) =>
                msg['content'] != null &&
                msg['content']!.trim().isNotEmpty) // Filter empty messages
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
        // One-shot request without history
        response = model.generateContentStream([Content.text(userMessage)]);
      }

      await for (final chunk in response) {
        final text = chunk.text ?? '';
        yield text;
      }
    } catch (e, stack) {
      debugPrint('🔥 Gemini Error: $e\n$stack');
      yield 'Sorry, I encountered an error connecting to Gemini. Please check your API key and try again.';
    }
  }

  Stream<String> _streamBackendResponse(String userMessage, String? token,
      {bool useHistory = true}) async* {
    // Note: The backend expects the current message to be IN the history list if using history
    final messagesToSend = useHistory
        ? await _buildMessagePayload(_conversationHistory)
        : await _buildMessagePayload([
            {'role': 'user', 'content': userMessage}
          ]);

    final request = http.Request(
      'POST',
      Uri.parse('$_apiBase/chat/stream'),
    )
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..body = jsonEncode({'messages': messagesToSend});

    http.Client client = http.Client();
    http.StreamedResponse response;

    try {
      response = await client.send(request);
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      // network error → fall back to non-stream endpoint
      yield* _fallbackResponse(userMessage, useHistory: useHistory);
      return;
    }

    if (response.statusCode != 200) {
      yield* _fallbackResponse(userMessage, useHistory: useHistory);
      return;
    }

    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final chunk = line.substring(6);
      if (chunk == '[DONE]') break;
      yield chunk;
    }
  }

  Stream<String> _fallbackResponse(String userMessage,
      {bool useHistory = true}) async* {
    // Since streamResponse wrapper adds to history, but fallback might use getResponse which ALSO adds to history...
    // We need to be careful. getResponse is designed to be standalone.
    // However, getResponse logic below uses _conversationHistory.
    // Let's reuse getResponse but we need to handle the double-add issue if getResponse adds to history.

    // Actually, let's keep it simple: getResponse returns the string.
    // getResponse uses _conversationHistory.

    // If called from streamResponse:
    // 1. User msg already in _conversationHistory.
    // 2. getResponse (if we modify it) will see it.

    final reply = await getResponse(userMessage,
        useHistory: useHistory, alreadyAddedToHistory: true);
    yield reply;
  }

  /// Gets a response from the AI.
  Future<String> getResponse(String userMessage,
      {bool useHistory = true, bool alreadyAddedToHistory = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final geminiApiKey = prefs.getString('geminiApiKey');
    final geminiModel = prefs.getString('geminiModel') ?? 'gemini-2.5-flash';

    // Update history if not already done (e.g. if called directly, not from streamResponse)
    if (useHistory && !alreadyAddedToHistory) {
      addToHistory('user', userMessage);
    }

    String reply;

    // Use Gemini directly if API key is set
    if (geminiApiKey != null && geminiApiKey.isNotEmpty) {
      reply = await _getGeminiResponse(userMessage, geminiApiKey, geminiModel,
          useHistory: useHistory);
    } else {
      // Backend
      final token = prefs.getString('token');
      final messagesToSend = useHistory
          ? await _buildMessagePayload(_conversationHistory)
          : await _buildMessagePayload([
              {'role': 'user', 'content': userMessage}
            ]);

      final response = await http.post(
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

    reply = reply.replaceFirst(RegExp(r'^Archie:?\s*'), '');

    if (useHistory && !alreadyAddedToHistory) {
      addToHistory('assistant', reply);
    }

    return reply;
  }

  Future<String> _getGeminiResponse(
      String userMessage, String apiKey, String modelName,
      {bool useHistory = true}) async {
    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        systemInstruction: Content.text(await _buildSystemPrompt()),
      );

      if (useHistory) {
        // Same logic as stream: exclude current user message from history sent to startChat
        final geminiHistory = _conversationHistory
            .take(_conversationHistory.length - 1)
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
        // One-shot
        final response =
            await model.generateContent([Content.text(userMessage)]);
        return response.text ?? '';
      }
    } catch (e, stack) {
      debugPrint('🔥 Gemini Error: $e\n$stack');
      return 'Sorry, I encountered an error connecting to Gemini. Please check your API key and try again.';
    }
  }

  Future<List<Map<String, String>>> _buildMessagePayload(
      List<Map<String, String>> history) async {
    return [
      {'role': 'system', 'content': await _buildSystemPrompt()},
      ...history
    ];
  }
}
