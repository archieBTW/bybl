import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class StreakService {
  final String baseUrl;
  final String authToken;

  StreakService({required this.baseUrl, required this.authToken});

  Future<void> logReadingToday() async {
    final res = await http.post(
      Uri.parse('$baseUrl/reading/log'),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to log reading');
    }
  }

  Future<Map<String, dynamic>> getStreak() async {
    final res = await http.get(
      Uri.parse('$baseUrl/reading/streak'),
      headers: {'Authorization': 'Bearer $authToken'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load streak');
    }

    return json.decode(res.body);
  }
}
