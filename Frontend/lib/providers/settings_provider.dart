import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'church_provider.dart';
// add near the other imports
import '../shared/helpers/color_helper_stub.dart'
    if (dart.library.html) '../shared/helpers/color_helper_web.dart';

class SettingsProvider with ChangeNotifier {
  MaterialColor? _currentColor;
  MaterialColor? _highlightColor;
  ThemeMode _currentThemeMode;
  String? _currentTranslationId;
  String? _currentTranslationName;
  int? _userId;
  bool _isLoggedIn = false;
  bool _isPublicProfile = false;
  String? _username;
  String? _email;
  String? _avatarUrl;
  String? get username => _username;
  String? get email => _email;
  String? get avatarUrl => _avatarUrl;
  bool loading = false;

  // Gemini API settings
  String? _geminiApiKey;
  String _geminiModel = 'gemini-2.5-flash';

  String? get geminiApiKey => _geminiApiKey;
  String get geminiModel => _geminiModel;

  static const List<String> availableGeminiModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-3-flash-preview',
    'gemini-3-pro-preview',
  ];

  List<dynamic> _translations = [];

  final SettingsService settingsService = SettingsService();

  SettingsProvider()
      : _currentColor = null,
        _highlightColor = null,
        _userId = null,
        _currentThemeMode = ThemeMode.dark,
        _currentTranslationId = null,
        _currentTranslationName = null {}

  void _applyPrimaryToBody(Color c) {
    if (!kIsWeb) return;

    final hex = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    setBodyBackground(hex);
  }

  MaterialColor? get currentColor => _currentColor;
  Color get fontColor => getFontColor(_currentColor!);
  int? get userId => _userId;
  MaterialColor? get highlightColor => _highlightColor;
  ThemeMode get currentThemeMode => _currentThemeMode;
  String? get currentTranslationId => _currentTranslationId;
  String? get currentTranslationName => _currentTranslationName;
  bool get isLoggedIn => _isLoggedIn;
  bool get isPublicProfile => _isPublicProfile;

  List<dynamic> get translations => _translations;

  Color getFontColor(MaterialColor color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);

    if (brightness == Brightness.dark) {
      return Colors.white;
    } else {
      return Colors.black;
    }
  }

  void preloadUserAssets(BuildContext context, String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      precacheImage(NetworkImage(avatarUrl), context);
    }
  }

  Future<void> loadSettings() async {
    loading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _currentColor =
        _parseColor(prefs.getInt('primaryColor') ?? Colors.black.value);
    _highlightColor =
        _parseColor(prefs.getInt('highlightColor') ?? Colors.yellow.value);
    _currentThemeMode = await settingsService.loadThemeMode();

    var translation = await settingsService.loadTranslation();
    _currentTranslationId = translation['id'];
    _currentTranslationName = translation['name'];

    // Load Gemini settings
    _geminiApiKey = prefs.getString('geminiApiKey');
    _geminiModel = prefs.getString('geminiModel') ?? 'gemini-2.5-flash';

    final token = prefs.getString('token');
    final tokenExpiry = prefs.getInt('tokenExpiry') ?? 0;
    if (token != null && token.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > tokenExpiry) {
        logout();
      } else {
        try {
          await fetchUserSettingsFromBackend(token);
        } catch (err, stack) {
          debugPrint('🔥 Error: $err\n$stack');
          logout();
        }
      }
    } else {
      _isLoggedIn = false;
    }
    _applyPrimaryToBody(_currentColor!);

    loading = false;
    notifyListeners();
  }

  Future<void> fetchUserSettingsFromBackend(String token) async {
    final settings = await settingsService.fetchUserSettings(token);
    final prefs = await SharedPreferences.getInstance();

    if (settings == null || settings['user_id'] == null) {
      throw Exception('Invalid token or settings not found');
    }

    final userId = settings['user_id'];
    _userId = userId;
    final user = await http.get(
      Uri.parse('https://api.bybl.dev/api/user/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (user.statusCode != 200 && user.statusCode != 201) {
      throw Exception('Failed to fetch user details'); // <- important
    }

    _isLoggedIn = true;

    prefs.setString('user', user.body);

    final userData = json.decode(user.body);

    _username = userData['Username'];
    _email = userData['Email'];
    _avatarUrl = userData['AvatarURL'];

    _currentColor = _parseColor(settings['primary_color']);
    _highlightColor = _parseColor(settings['highlight_color']);
    _currentThemeMode =
        settings['dark_mode'] ? ThemeMode.dark : ThemeMode.light;
    _isPublicProfile = settings['public_profile'];
    _currentTranslationId =
        settings["translation_id"].toString().toLowerCase() == 'esv'
            ? 'bba9f40183526463-01'
            : settings['translation_id'];
    _currentTranslationName =
        settings["translation_name"].toString().toLowerCase() ==
                'english standard version'
            ? 'Berean Standard Version'
            : settings['translation_name'];

    notifyListeners();
  }

  Future<void> fetchTranslations() async {
    if (_translations.isEmpty) {
      List<dynamic> fetchedTranslations =
          await settingsService.fetchTranslations();

      Set<String> seenNames = {};
      _translations = [];

      List<dynamic> cleanedTranslations = [];

      for (dynamic translation in fetchedTranslations) {
        String name = (translation["name"] as String).toLowerCase();
        if (!seenNames.contains(name)) {
          seenNames.add(name);
          cleanedTranslations.add(translation);
        }
      }

// Add ESV and NIV manually
      cleanedTranslations.add({
        'id': 'bba9f40183526463-01',
        'name': 'Berean Standard Version',
      });
      cleanedTranslations.add({
        'id': 'NIV',
        'name': 'New International Version',
      });

      _translations = cleanedTranslations;

      // for (dynamic translation in fetchedTranslations) {
      //   String name = (translation["name"] as String).toLowerCase();
      //   if (!seenNames.contains(name)) {
      //     seenNames.add(name);
      //     fetchedTranslations.add(translation);
      //   }
      // }
      // _translations = fetchedTranslations;
      // _translations.add({
      //   'id': 'bba9f40183526463-01',
      //   'name': 'Berean Standard Version',
      // });
      // _translations.add({
      //   'id': 'NIV',
      //   'name': 'New International Version',
      // });
    }
    notifyListeners();
  }

  Future<void> updateUserSettingsOnBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      await settingsService.updateUserSettings(
        token,
        _currentColor!.value,
        _highlightColor!.value,
        _currentThemeMode == ThemeMode.dark,
        _isPublicProfile,
        _currentTranslationId!,
        _currentTranslationName!,
      );
    }
  }

  void updateColor(MaterialColor color) {
    _currentColor = color;
    settingsService.saveColor(color);
    _applyPrimaryToBody(_currentColor!);
    notifyListeners();
  }

  void updateHighlightColor(MaterialColor color) {
    _highlightColor = color;
    settingsService.saveHighlightColor(color);
    notifyListeners();
  }

  void updateThemeMode(ThemeMode themeMode) {
    _currentThemeMode = themeMode;
    settingsService.saveThemeMode(themeMode);
    notifyListeners();
  }

  Future<void> updateTranslation(
      String translationId, String translationName) async {
    _currentTranslationId = translationId;
    _currentTranslationName = translationName;
    await settingsService.saveTranslation(translationId, translationName);
    notifyListeners();
  }

  void togglePublicProfile(value) {
    _isPublicProfile = value;
    notifyListeners();
  }

  Future<void> updateGeminiApiKey(String? apiKey) async {
    _geminiApiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    if (apiKey != null && apiKey.isNotEmpty) {
      await prefs.setString('geminiApiKey', apiKey);
    } else {
      await prefs.remove('geminiApiKey');
    }
    notifyListeners();
  }

  Future<void> updateGeminiModel(String model) async {
    _geminiModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geminiModel', model);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _currentColor = _parseColor(Colors.black.value);
    _highlightColor = null;
    notifyListeners();
  }

  MaterialColor _parseColor(int colorValue) {
    return MaterialColor(colorValue, {
      50: Color(colorValue).withOpacity(0.1),
      100: Color(colorValue).withOpacity(0.2),
      200: Color(colorValue).withOpacity(0.3),
      300: Color(colorValue).withOpacity(0.4),
      400: Color(colorValue).withOpacity(0.5),
      500: Color(colorValue).withOpacity(0.6),
      600: Color(colorValue).withOpacity(0.7),
      700: Color(colorValue).withOpacity(0.8),
      800: Color(colorValue).withOpacity(0.9),
      900: Color(colorValue),
    });
  }
}
