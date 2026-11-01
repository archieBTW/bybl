import 'package:TheWord/models/local_bookmark.dart';
import 'package:TheWord/providers/bible_provider.dart';
import 'package:TheWord/screens/reader_screen.dart';
import 'package:TheWord/screens/settings_screen.dart';
import 'package:TheWord/shared/widgets/api_key_setup_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/verse_provider.dart';

class SelectableTextHighlight extends StatefulWidget {
  final List<Map<String, dynamic>> verses;
  final TextStyle style;
  final int? currentVerseIndex;
  final String bookName;
  final String translationId;
  final String chapterId;
  final String? copyright;
  final String? targetVerseId;
  final ScrollController? scrollController;

  const SelectableTextHighlight({
    Key? key,
    required this.verses,
    required this.style,
    required this.bookName,
    required this.chapterId,
    required this.translationId,
    this.currentVerseIndex,
    this.targetVerseId,
    this.copyright,
    this.scrollController,
  }) : super(key: key);

  @override
  SelectableTextHighlightState createState() => SelectableTextHighlightState();
}

class SelectableTextHighlightState extends State<SelectableTextHighlight> {
  final Set<String> selectedVerseIds = {};
  String? _activeTooltipVerseId;
  final Map<String, GlobalKey> _verseKeys = {};

  static const List<Color> _highlighterPalette = [
    Color(0xFFE6C84F), // Warm Gold
    Color(0xFF5DC482), // Mint Green
    Color(0xFF5DA9E9), // Sky Blue
    Color(0xFFF0789C), // Rose Pink
    Color(0xFFA77DE8), // Lavender
    Color(0xFFF2994A), // Coral Orange
  ];

