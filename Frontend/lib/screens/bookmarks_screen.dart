import 'dart:convert';
import 'package:TheWord/providers/bible_provider.dart';
import 'package:TheWord/services/local_storage_service.dart';
import 'package:TheWord/models/local_bookmark.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../providers/settings_provider.dart';
import 'reader_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;

  Map<String, List<LocalBookmark>> groupedBookmarks = {};
  List<LocalHighlight> highlights = [];
  bool _isLoading = true;
  String? _expandedHighlightId;
  final Map<String, TextEditingController> _noteControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final bookmarksGrouped = await LocalStorageService.getBookmarksGrouped();
    final loadedHighlights = await LocalStorageService.getHighlights();
    
    if (mounted) {
      setState(() {
        groupedBookmarks = bookmarksGrouped;
        highlights = loadedHighlights;
        _isLoading = false;
      });
    }
  }

  Future<dynamic> fetchChapters(String translationId, String bookId) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.bybl.dev/api/bible/${translationId}/books/$bookId/chapters'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        var incomingChapters = data['data'];
        var chapters =
            incomingChapters.where((c) => c['number'] != 'intro').toList();

        return chapters;
      } else {
        throw Exception('Failed to load chapters');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      return [];
    }
  }

  Future<void> _deleteBookmark(String bookmarkId) async {
    await LocalStorageService.deleteBookmark(bookmarkId);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bookmark removed')),
      );
    }
  }

  Future<void> _deleteHighlight(String highlightId) async {
    await LocalStorageService.deleteHighlight(highlightId);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Highlight removed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final currentColor = settingsProvider.currentColor;
    final isDark = settingsProvider.currentThemeMode == ThemeMode.dark;
    final fontColor = isDark ? Colors.white : Colors.black;
    final effectiveFontColor = currentColor != null
        ? settingsProvider.getFontColor(currentColor)
        : fontColor;
    
    // Subtle card colors that blend in
    final cardColor = isDark 
        ? const Color(0xFF0A0A0A)  // Very dark grey (darker)
        : const Color(0xFFF5F5F5); // Very light grey

    return Scaffold(
      appBar: AppBar(
        backgroundColor: currentColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: effectiveFontColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bookmarks & Highlights',
          style: TextStyle(color: effectiveFontColor),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: effectiveFontColor,
          unselectedLabelColor: effectiveFontColor?.withOpacity(0.6),
          indicatorColor: effectiveFontColor,
          tabs: const [
            Tab(text: 'Chapters'),
            Tab(text: 'Highlights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChaptersTab(theme, cardColor: cardColor),
          _buildHighlightsTab(theme, cardColor: cardColor),
        ],
      ),
    );
  }

  Widget _buildChaptersTab(ThemeData theme, {required Color cardColor}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: groupedBookmarks.isEmpty
          ? ListView(
              padding: const EdgeInsets.only(top: 16),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No bookmarks yet',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Tap the bookmark icon while reading to save chapters',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: groupedBookmarks.entries
                  .expand((entry) => [
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 12, left: 16, bottom: 4),
                                child: Text(entry.key,
                                    style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        ...entry.value.map((bookmark) => Dismissible(
                              key: Key(bookmark.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child:
                                    const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) {
                                _deleteBookmark(bookmark.id);
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                color: cardColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                    child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  title: Text(bookmark.chapterName),
                                  subtitle: Text(bookmark.translationName),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.redAccent),
                                    onPressed: () =>
                                        _deleteBookmark(bookmark.id),
                                      ),
                                      onTap: () async {
                                        var chapters = await fetchChapters(
                                        bookmark.translationId, bookmark.bookId);
                                    if (mounted) {
                                      await Navigator.of(context)
                                            .push(MaterialPageRoute(
                                                builder: (_) => ReaderScreen(
                                                    bookId: bookmark.bookId,
                                                    chapterId: bookmark.chapterId,
                                                    chapterName:
                                                        bookmark.chapterName,
                                                      chapterIds: chapters
                                                          .map((c) => c['id'])
                                                          .toList(),
                                                      chapterNames: chapters
                                                          .map((c) =>
                                                              'Chapter ${c['number']}')
                                                          .toList(),
                                                    bookName: bookmark.bookName,
                                                    translationId:
                                                        bookmark.translationId,
                                                    translationName:
                                                        bookmark.translationName,
                                                  )));
                                      // Reload data when returning from reader
                                      _loadData();
                                    }
                                  },
                                ),
                                    ),
                                  ))
                            ])
                        .toList(),
                  ),
          );
  }

  Widget _buildHighlightsTab(ThemeData theme, {required Color cardColor}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: highlights.isEmpty
          ? ListView(
              padding: const EdgeInsets.only(top: 16),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.format_paint, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No highlights yet',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Double-tap on verses while reading to highlight them',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              itemCount: highlights.length,
              itemBuilder: (context, index) {
                final highlight = highlights[index];
                final isExpanded = _expandedHighlightId == highlight.id;
                
                // Get or create controller for this highlight
                if (!_noteControllers.containsKey(highlight.id)) {
                  _noteControllers[highlight.id] = TextEditingController(text: highlight.note ?? '');
                }
                final noteController = _noteControllers[highlight.id]!;
                
                return Dismissible(
                  key: Key(highlight.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _noteControllers.remove(highlight.id);
                    _deleteHighlight(highlight.id);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    color: cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main content - tappable to expand
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedHighlightId = null;
                              } else {
                                _expandedHighlightId = highlight.id;
                                // Reset controller text when expanding
                                noteController.text = highlight.note ?? '';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  highlight.content,
                                  maxLines: isExpanded ? null : 3,
                                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        highlight.verseId,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (highlight.note != null && highlight.note!.isNotEmpty && !isExpanded)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.note,
                                          size: 16,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                      color: Colors.grey[500],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Expanded section with note editing
                        if (isExpanded) ...[
                          Divider(
                            height: 1,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Note',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: noteController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Add your note here...',
                                    hintStyle: TextStyle(color: Colors.grey[600]),
                                    filled: true,
                                    fillColor: isDark 
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.03),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                      label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                      onPressed: () {
                                        _noteControllers.remove(highlight.id);
                                        _deleteHighlight(highlight.id);
                                      },
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final note = noteController.text.trim();
                                        await LocalStorageService.updateHighlightNote(
                                          highlight.id,
                                          note.isEmpty ? null : note,
                                        );
                                        if (mounted) {
                                          setState(() {
                                            _expandedHighlightId = null;
                                          });
                                          _loadData();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Note saved')),
                                          );
                                        }
                                      },
                                      child: const Text('Save Note'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
