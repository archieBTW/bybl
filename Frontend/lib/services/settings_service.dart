import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsService {
  // final String apiKey = dotenv.env['BIBLE_KEY'] ?? '';
  Future<Map<String, dynamic>?> fetchUserSettings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.bybl.dev/api/user/settings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.trim().toLowerCase().startsWith('<!doctype html>')) {
          return null;
        }

        try {
          return json.decode(response.body);
        } catch (e, stack) {
          debugPrint('🔥 Error: $e\n$stack');
          return null;
        }
      } else {
        return null;
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      return null;
    }
  }

  Future<void> updateUserSettings(
    String token,
    int primaryColor,
    int highlightColor,
    bool darkMode,
    bool publicProfile,
    String translationId,
    String translationName,
  ) async {
    var payload = json.encode({
      'primary_color': primaryColor,
      'highlight_color': highlightColor,
      'dark_mode': darkMode,
      'public_profile': publicProfile,
      'translation_id': translationId,
      'translation_name': translationName,
    });
    final response =
        await http.post(Uri.parse('https://api.bybl.dev/api/user/settings'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: payload);

    if (response.statusCode != 200) {
      throw Exception('Failed to update user settings: ${response.body}');
    }
  }

  Future<void> saveColor(MaterialColor color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', color.value);
  }

  Future<void> saveHighlightColor(MaterialColor color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highlightColor', color.value);
  }

  Future<MaterialColor> loadColor() async {
    final prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('primaryColor');
    return _parseColor(colorValue ?? 0xFF000000);
  }

  Future<MaterialColor> loadHighlightColor() async {
    final prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt('highlightColor');
    return _parseColor(colorValue ?? 0xFFFF0000);
  }

  Future<void> saveThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', themeMode.toString());
  }

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    String? themeModeString = prefs.getString('themeMode');
    return themeModeString != null
        ? ThemeMode.values
            .firstWhere((mode) => mode.toString() == themeModeString)
        : ThemeMode.dark;
  }

  Future<void> saveTranslation(
      String translationId, String translationName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translationId', translationId);
    await prefs.setString('translationName', translationName);
  }

  Future<void> saveDenomination(Denomination denomination) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('denomination', denomination.name);
  }

  Future<Denomination> loadDenomination() async {
    final prefs = await SharedPreferences.getInstance();
    String? denominationString = prefs.getString('denomination');
    if (denominationString != null) {
      return Denomination.values.firstWhere(
        (e) => e.name == denominationString,
        orElse: () => Denomination.other,
      );
    }
    return Denomination.nondenominational; // Default
  }

  Future<void> saveAIContext(AIContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aiContext', context.name);
  }

  Future<AIContext> loadAIContext() async {
    final prefs = await SharedPreferences.getInstance();
    String? contextString = prefs.getString('aiContext');
    if (contextString != null) {
      return AIContext.values.firstWhere(
        (e) => e.name == contextString,
        orElse: () => AIContext.devotional,
      );
    }
    return AIContext.devotional; // Default
  }

  Future<Map<String, String>> loadTranslation() async {
    final prefs = await SharedPreferences.getInstance();
    String? translationId = prefs.getString('translationId');
    String? translationName = prefs.getString('translationName');

    return {
      'id': translationId ?? 'bba9f40183526463-01',
      'name': translationName ?? 'Berean Standard Version',
    };
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

  Future<List<dynamic>> fetchTranslations() async {
    final response = await http.get(
      Uri.parse('https://api.bybl.dev/api/bible/translations'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'];
    } else {
      throw Exception('Failed to load translations');
    }
  }

  Future<void> handleAvatarUpload({
    required BuildContext context,
    required String uploadUrl,
    required VoidCallback onSuccess,
  }) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in')),
      );
      return;
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.headers['Authorization'] = 'Bearer $token';

      if (kIsWeb) {
        // WEB: Upload bytes directly
        final bytes = await pickedFile.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: pickedFile.name,
        );
        request.files.add(multipartFile);
      } else {
        // MOBILE: Upload from file path
        final multipartFile = await http.MultipartFile.fromPath(
          'avatar',
          pickedFile.path,
        );
        request.files.add(multipartFile);
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated!')),
        );
        onSuccess(); // Refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.reasonPhrase}')),
        );
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
