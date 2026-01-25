import 'package:TheWord/models/saved_chat.dart';
import 'package:TheWord/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../shared/widgets/api_key_setup_prompt.dart';
import '../shared/widgets/ai_disclaimer.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  final ChatService _chatService = ChatService();
  String _streamingReply = '';
  bool _isStreaming = false;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCurrentChat();
  }

  Future<void> _loadCurrentChat() async {
    // Always start a new chat when entering the screen, per user request
    final chat = await _chatService.startNewChat();
    setState(() {
      _messages.clear();
      _isLoading = false;
    });
  }

  void _scrollToBottom({bool isImmediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Small delay to allow layout to settle, especially for Markdown
      if (isImmediate) {
         // for initial load, wait a bit longer to ensure content is rendered
         await Future.delayed(const Duration(milliseconds: 100));
      }
      
      if (_scrollController.hasClients) {
        final position = _scrollController.position.maxScrollExtent;
        if (isImmediate) {
          _scrollController.jumpTo(position);
        } else {
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _sendMessage() async {
    final originalMessage = _controller.text.trim();
    if (originalMessage.isEmpty || _isStreaming) return;

    _controller.clear();

    setState(() {
      _messages.add('**You**: $originalMessage');
      _streamingReply = '';
      _isStreaming = true;
    });

    // Save immediately with the user message
    await _chatService.saveCurrentChat(_messages);

    bool success = await _tryStreamResponse(originalMessage);

    if (!success) {
      setState(() {
        _isStreaming = false;
        _messages.removeLast(); // Remove the failed user message
      });

      _controller.text = originalMessage;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      // Save the chat with the assistant response
      await _chatService.saveCurrentChat(_messages);
    }
  }

  Future<bool> _tryStreamResponse(String message) async {
    try {
      final stream = _chatService.streamResponse(message);

      await for (final chunk in stream) {
        setState(() {
          _streamingReply += chunk;
        });
        _scrollToBottom();
      }

      setState(() {
        _messages.add('**Archie**: $_streamingReply');
        _streamingReply = '';
        _isStreaming = false;
      });

      return true;
    } catch (e) {
      // Retry once
      try {
        final retryStream = _chatService.streamResponse(message);

        await for (final chunk in retryStream) {
          setState(() {
            _streamingReply += chunk;
          });
          _scrollToBottom();
        }

        setState(() {
          _messages.add('**Archie**: $_streamingReply');
          _streamingReply = '';
          _isStreaming = false;
        });

        return true;
      } catch (e2) {
        return false;
      }
    }
  }

  Future<void> _startNewChat() async {
    final chat = await _chatService.startNewChat();
    setState(() {
      _messages.clear();
    });
  }

  Future<void> _loadChat(SavedChat chat) async {
    await _chatService.loadChat(chat.id);
    setState(() {
      _messages.clear();
      _messages.addAll(_chatService.convertChatToDisplayMessages(chat));
    });
    _scrollToBottom(isImmediate: true);
  }

  Future<void> _deleteChat(SavedChat chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete "${chat.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatService.deleteChat(chat.id);
      // If we deleted the current chat, start a new one
      if (chat.id == _chatService.currentChatId) {
        await _startNewChat();
      }
    }
  }

  Future<void> _clearAllChats() async {
    await _chatService.clearAllChats();
    await _startNewChat();
  }

  void _showSavedChats() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SavedChatsSheet(
        chatService: _chatService,
        onChatSelected: (chat) {
          Navigator.pop(context);
          _loadChat(chat);
        },
        onNewChat: () {
          Navigator.pop(context);
          _startNewChat();
        },
        onDeleteChat: (chat) async {
          await _deleteChat(chat);
          // Refresh the sheet
          Navigator.pop(context);
          _showSavedChats();
        },
        onClearAll: () {
          Navigator.pop(context);
          _clearAllChats();
        },
        currentChatId: _chatService.currentChatId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final allMessages = List<String>.from(_messages);
    if (_streamingReply.isNotEmpty) {
      allMessages.add('**Archie**: $_streamingReply');
    }

    final hasApiKey = settings.geminiApiKey != null && settings.geminiApiKey!.isNotEmpty;

    final currentColor = settings.currentColor;
    final fontColor = settings.currentThemeMode == ThemeMode.dark
        ? Colors.white
        : Colors.black;
    final effectiveFontColor = currentColor != null
        ? settings.getFontColor(currentColor)
        : fontColor;

    // Show API key setup prompt if no key is configured
    if (!hasApiKey) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: currentColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: effectiveFontColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Ask Archie', style: TextStyle(color: effectiveFontColor)),
        ),
        body: ApiKeySetupPrompt(
          onGoToSettings: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: currentColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: effectiveFontColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Ask Archie', style: TextStyle(color: effectiveFontColor)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: currentColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: effectiveFontColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ask Archie', style: TextStyle(color: effectiveFontColor)),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: effectiveFontColor),
            tooltip: 'Chat History',
            onPressed: _showSavedChats,
          ),
          IconButton(
            icon: Icon(Icons.add_comment_outlined, color: effectiveFontColor),
            tooltip: 'New Chat',
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: allMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icon/archie.png',
                          width: 150,
                          height: 150,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a new conversation',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: allMessages.length,
                    itemBuilder: (context, index) {
                      final message = allMessages[index];
                      final isUser = message.startsWith('**You**:');
                      final content =
                          message.replaceFirst(RegExp(r'^\*\*.*?\*\*:\s*'), '');

                      return Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 14),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? settings.currentColor
                                    : Colors.grey[900],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                                  bottomRight: Radius.circular(isUser ? 0 : 16),
                                ),
                              ),
                              child: MarkdownBody(
                                data: content,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    color:
                                        isUser ? settings.fontColor : Colors.white,
                                    fontSize: 16,
                                  ),
                                  strong: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isUser ? settings.fontColor : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!isUser)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: const AiDisclaimer(compact: true),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          if (_isStreaming && _streamingReply.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: ThinkingIndicator(),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: 8.0,
              right: 8.0,
              top: 8.0,
              bottom: 8.0 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      reverse: true,
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Ask something...',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedChatsSheet extends StatefulWidget {
  final ChatService chatService;
  final Function(SavedChat) onChatSelected;
  final VoidCallback onNewChat;
  final Function(SavedChat) onDeleteChat;
  final VoidCallback onClearAll;
  final String? currentChatId;

  const _SavedChatsSheet({
    required this.chatService,
    required this.onChatSelected,
    required this.onNewChat,
    required this.onDeleteChat,
    required this.onClearAll,
    this.currentChatId,
  });

  @override
  State<_SavedChatsSheet> createState() => _SavedChatsSheetState();
}

