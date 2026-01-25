import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/verse_provider.dart';
import '../shared/widgets/verse_card.dart';
import 'comment_screen.dart';

class PublicVersesScreen extends StatefulWidget {
  const PublicVersesScreen({Key? key}) : super(key: key);

  @override
  State<PublicVersesScreen> createState() => _PublicVersesScreenState();
}

class _PublicVersesScreenState extends State<PublicVersesScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();
  bool _initialLoadRequested = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Make sure we call the first fetch only once.
    if (!_initialLoadRequested) {
      _initialLoadRequested = true;
      Future.microtask(() {
        if (!mounted) return;
        context
            .read<VerseProvider>()
            .fetchPublicVerses(reset: true, init: true);
      });
    }
  }

  void _handleScroll() {
    final provider = context.read<VerseProvider>();

    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
        !provider.isLoading) {
      provider.fetchPublicVerses(); // next page
    }
  }

  Future<void> _refresh() => context
      .read<VerseProvider>()
      .fetchPublicVerses(reset: true, silent: true);

  @override
  Widget build(BuildContext context) {
    super.build(context); // important for AutomaticKeepAliveClientMixin

    return Consumer<VerseProvider>(
      builder: (_, vp, __) {
        final verses = vp.publicVerses;
        final isBusy = vp.isLoading || vp.isIniting;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: isBusy && verses.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : verses.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 200),
                          Center(child: Text('No public verses')),
                        ],
                      )
                    : ListView.builder(
                        controller: _scroll,
                        itemCount: verses.length +
                            (vp.isLoading ? 1 : 0), // add a tail spinner
                        itemBuilder: (ctx, idx) {
                          // tail-spinner
                          if (idx == verses.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                  child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator())),
                            );
                          }

                          final id = vp.publicVerses[idx]['UserVerseID'] as int;
                          final currentVerse =
                              vp.publicVerses[idx]; // 👈 ALWAYS FRESH
                          return VerseCard(
                              verseId: currentVerse['VerseID'],
                              verseContent: currentVerse['Content'],
                              username: currentVerse['Username'] ?? '',
                              note: currentVerse['Note'] ?? '',
                              isPublished: true,
                              likesCount:
                                  currentVerse['likes_count'], // 👈 not stale
                              commentCount: currentVerse['comment_count'] ?? 0,
                              onLike: () => vp.toggleLike(id),
                              onComment: () => _openComments(currentVerse),
                              isSaved: false,
                              onSaveNote: (_) {}

                              // final v = verses[idx];
                              // print(v);
                              // final id = v['UserVerseID'] as int;

                              // return VerseCard(
                              //   verseId: v['VerseID'],
                              //   verseContent: v['Content'],
                              //   username: v['username'] ?? '',
                              //   note: v['Note'] ?? '',
                              //   isPublished: true,
                              //   likesCount: v['likes_count'],
                              //   commentCount: v['comment_count'] ?? 0,
                              //   onLike: () => vp.toggleLike(id),
                              //   onComment: () => _openComments(v),
                              //   isSaved: false,
                              //   onSaveNote: (_) {},
                              );
                        },
                      ),
          ),
        );
      },
    );
  }

  void _openComments(dynamic verse) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommentsScreen(verse: verse)),
    );
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
