import 'package:TheWord/providers/bible_provider.dart';
import 'package:TheWord/providers/settings_provider.dart';
import 'package:TheWord/providers/verse_provider.dart';
import 'package:TheWord/screens/main_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => BibleProvider()),
        ChangeNotifierProvider(create: (_) => VerseProvider()),
      ],
      child: ByblApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ByblApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        BibleProvider bibleProvider =
            Provider.of<BibleProvider>(context, listen: false);
        bibleProvider.fetchTranslations();

        // Initialize verse provider for local highlights
        VerseProvider verseProvider =
            Provider.of<VerseProvider>(context, listen: false);
        verseProvider.init();

        var themeFontColor = settings.currentThemeMode == ThemeMode.dark
            ? Colors.white
            : Colors.black;
        if (settings.currentColor != null)
          themeFontColor = settings.getFontColor(settings.currentColor!);

        return MaterialApp(
          initialRoute: '/main',
          routes: {
            '/main': (context) => const MainAppScreen(),
          },
          title: 'bybl',
          themeMode: settings.currentThemeMode,

          darkTheme: ThemeData(
            fontFamily: 'NotoSans',
            brightness: Brightness.dark,
            primarySwatch: settings.currentColor,
            scaffoldBackgroundColor: Colors.black,
            cardColor: Color(0xFF090909),
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.white),
            ),
            appBarTheme: AppBarTheme(
              foregroundColor: themeFontColor,
              backgroundColor: settings.currentColor,
              titleTextStyle: TextStyle(color: themeFontColor, fontSize: 20),
            ),
            bottomAppBarTheme: BottomAppBarThemeData(
              surfaceTintColor: themeFontColor,
              color: settings.currentColor,
            ),
            listTileTheme: const ListTileThemeData(
              textColor: Colors.white,
              iconColor: Colors.white,
            ),
          ),
          theme: ThemeData(
            fontFamily: 'NotoSans',
            highlightColor: settings.highlightColor,
            brightness: Brightness.light,
            cardColor: Colors.white,
            primarySwatch: settings.currentColor,
            scaffoldBackgroundColor: Colors.white,
            textTheme: const TextTheme(
              bodyMedium: TextStyle(color: Colors.black),
            ),
            appBarTheme: AppBarTheme(
              foregroundColor: themeFontColor,
              backgroundColor: settings.currentColor,
              titleTextStyle: TextStyle(color: themeFontColor, fontSize: 20),
            ),
            bottomAppBarTheme: BottomAppBarThemeData(
              surfaceTintColor: themeFontColor,
              color: settings.currentColor,
            ),
            listTileTheme: const ListTileThemeData(
              textColor: Colors.black,
              iconColor: Colors.black,
            ),
          ),
        );
      },
    );
  }
}

MaterialColor createMaterialColor(Color color) {
  final strengths = <double>[.05];
  final swatch = <int, Color>{};

  final r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}
