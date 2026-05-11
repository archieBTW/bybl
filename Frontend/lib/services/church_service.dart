import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:TheWord/models/church.dart';
import 'package:TheWord/models/small_group.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ChurchService {
  final String baseUrl = 'https://api.bybl.dev';

  Future<List<Church>> getChurches() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/churches'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> data = json.decode(response.body);

        return data.map((json) => Church.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load churches: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<Church> getChurchDetails(int churchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/churches/$churchId'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Church.fromJson(data);
      } else {
        throw Exception(
            'Failed to load church details: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<SmallGroup> getGroupDetails(int groupId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/groups/$groupId'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print(data); // good to keep for debugging

        // Merge group data with isMember and isLeader from root
        final groupData = Map<String, dynamic>.from(data['group']);
        groupData['is_member'] = data['isMember'];
        groupData['is_leader'] = data['isLeader'];
        groupData['messages'] = data['messages'];
        groupData['events'] = data['events'];
        groupData['prayerRequests'] = data['prayerRequests'];

        return SmallGroup.fromJson(groupData);
      } else {
        throw Exception('Failed to load group details: ${response.statusCode}');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<void> joinChurch(int churchId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/churches/$churchId/join'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to join church: ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<void> leaveChurch() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/churches/leave'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to leave church: ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final tokenExpiry = prefs.getInt('tokenExpiry') ?? 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (token != null && now > tokenExpiry) {
      await prefs.remove('token');
      await prefs.remove('tokenExpiry');
      return null;
    }

    return token;
  }

  Future<void> createPost(int churchId, String title, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/churches/$churchId/messages'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': title,
          'content': content,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create post: ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<void> createEvent(
    int churchId,
    String title,
    String description,
    DateTime startTime,
    DateTime endTime,
    String location,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/churches/$churchId/events'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': title,
          'description': description,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'location': location,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create event: ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<void> createGroup(
    int churchId,
    String name,
    String description,
    String meetingDay,
    String meetingTime,
    String meetingLocation,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/churches/$churchId/groups'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'description': description,
          'meeting_day': meetingDay,
          'meeting_time': meetingTime,
          'meeting_location': meetingLocation,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to create group: ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }
}
