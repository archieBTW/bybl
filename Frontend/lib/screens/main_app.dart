import 'dart:async';

import 'package:TheWord/providers/bible_provider.dart';
import 'package:TheWord/screens/bookmarks_screen.dart';
import 'package:TheWord/screens/chat_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'book_list.dart';
import 'settings_screen.dart';
import '../shared/widgets/dynamic_search_bar.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({Key? key}) : super(key: key);

  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  bool isInited = false;
  bool isInitRunning = false;

  late SettingsProvider settingsProvider;
  late BibleProvider bibleProvider;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> init() async {
    setState(() {
      isInitRunning = true;
    });
    
    await settingsProvider.loadSettings();
    await bibleProvider.fetchBooks(
        settingsProvider.currentTranslationId ?? 'bba9f40183526463-01');
    
    setState(() {
      isInited = true;
      isInitRunning = false;
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await init();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _openEndDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _navigateToBookmarks() {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BookmarksScreen()),
    );
  }

  void _navigateToChat() {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen()),
    );
  }

  void _navigateToSettings() {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    settingsProvider = Provider.of<SettingsProvider>(context);
    bibleProvider = Provider.of<BibleProvider>(context);
    
    if (!isInited && !isInitRunning) {
      init();
    }

    MaterialColor? currentColor = settingsProvider.currentColor;
    Color? fontColor = settingsProvider.currentThemeMode == ThemeMode.dark
        ? Colors.white
        : Colors.black;
    if (currentColor != null) {
      fontColor = settingsProvider.getFontColor(currentColor);
    }

    final isDark = settingsProvider.currentThemeMode == ThemeMode.dark;
    final drawerBgColor = isDark ? Colors.black : Colors.white;
    final drawerTextColor = isDark ? Colors.white : Colors.black87;

    if (settingsProvider.loading ||
        (Provider.of<BibleProvider>(context).isLoadingBooks)) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: isDark ? Colors.black : Colors.white,
        endDrawer: Drawer(
          backgroundColor: drawerBgColor,
          width: 220,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.bookmarks_outlined, color: drawerTextColor),
                  title: Text(
                    'Bookmarks',
                    style: TextStyle(color: drawerTextColor),
                  ),
                  onTap: _navigateToBookmarks,
                ),
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: drawerTextColor),
                  title: Text(
                    'Ask Archie',
                    style: TextStyle(color: drawerTextColor),
                  ),
                  onTap: _navigateToChat,
                ),
                ListTile(
                  leading: Icon(Icons.settings_outlined, color: drawerTextColor),
                  title: Text(
                    'Settings',
                    style: TextStyle(color: drawerTextColor),
                  ),
                  onTap: _navigateToSettings,
                ),
              ],
            ),
          ),
        ),
        appBar: AppBar(
          toolbarHeight: 56,
          backgroundColor: currentColor ?? (isDark ? Colors.black : Colors.white),
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              // Cross icon on the left
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Image.asset(
                  'assets/icon/cross_nav.png',
                  width: 36,
                  height: 36,
                  color: fontColor,
                ),
              ),
              const SizedBox(width: 8),
              // Search bar
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: DynamicSearchBar(
                    searchType: SearchType.BibleBooks,
                    fontColor: fontColor,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Hamburger menu on the right
            IconButton(
              icon: Icon(Icons.menu, color: fontColor),
              onPressed: _openEndDrawer,
            ),
          ],
        ),
        // Bible content
        body: const BookListScreen(),
      ),
    );
  }
}

class ResponsiveImage extends StatelessWidget {
  final String asset;
  final double max;
  const ResponsiveImage(this.asset, {this.max = 400});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final target = w < max ? w : max;
    return Image.asset(asset, width: target);
  }
}

class FixedAssetIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  const FixedAssetIcon(
    this.asset, {
    this.size = 60,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      color: color,
      fit: BoxFit.contain,
    );
  }
}
