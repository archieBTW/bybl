import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'church_provider.dart';
// add near the other imports
import '../shared/helpers/color_helper_stub.dart'
    if (dart.library.html) '../shared/helpers/color_helper_web.dart';
import '../models/user_settings_enums.dart';

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

  // Reader Typography Settings
  double _readerFontSize = 18.0;
  double _readerLineHeight = 1.55;
  bool _readerUseSerif = false;

  double get readerFontSize => _readerFontSize;
  double get readerLineHeight => _readerLineHeight;
  bool get readerUseSerif => _readerUseSerif;

  // Gemini API settings
  String? _geminiApiKey;
  String _geminiModel = 'gemini-3.8-flash';

  // AI Identity Settings
  Denomination _denomination = Denomination.nondenominational;
  AIContext _aiContext = AIContext.devotional;
  String? _aiUserName;

  String? get geminiApiKey => _geminiApiKey;
  String get geminiModel => _geminiModel;
  Denomination get denomination => _denomination;
  AIContext get aiContext => _aiContext;
  String? get aiUserName => _aiUserName;

  static const List<String> availableGeminiModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
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

    _readerFontSize = prefs.getDouble('readerFontSize') ?? 18.0;
    _readerLineHeight = prefs.getDouble('readerLineHeight') ?? 1.55;
    _readerUseSerif = prefs.getBool('readerUseSerif') ?? false;

    var translation = await settingsService.loadTranslation();
    _currentTranslationId = translation['id'];
    _currentTranslationName = translation['name'];

    // Load Gemini settings
    _geminiApiKey = prefs.getString('geminiApiKey');
    _geminiModel = prefs.getString('geminiModel') ?? 'gemini-3.8-flash';
    if (_geminiModel.contains('3.1') || _geminiModel.contains('1.5')) {
      _geminiModel = 'gemini-3.8-flash';
      await prefs.setString('geminiModel', _geminiModel);
    }

    _denomination = await settingsService.loadDenomination();
    _aiContext = await settingsService.loadAIContext();
    _aiUserName = await settingsService.loadAIUserName();

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
    final rawId = settings["translation_id"]?.toString() ?? '';
    final isInvalidOrLegacy = rawId.toLowerCase() == 'esv' ||
        rawId.toLowerCase() == 'niv' ||
        rawId == '317e03834065a236-01';
    _currentTranslationId =
        isInvalidOrLegacy ? 'bba9f40183526463-01' : settings['translation_id'];
    _currentTranslationName = isInvalidOrLegacy ||
            settings["translation_name"].toString().toLowerCase() ==
                'english standard version' ||
            settings["translation_name"].toString().toLowerCase() ==
                'berean standard version'
        ? 'Berean Standard Bible'
        : settings['translation_name'];

    notifyListeners();
  }

  Future<void> fetchTranslations() async {
    if (_translations.isEmpty) {
      List<dynamic> fetchedTranslations =
          await settingsService.fetchTranslations();

      Map<String, int> seenNames = {};
      List<dynamic> cleanedTranslations = [];

      for (dynamic translation in fetchedTranslations) {
        final id = translation["id"]?.toString() ?? '';
        if (id.toUpperCase() == 'ESV' || id.toUpperCase() == 'NIV') {
          continue;
        }
        String name = (translation["name"] as String).toLowerCase();
        if (!seenNames.containsKey(name)) {
          seenNames[name] = cleanedTranslations.length;
          cleanedTranslations.add(translation);
        } else if (id == 'bba9f40183526463-01') {
          cleanedTranslations[seenNames[name]!] = translation;
        }
      }

      _translations = cleanedTranslations;
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

  Future<void> updateReaderTypography({
    double? fontSize,
    double? lineHeight,
    bool? useSerif,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (fontSize != null) {
      _readerFontSize = fontSize.clamp(14.0, 28.0);
      await prefs.setDouble('readerFontSize', _readerFontSize);
    }
    if (lineHeight != null) {
      _readerLineHeight = lineHeight.clamp(1.2, 2.2);
      await prefs.setDouble('readerLineHeight', _readerLineHeight);
    }
    if (useSerif != null) {
      _readerUseSerif = useSerif;
      await prefs.setBool('readerUseSerif', _readerUseSerif);
    }
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

  Future<void> updateDenomination(Denomination denom) async {
    _denomination = denom;
    await settingsService.saveDenomination(denom);
    notifyListeners();
  }

  Future<void> updateAIContext(AIContext ctx) async {
    _aiContext = ctx;
    await settingsService.saveAIContext(ctx);
    notifyListeners();
  }

  Future<void> updateAIUserName(String name) async {
    _aiUserName = name;
    await settingsService.saveAIUserName(name);
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
