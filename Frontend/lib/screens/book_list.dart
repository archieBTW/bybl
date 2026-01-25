import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bible_provider.dart';
import '../providers/settings_provider.dart';
import 'reader_screen.dart';

class BookListScreen extends StatelessWidget {
  const BookListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.black : Colors.white;

    return Selector<SettingsProvider, String?>(
      selector: (_, settingsProvider) => settingsProvider.currentTranslationId,
      builder: (context, translationId, _) {
        final bibleProvider =
            Provider.of<BibleProvider>(context, listen: false);

        return Consumer<BibleProvider>(
          builder: (context, bibleProvider, _) {
            if (bibleProvider.isLoadingBooks) {
              return const Center(child: CircularProgressIndicator());
            }

            if (bibleProvider.filteredBooks.isEmpty) {
              return const Center(child: Text('No books available'));
            }

            return ListView.builder(
                itemCount: bibleProvider.filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = bibleProvider.filteredBooks[index];
                  final bookId = book['id'];
                  final bookName = book['name'];

                  return Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    child: ExpansionTile(
                      collapsedShape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                        borderRadius: BorderRadius.zero,
                      ),
                      shape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                        borderRadius: BorderRadius.zero,
                      ),
                      backgroundColor: cardColor,
                      collapsedBackgroundColor: cardColor,
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      title: Text(
                        bookName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      onExpansionChanged: (expanded) {
                        if (expanded &&
                            bibleProvider.getChapters(bookId) == null) {
                          bibleProvider.fetchChapters(translationId!, bookId);
                        }
                      },
                      children: bibleProvider.getChapters(bookId) == null
                          ? const [
                              Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator())
                            ]
                          : [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 2,
                                  ),
                                  itemCount:
                                      bibleProvider.getChapters(bookId)!.length,
                                  itemBuilder: (context, chapterIndex) {
                                    final chapter = bibleProvider
                                        .getChapters(bookId)![chapterIndex];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReaderScreen(
                                                bookName: bookName,
                                                bookId: bookId,
                                                chapterId: chapter['id'],
                                                chapterName:
                                                    'Chapter ${chapter['number']}',
                                                chapterIds: bibleProvider
                                                    .getChapters(bookId)!
                                                    .map((c) => c['id'])
                                                    .toList(),
                                                chapterNames: bibleProvider
                                                    .getChapters(bookId)!
                                                    .map((c) =>
                                                        'Chapter ${c['number']}')
                                                    .toList(),
                                                //TODO: Properly handle errors here
                                                translationName: Provider.of<
                                                                SettingsProvider>(
                                                            context,
                                                            listen: false)
                                                        .currentTranslationName ??
                                                    '',
                                                translationId: Provider.of<
                                                                SettingsProvider>(
                                                            context,
                                                            listen: false)
                                                        .currentTranslationId ??
                                                    ''),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? const Color(0xFF111111)
                                              : const Color(0xFFF2F2F2),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          chapter['number'].toString(),
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
            },
          );
        },
      );
  }
}
