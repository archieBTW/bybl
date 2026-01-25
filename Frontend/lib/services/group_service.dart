import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/small_group.dart';
import '../models/event.dart';
import '../models/message.dart';
import '../models/prayer_request.dart';
import '../models/group_member.dart';

class GroupService {
  final String _baseUrl = 'https://api.bybl.dev/api';

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<SmallGroup> getGroup(int groupId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.get(
      Uri.parse('$_baseUrl/groups/$groupId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      SmallGroup group = SmallGroup.fromJson(jsonDecode(response.body));
      return group;
    } else {
      throw Exception('Failed to load group');
    }
  }

  Future<List<ChurchEvent>> getGroupEvents(int groupId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.get(
      Uri.parse('$_baseUrl/groups/$groupId/events'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => ChurchEvent.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load group events');
    }
  }

  Future<List<Message>> getGroupMessages(int groupId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.get(
      Uri.parse('$_baseUrl/groups/$groupId/messages'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Message.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load group messages');
    }
  }

  Future<List<PrayerRequest>> getGroupPrayerRequests(int groupId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.get(
      Uri.parse('$_baseUrl/groups/$groupId/prayer-requests'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => PrayerRequest.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load prayer requests');
    }
  }

  Future<List<GroupMember>> getGroupMembers(int groupId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.get(
      Uri.parse('$_baseUrl/groups/$groupId/members'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => GroupMember.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load group members');
    }
  }

  Future<void> joinGroup(int groupId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.post(
      Uri.parse('$_baseUrl/groups/$groupId/join'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to join group');
    }
  }

  Future<void> leaveGroup(int groupId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.post(
      Uri.parse('$_baseUrl/groups/$groupId/leave'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to leave group');
    }
  }

  Future<void> createGroup(int churchId, String name, String? description,
      String? meetingDay, String? meetingTime, String? meetingLocation) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.post(
      Uri.parse('$_baseUrl/groups'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'church_id': churchId,
        'name': name,
        'description': description,
        'meeting_day': meetingDay,
        'meeting_time': meetingTime,
        'meeting_location': meetingLocation,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create group');
    }
  }
}
