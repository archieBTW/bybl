import 'package:TheWord/screens/reader_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/verse_provider.dart';
import 'package:TheWord/shared/widgets/api_key_setup_prompt.dart';
import 'package:TheWord/screens/settings_screen.dart';
import 'package:flutter/services.dart';

class SelectableTextHighlight extends StatefulWidget {
  final List<Map<String, dynamic>> verses;
  final TextStyle style;
  int? currentVerseIndex;
  String bookName;
  String translationId;
  String chapterId;
  String? copyright;
  SelectableTextHighlight(
      {Key? key,
      required this.verses,
      required this.style,
      required this.bookName,
      required this.chapterId,
      required this.translationId,
      this.currentVerseIndex,
      this.copyright})
      : super(key: key);

  @override
  SelectableTextHighlightState createState() => SelectableTextHighlightState();
}

class SelectableTextHighlightState extends State<SelectableTextHighlight> {
  // Set<String> selectedVerseIds = {};
  String? _activeTooltipVerseId;
  String? selectedVerseId; // Only one selected at a time

  @override
  void initState() {
    super.initState();
  }

  void _toggleVerse(
    VerseProvider verseProvider,
    String chapter,
    String verseId,
    String text,
    String translationId,
  ) async {
    String savedVerseId = verseId;
    if (translationId == 'ESV') {
      savedVerseId = "$chapter:$verseId";
    }

    if (verseProvider.isVerseSaved(savedVerseId)) {
      final userVerseId = verseProvider.getSavedVerseUserVerseID(savedVerseId);
      if (userVerseId != null) {
        await verseProvider.unsaveVerse(userVerseId);
      }
    } else {
      await verseProvider.saveVerse(savedVerseId, text);
    }
  }

  bool _isNumeric(String str) {
    if (str.isEmpty) return false;
    return double.tryParse(str) != null;
  }