  @override
  void initState() {
    super.initState();
    if (widget.targetVerseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTarget();
      });
    }
  }

  @override
  void didUpdateWidget(SelectableTextHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetVerseId != oldWidget.targetVerseId &&
        widget.targetVerseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTarget();
      });
    }
  }

  void _scrollToTarget() {
    final targetId = widget.targetVerseId;
    if (targetId == null || !mounted) return;

    final key = _verseKeys[targetId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.3,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return;
    }

    // If the target verse is further down the virtualized ListView and not yet mounted,
    // jump to an estimated offset first so ListView builds it, then ensureVisible.
    final targetIndex =
        widget.verses.indexWhere((v) => v['id'].toString() == targetId);
    final controller = widget.scrollController;
    if (targetIndex > 0 && controller != null && controller.hasClients) {
      final estimatedOffset = (targetIndex * 68.0)
          .clamp(0.0, controller.position.maxScrollExtent);
      controller.jumpTo(estimatedOffset);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final mountedContext = _verseKeys[targetId]?.currentContext;
        if (mountedContext != null) {
          Scrollable.ensureVisible(
            mountedContext,
            alignment: 0.3,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _resolveSavedVerseId(String verseId, String translationId) {
    if (translationId.toUpperCase() == 'ESV' && !verseId.contains(':')) {
      return '${widget.chapterId}:$verseId';
    }
    return verseId;
  }

  void _handleTap(String verseId) {
    setState(() {
      if (selectedVerseIds.contains(verseId)) {
        selectedVerseIds.remove(verseId);
        if (_activeTooltipVerseId == verseId) {
          _activeTooltipVerseId =
              selectedVerseIds.isNotEmpty ? selectedVerseIds.last : null;
        }
      } else {
        selectedVerseIds.add(verseId);
        _activeTooltipVerseId = verseId;
      }
    });
  }

  void clearSelection() {
    if (selectedVerseIds.isEmpty) return;
    setState(() {
      selectedVerseIds.clear();
      _activeTooltipVerseId = null;
    });
  }

  Future<void> _toggleSingleVerseDefaultHighlight(
    VerseProvider verseProvider,
    SettingsProvider settingsProvider,
    String verseId,
    String text,
  ) async {
    final translationId =
        settingsProvider.currentTranslationId ?? widget.translationId;
    final savedVerseId = _resolveSavedVerseId(verseId, translationId);
    final defaultColorValue =
        settingsProvider.highlightColor?.value ?? Colors.amber.value;

    if (verseProvider.isVerseSaved(savedVerseId)) {
      final userVerseId = verseProvider.getSavedVerseUserVerseID(savedVerseId);
      if (userVerseId != null) {
        await verseProvider.unsaveVerse(userVerseId);
      }
    } else {
      await verseProvider.saveVerse(
        savedVerseId,
        text,
        colorValue: defaultColorValue,
      );
    }
  }

  Future<void> _applyHighlightColorToSelected(
    VerseProvider verseProvider,
    SettingsProvider settingsProvider,
    int colorValue,
  ) async {
    final translationId =
        settingsProvider.currentTranslationId ?? widget.translationId;
    final orderedSelected = _getOrderedSelectedVerses();

    for (final v in orderedSelected) {
      final rawId = v['id'].toString();
      final text = (v['text'] ?? '').toString();
      final savedVerseId = _resolveSavedVerseId(rawId, translationId);
      await verseProvider.saveVerse(
        savedVerseId,
        text,
        colorValue: colorValue,
      );
    }

    if (mounted) {
      setState(() {
        selectedVerseIds.clear();
        _activeTooltipVerseId = null;
      });
    }
  }

  Future<void> _removeHighlightFromSelected(
    VerseProvider verseProvider,
    SettingsProvider settingsProvider,
  ) async {
    final translationId =
        settingsProvider.currentTranslationId ?? widget.translationId;
    final orderedSelected = _getOrderedSelectedVerses();

    for (final v in orderedSelected) {
      final rawId = v['id'].toString();
      final savedVerseId = _resolveSavedVerseId(rawId, translationId);
      if (verseProvider.isVerseSaved(savedVerseId)) {
        final userVerseId =
            verseProvider.getSavedVerseUserVerseID(savedVerseId);
        if (userVerseId != null) {
          await verseProvider.unsaveVerse(userVerseId);
        }
      }
    }

    if (mounted) {
      setState(() {
        selectedVerseIds.clear();
        _activeTooltipVerseId = null;
      });
    }
  }

  List<Map<String, dynamic>> _getOrderedSelectedVerses() {
    if (selectedVerseIds.isEmpty) return [];
    return widget.verses
        .where((v) => selectedVerseIds.contains(v['id'].toString()))
        .toList();
  }

  List<String> getSelectedTexts() {
    return _getOrderedSelectedVerses()
        .map((v) => (v['text'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  List<String> getSelectedVerseIds() {
    return _getOrderedSelectedVerses()
        .map((v) => v['id'].toString())
        .toList();
  }

  String _extractDisplayVerseNumber(String verseId) {
    if (widget.translationId.toUpperCase() == 'ESV') {
      return verseId;
    }
    final parts = verseId.split('.');
    return parts.length >= 3 ? parts[2] : parts.last;
  }

  double _indentForLineStyle(String style) {
    switch (style) {
      case 'q1':
      case 'q':
      case 'qm1':
      case 'pi':
      case 'pi1':
      case 'li1':
      case 'li':
        return 16.0;
      case 'q2':
      case 'qm2':
      case 'pi2':
      case 'li2':
        return 34.0;
      case 'q3':
      case 'qm3':
      case 'pi3':
      case 'li3':
        return 50.0;
      case 'mi':
        return 12.0;
      default:
        return 0.0;
    }
  }

  bool _isPoeticOrStructuredVerse(Map<String, dynamic> verse) {
    final rawLines = verse['lines'];
    if (rawLines is! List || rawLines.isEmpty) return false;
    if (rawLines.length > 1) return true;
    final first = rawLines.first;
    if (first is Map) {
      final style = (first['style'] ?? 'p').toString();
      final stanzaBreak = first['stanzaBreak'] == true;
      if (stanzaBreak) return true;
      if (style != 'p' && style != 'm') return true;
    }
    return false;
  }

  Widget _buildVerseContent({
    required BuildContext context,
    required Map<String, dynamic> verse,
    required String verseNumber,
    required String verseText,
    required TextStyle baseTextStyle,
    required TextStyle verseNumberStyle,
  }) {
    final rawLines = verse['lines'];
    if (rawLines is! List || rawLines.isEmpty) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$verseNumber  ', style: verseNumberStyle),
            TextSpan(text: verseText, style: baseTextStyle),
          ],
        ),
      );
    }

    final lines = rawLines
        .whereType<Map>()
        .map((l) => Map<String, dynamic>.from(l))
        .where((l) => (l['text'] ?? '').toString().trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$verseNumber  ', style: verseNumberStyle),
            TextSpan(text: verseText, style: baseTextStyle),
          ],
        ),
      );
    }

    // Single standard paragraph line without stanza break
    if (lines.length == 1 &&
        (lines.first['style'] == 'p' || lines.first['style'] == 'm') &&
        lines.first['stanzaBreak'] != true) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$verseNumber  ', style: verseNumberStyle),
            TextSpan(
              text: (lines.first['text'] ?? verseText).toString(),
              style: baseTextStyle,
            ),
          ],
        ),
      );
    }

    // Multi-line or poetic/superscription formatting (e.g. Psalms, Proverbs, Prophets)
    final children = <Widget>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineText = (line['text'] ?? '').toString().trim();
      final style = (line['style'] ?? 'p').toString();
      final stanzaBreak = line['stanzaBreak'] == true;

      if (stanzaBreak) {
        children.add(const SizedBox(height: 10.0));
      }

      final isSuperscription = style == 'd' || style == 'sp';
      final isRightAligned = style == 'qr';
      final indent = _indentForLineStyle(style);

      final effectiveLineStyle = isSuperscription
          ? baseTextStyle.copyWith(
              fontStyle: FontStyle.italic,
              fontSize: (baseTextStyle.fontSize ?? 18.0) * 0.92,
              fontWeight:
                  style == 'sp' ? FontWeight.w600 : baseTextStyle.fontWeight,
            )
          : baseTextStyle;

      children.add(
        Padding(
          padding: EdgeInsets.only(
            left: indent,
            top: i == 0 ? 0.0 : 2.0,
            bottom: isSuperscription ? 4.0 : 0.0,
          ),
          child: Text.rich(
            TextSpan(
              children: [
                if (i == 0)
                  TextSpan(text: '$verseNumber  ', style: verseNumberStyle),
                TextSpan(text: lineText, style: effectiveLineStyle),
              ],
            ),
            textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<Color> _buildColorOptions(SettingsProvider settingsProvider) {
    final defaultColor =
        Color(settingsProvider.highlightColor?.value ?? 0xFFE6C84F);
    final colors = <Color>[defaultColor];
    for (final c in _highlighterPalette) {
      if (!colors.any((existing) => existing.value == c.value)) {
        colors.add(c);
      }
    }
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final verseProvider = Provider.of<VerseProvider>(context);
    final bibleProvider = Provider.of<BibleProvider>(context, listen: false);
    final isDark = settingsProvider.currentThemeMode == ThemeMode.dark;

    final fontSize = settingsProvider.readerFontSize;
    final lineHeight = settingsProvider.readerLineHeight;
    final fontFamily = settingsProvider.readerUseSerif ? 'Georgia' : null;

    final hasCopyright = widget.copyright != null &&
        widget.copyright!.isNotEmpty &&
        widget.verses.isNotEmpty;
    final totalCount = widget.verses.length + (hasCopyright ? 1 : 0);

    final colorOptions = _buildColorOptions(settingsProvider);
    final anySelectedHighlighted = selectedVerseIds.any((id) {
      final savedId = _resolveSavedVerseId(
        id,
        settingsProvider.currentTranslationId ?? widget.translationId,
      );
      return verseProvider.isVerseSaved(savedId);
    });

    final baseTextColor = isDark
        ? Colors.white.withOpacity(0.92)
        : Colors.black.withOpacity(0.88);

    return Stack(
      children: [
        ListView.builder(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          key: PageStorageKey(widget.chapterId),
          cacheExtent: 500.0,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          padding: EdgeInsets.only(
            top: 8.0,
            bottom: selectedVerseIds.isNotEmpty ? 96.0 : 24.0,
          ),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            if (hasCopyright && index == widget.verses.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 16.0),
                child: Text(
                  widget.copyright!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              );
            }

            final verse = widget.verses[index];
            final verseId = verse['id'].toString();
            final verseText = (verse['text'] ?? '').toString();

            if (verseText.trim().isEmpty ||
                double.tryParse(verseText) != null) {
              return const SizedBox.shrink();
            }

            final savedVerseId = _resolveSavedVerseId(
              verseId,
              settingsProvider.currentTranslationId ?? widget.translationId,
            );
            final isSelected = selectedVerseIds.contains(verseId);
            final isHighlighted = verseProvider.isVerseSaved(savedVerseId);
            final isCurrentVerse = (widget.currentVerseIndex == index);

            final customColorVal =
                verseProvider.getVerseColorValue(savedVerseId);
            final rawHighlightColor = customColorVal != null
                ? Color(customColorVal)
                : (settingsProvider.highlightColor ?? Colors.amber);

            if (widget.targetVerseId != null &&
                verseId == widget.targetVerseId) {
              _verseKeys.putIfAbsent(verseId, () => GlobalKey());
            }

            final isPoetic = _isPoeticOrStructuredVerse(verse);
            final verseNumStr = _extractDisplayVerseNumber(verseId);

            final baseTextStyle = DefaultTextStyle.of(context).style.copyWith(
                  fontSize: fontSize,
                  height: lineHeight,
                  fontFamily: fontFamily,
                  color: baseTextColor,
                  fontWeight:
                      isCurrentVerse ? FontWeight.w600 : FontWeight.normal,
                );

            final verseNumberStyle = TextStyle(
              fontSize: (fontSize * 0.68).clamp(11.0, 16.0),
              height: lineHeight,
              fontFamily: fontFamily,
              color: isHighlighted
                  ? (isDark ? Colors.white70 : Colors.black54)
                  : Colors.grey,
              fontWeight: FontWeight.w700,
            );

            // Natural, non-blocky highlight & selection decoration
            BoxDecoration? verseDecoration;
            if (isHighlighted || isSelected || isCurrentVerse) {
              final bgColor = isHighlighted
                  ? rawHighlightColor.withOpacity(isDark ? 0.25 : 0.22)
                  : (isSelected
                      ? (isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.05))
                      : Colors.transparent);

              verseDecoration = BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.35)
                            : Colors.black.withOpacity(0.25),
                        width: 1.2,
                      )
                    : (isHighlighted
                        ? Border(
                            left: BorderSide(
                              color: rawHighlightColor.withOpacity(0.85),
                              width: 3.5,
                            ),
                          )
                        : null),
              );
            }

            return GestureDetector(
              key: _verseKeys[verseId],
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleTap(verseId),
              onDoubleTap: () {
                _toggleSingleVerseDefaultHighlight(
                  verseProvider,
                  settingsProvider,
                  verseId,
                  verseText,
                );
              },
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: isPoetic ? 1.5 : 2.5,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: isPoetic ? 5.0 : 7.0,
                ),
                decoration: verseDecoration,
                child: _buildVerseContent(
                  context: context,
                  verse: verse,
                  verseNumber: verseNumStr,
                  verseText: verseText,
                  baseTextStyle: baseTextStyle,
                  verseNumberStyle: verseNumberStyle,
                ),
              ),
            );
          },
        ),

        // Floating multi-verse selection & multi-color highlighter bar
        if (selectedVerseIds.isNotEmpty)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Highlighter color swatches + unhighlight
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...colorOptions.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final color = entry.value;
                            final isDefault = idx == 0;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5.0),
                              child: Tooltip(
                                message: isDefault
                                    ? 'Default Highlighter'
                                    : 'Highlight',
                                child: InkWell(
                                  onTap: () => _applyHighlightColorToSelected(
                                    verseProvider,
                                    settingsProvider,
                                    color.value,
                                  ),
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDefault
                                            ? (isDark
                                                ? Colors.white
                                                : Colors.black87)
                                            : Colors.black26,
                                        width: isDefault ? 2.2 : 1.0,
                                      ),
                                    ),
                                    child: isDefault
                                        ? Icon(
                                            Icons.star_rounded,
                                            size: 14,
                                            color: color.computeLuminance() >
                                                    0.5
                                                ? Colors.black87
                                                : Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (anySelectedHighlighted)
                            Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.format_color_reset_outlined,
                                  size: 20,
                                ),
                                tooltip: 'Remove Highlight',
                                onPressed: () => _removeHighlightFromSelected(
                                  verseProvider,
                                  settingsProvider,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 10),
                    // Row 2: Selected count + Copy + Summarize + Close
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            selectedVerseIds.length == 1
                                ? BibleReferenceFormatter.format(
                                    selectedVerseIds.first,
                                    books: bibleProvider.books,
                                  )
                                : '${selectedVerseIds.length} verses selected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.copy, size: 17),
                              label: const Text('Copy'),
                              onPressed: () {
                                final texts = getSelectedTexts().join(' ');
                                Clipboard.setData(ClipboardData(text: texts));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      selectedVerseIds.length == 1
                                          ? 'Verse copied to clipboard'
                                          : '${selectedVerseIds.length} verses copied to clipboard',
                                    ),
                                  ),
                                );
                                clearSelection();
                              },
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.summarize_outlined,
                                  size: 17),
                              label: const Text('Summarize'),
                              onPressed: () {
                                final texts = getSelectedTexts().join(' ');
                                final ids = getSelectedVerseIds();
                                _summarizeSelectedVerses(
                                  context,
                                  texts,
                                  ids,
                                  bibleProvider.books,
                                );
                              },
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Clear Selection',
                              onPressed: clearSelection,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _summarizeSelectedVerses(
    BuildContext context,
    String verseText,
    List<String> verseIds,
    List<dynamic> books,
  ) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final hasApiKey = settingsProvider.geminiApiKey != null &&
        settingsProvider.geminiApiKey!.isNotEmpty;

    if (!hasApiKey) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Key Required'),
          content: SingleChildScrollView(
            child: ApiKeySetupPrompt(
              onGoToSettings: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
        ),
      );
      return;
    }

    String readableRef = '';
    if (verseIds.length == 1) {
      readableRef = BibleReferenceFormatter.format(verseIds.first, books: books);
    } else if (verseIds.length > 1) {
      final firstRef =
          BibleReferenceFormatter.format(verseIds.first, books: books);
      final lastNum = _extractDisplayVerseNumber(verseIds.last);
      readableRef = '$firstRef–$lastNum';
    }

    final title =
        readableRef.isNotEmpty ? 'Summary of $readableRef' : 'Verse Summary';
    final reference = readableRef.isNotEmpty ? ' ($readableRef)' : '';

    final prompt =
        'Summarize and interpret the following Bible passage$reference:\n\n$verseText';

    showDialog(
      context: context,
      builder: (context) => StreamedSummaryModal(
        prompt: prompt,
        title: title,
      ),
    );
  }
}

class SensitivityScrollPhysics extends ScrollPhysics {
  const SensitivityScrollPhysics({super.parent});

  @override
  SensitivityScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SensitivityScrollPhysics(parent: buildParent(ancestor));
  }
}