class _SavedChatsSheetState extends State<_SavedChatsSheet> {
  List<SavedChat> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final chats = await widget.chatService.getSavedChats();
    setState(() {
      _chats = chats;
      _isLoading = false;
    });
  }

  Future<void> _showClearAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Chats'),
        content: Text(
          'Are you sure you want to delete all ${_chats.length} chat${_chats.length == 1 ? '' : 's'}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onClearAll();
    }
  }

  Future<void> _showDeleteDialog(SavedChat chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete "${chat.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDeleteChat(chat);
      // Refresh the list
      _loadChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Chat History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_chats.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'clear_all') {
                            _showClearAllDialog();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'clear_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Clear All Chats', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    TextButton.icon(
                      onPressed: widget.onNewChat,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Chat'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Chat list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _chats.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 16),
                                Text(
                                  'No saved chats yet',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _chats.length,
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              final isCurrentChat =
                                  chat.id == widget.currentChatId;
                              final dateFormat = DateFormat('MMM d, yyyy');
                              final timeFormat = DateFormat('h:mm a');

                              return Dismissible(
                                key: Key(chat.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Chat'),
                                      content: Text(
                                          'Are you sure you want to delete "${chat.title}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (direction) {
                                  widget.onDeleteChat(chat);
                                },
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isCurrentChat
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[800],
                                    child: Icon(
                                      isCurrentChat
                                          ? Icons.chat
                                          : Icons.chat_bubble_outline,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    chat.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isCurrentChat
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${dateFormat.format(chat.updatedAt)} at ${timeFormat.format(chat.updatedAt)}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isCurrentChat)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .primaryColor
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Current',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        )
                                      else
                                        Text(
                                          '${chat.messages.length} msgs',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline,
                                            color: Colors.grey[600], size: 20),
                                        onPressed: () => _showDeleteDialog(chat),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  onTap: () => widget.onChatSelected(chat),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({Key? key}) : super(key: key);

  @override
  _ThinkingIndicatorState createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dot1, _dot2, _dot3;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(seconds: 1), vsync: this)
          ..repeat();

    _dot1 = Tween(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3)),
    );
    _dot2 = Tween(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.6)),
    );
    _dot3 = Tween(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Container(
            width: 8,
            height: 8 + animation.value,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_dot(_dot1), _dot(_dot2), _dot(_dot3)],
    );
  }
}