  List<String> getSelectedTexts() {
    if (selectedVerseId == null) return [];
    final selected = widget.verses.firstWhere(
      (v) {
        final id = widget.translationId == 'esv'
            ? "${widget.chapterId}:${v['id']}"
            : v['id'];
        return id == selectedVerseId;
      },
      orElse: () => {},
    );
    return selected.isNotEmpty ? [selected['text']] : [];
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final verseProvider = Provider.of<VerseProvider>(context);

    final versesWithCopyright = List<Map<String, dynamic>>.from(widget.verses);

    // Add copyright at the end if available
    if (widget.copyright != null && widget.copyright!.isNotEmpty && widget.verses.isNotEmpty) {
      versesWithCopyright.add({
        'id': 'copyright',
        'text': widget.copyright,
        'isCopyright': true,
      });
    }

    return ListView.builder(
      key: PageStorageKey(widget.chapterId),
      itemCount: versesWithCopyright.length,
      itemBuilder: (context, index) {
        final verse = versesWithCopyright[index];
        final verseId = verse['id'].toString();
        final verseText = verse['text'] ?? '';

        if (verse['isCopyright'] == true) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Text(
              verseText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          );
        }

        if (verseText.trim().isEmpty || double.tryParse(verseText) != null) {
          return const SizedBox.shrink();
        }

        // final fullId = widget.translationId == 'bba9f40183526463-01'
        // ? "${widget.chapterId}:$verseId"
        // : verseId;

        // final isSelected = selectedVerseIds.contains(fullId);
        final isSelected = selectedVerseId == verseId;

        final isHighlighted = verseProvider.isVerseSaved(verseId);
        final isCurrentVerse = (widget.currentVerseIndex == index);

        final highlightColor = isHighlighted
            ? settingsProvider.highlightColor
            : Colors.transparent;

        final textColor = isHighlighted &&
                settingsProvider.highlightColor != null
            ? settingsProvider.getFontColor(settingsProvider.highlightColor!)
            : (settingsProvider.currentThemeMode == ThemeMode.dark
                ? Colors.white
                : Colors.black);

        return Stack(
          children: [
            GestureDetector(
              // onTap: () {
              //   if (widget.loggedIn)
              //     setState(() {
              //       if (selectedVerseId == fullId) {
              //         selectedVerseId = null;
              //         _activeTooltipVerseId = null;
              //       } else {
              //         selectedVerseId = fullId;
              //         _activeTooltipVerseId = fullId;
              //       }
              //     });
              // },
              onDoubleTap: () {
                _toggleVerse(
                  verseProvider,
                  widget.chapterId,
                  verseId,
                  verseText,
                  settingsProvider.currentTranslationId!,
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                // decoration: BoxDecoration(
                // color: highlightColor,
                // borderRadius: BorderRadius.circular(8.0),
                // ),
                child: SelectableRegion(
                  focusNode:
                      FocusNode(), // Can also reuse one for the whole screen
                  selectionControls: materialTextSelectionControls,
                  child: Text.rich(
                    TextSpan(
                      style: DefaultTextStyle.of(context).style.copyWith(
                            color: textColor,
                          ),
                      children: [
                        TextSpan(
                          text: widget.translationId == "ESV"
                              ? "$verseId  "
                              : "${verseId.split('.')[2]}  ",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: verseText,
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                            fontWeight: isCurrentVerse || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            decorationThickness: 4,
                            decoration:
                                isSelected ? TextDecoration.underline : null,
                            decorationStyle:
                                isSelected ? TextDecorationStyle.dotted : null,
                            backgroundColor: isHighlighted
                                ? highlightColor
                                : Colors.transparent,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              setState(() {
                                if (selectedVerseId == verseId) {
                                  selectedVerseId = null;
                                  _activeTooltipVerseId = null;
                                } else {
                                  selectedVerseId = verseId;
                                  _activeTooltipVerseId = verseId;
                                }
                              });
                            },
                        ),
                      ],
                    ),
                  ),
                ),

                // child: SelectableText.rich(
                //   TextSpan(
                //     style: DefaultTextStyle.of(context).style.copyWith(
                //           color: textColor,
                //         ),
                //     children: [
                //       TextSpan(
                //         text: widget.translationId == "ESV"
                //             ? "$verseId  "
                //             : "${verseId.split('.')[2]}  ",
                //         style: const TextStyle(
                //           fontSize: 12,
                //           color: Colors.grey,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //       TextSpan(
                //         text: verseText,
                //         style: TextStyle(
                //           fontSize: 18,
                //           color: textColor,
                //           fontWeight: isCurrentVerse || isSelected
                //               ? FontWeight.bold
                //               : FontWeight.normal,
                //           decorationThickness: 4,

                //           decoration:
                //               isSelected ? TextDecoration.underline : null,
                //           decorationStyle:
                //               isSelected ? TextDecorationStyle.dotted : null,
                //           backgroundColor: isHighlighted
                //               ? highlightColor
                //               : Colors.transparent, // ✅ highlight just text
                //         ),
                //         recognizer: TapGestureRecognizer()
                //           ..onTap = () {
                //             if (widget.loggedIn) {
                //               setState(() {
                //                 if (selectedVerseId == fullId) {
                //                   selectedVerseId = null;
                //                   _activeTooltipVerseId = null;
                //                 } else {
                //                   selectedVerseId = fullId;
                //                   _activeTooltipVerseId = fullId;
                //                 }
                //               });
                //             }
                //           },
                //       ),
                //     ],
                //   ),
                // ),
              ),
            ),

            // Tooltip for selected verse
            if (_activeTooltipVerseId == verseId)
              Positioned(
                right: 12,
                top: 0,
                child: Material(
                  color: settingsProvider.currentColor,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dialogTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy',
                          color: settingsProvider.fontColor,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: verseText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Verse copied to clipboard')),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.bookmark_add, size: 20),
                          tooltip: 'Highlight',
                          color: settingsProvider.fontColor,
                          onPressed: () {
                            _toggleVerse(
                              verseProvider,
                              widget.chapterId,
                              verseId,
                              verseText,
                              settingsProvider.currentTranslationId!,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.summarize, size: 20),
                          tooltip: 'Summarize',
                          color: settingsProvider.fontColor,
                          onPressed: () {
                            _summarizeVerse(context, verseText);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _summarizeVerse(BuildContext context, String verseText) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final hasApiKey = settingsProvider.geminiApiKey != null && settingsProvider.geminiApiKey!.isNotEmpty;

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

    // Construct a title from the verse ID if possible, otherwise generic
    // We can't access verseId easily here without passing it, but we can verify if selectedVerseId is set
    // Or just use "Verse Summary"
    String title = "Verse Summary";
    String reference = "";
    if (selectedVerseId != null) {
        // Cleaning up the ID for display
        // e.g., GEN.1.1 or just 1
        title = "Summary of $selectedVerseId";
        reference = " ($selectedVerseId)";
    }

    final prompt = "Summarize and interpret this Bible verse$reference:\n\n$verseText";

    showDialog(
      context: context,
      builder: (context) => StreamedSummaryModal(
        prompt: prompt, 
        title: title,
      ),
    );
  }
}
