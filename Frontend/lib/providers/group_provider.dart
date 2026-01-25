import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/group_service.dart';
import '../models/small_group.dart' as group_model;
import '../models/event.dart' as church_event_model;
import '../models/message.dart' as message_model;
import '../models/prayer_request.dart' as prayer_model;
import '../models/group_member.dart' as member_model;

class GroupProvider with ChangeNotifier {
  final String baseUrl = 'https://api.bybl.dev/api';
  final GroupService _groupService = GroupService();

  group_model.SmallGroup? _currentGroup;
  List<church_event_model.ChurchEvent> _events = [];
  List<message_model.Message> _messages = [];
  List<prayer_model.PrayerRequest> _prayerRequests = [];
  List<member_model.GroupMember> _members = [];
  bool _isLoading = false;
  String? _token;

  group_model.SmallGroup? get currentGroup => _currentGroup;
  List<church_event_model.ChurchEvent> get events => _events;
  List<message_model.Message> get messages => _messages;
  List<prayer_model.PrayerRequest> get prayerRequests => _prayerRequests;
  List<member_model.GroupMember> get members => _members;
  bool get isLoading => _isLoading;

  GroupProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<group_model.SmallGroup?> getGroup(int groupId) async {
    if (_token == null) {
      await _loadToken();
      if (_token == null) return null;
    }

    _setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentGroup = group_model.SmallGroup.fromJson(data);
        notifyListeners();
        return _currentGroup;
      } else {
        print('Failed to get group: ${response.statusCode}');
        return null;
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<church_event_model.ChurchEvent>> getGroupEvents(
      int groupId) async {
    if (_token == null) {
      await _loadToken();
      if (_token == null) return [];
    }

    _setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/events'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _events = data
            .map((item) => church_event_model.ChurchEvent.fromJson(item))
            .toList();
        notifyListeners();
        return _events;
      } else {
        print('Failed to get group events: ${response.statusCode}');
        return [];
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Future<List<message_model.Message>> getGroupMessages(int groupId) async {
    if (_token == null) {
      await _loadToken();
      if (_token == null) return [];
    }

    _setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/messages'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _messages =
            data.map((item) => message_model.Message.fromJson(item)).toList();
        notifyListeners();
        return _messages;
      } else {
        print('Failed to get group messages: ${response.statusCode}');
        return [];
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Future<List<prayer_model.PrayerRequest>> getGroupPrayerRequests(
      int groupId) async {
    if (_token == null) {
      await _loadToken();
      if (_token == null) return [];
    }

    _setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/prayers'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _prayerRequests = data
            .map((item) => prayer_model.PrayerRequest.fromJson(item))
            .toList();
        notifyListeners();
        return _prayerRequests;
      } else {
        print('Failed to get group prayer requests: ${response.statusCode}');
        return [];
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Future<List<member_model.GroupMember>> getGroupMembers(int groupId) async {
    if (_token == null) {
      await _loadToken();
      if (_token == null) return [];
    }

    _setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups/$groupId/members'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _members = data
            .map((item) => member_model.GroupMember.fromJson(item))
            .toList();
        notifyListeners();
        return _members;
      } else {
        print('Failed to get group members: ${response.statusCode}');
        return [];
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> joinGroup(int groupId) async {
    if (_token == null) {
      await _loadToken();
      if (_token == null) return false;
    }

    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/join'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        await getGroup(groupId);
        notifyListeners();
        return true;
      } else {
        print('Failed to join group: ${response.statusCode}');
        return false;
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> leaveGroup(int groupId) async {
    if (_token == null) {
      await _loadToken();
      if (_token == null) return false;
    }

    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/leave'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        _currentGroup = null;
        _events = [];
        _messages = [];
        _prayerRequests = [];
        _members = [];
        notifyListeners();
        return true;
      } else {
        print('Failed to leave group: ${response.statusCode}');
        return false;
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<group_model.SmallGroup?> createGroup(
    int churchId,
    String name, {
    String? description,
    String? meetingDay,
    String? meetingTime,
    String? meetingLocation,
  }) async {
    if (_token == null) {
      await _loadToken();
      if (_token == null) return null;
    }

    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'church_id': churchId,
          'name': name,
          'description': description,
          'meeting_day': meetingDay,
          'meeting_time': meetingTime,
          'meeting_location': meetingLocation,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentGroup = group_model.SmallGroup.fromJson(data);
        notifyListeners();
        return _currentGroup;
      } else {
        print('Failed to create group: ${response.statusCode}');
        return null;
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void reset() {
    _currentGroup = null;
    _events = [];
    _messages = [];
    _prayerRequests = [];
    _members = [];
    _token = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> createMessage(int groupId, String title, String content) async {
    await _ensureTokenLoaded();
    _setLoading(true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/messages'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'title': title, 'content': content}),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final newMsg = message_model.Message.fromJson(json.decode(res.body));
        _messages.insert(0, newMsg); // local optimistic update
        notifyListeners();
      } else {
        throw Exception('Failed to create message');
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> createEvent(
    int groupId,
    String title,
    String description,
    DateTime startTime,
    DateTime endTime,
    String location,
  ) async {
    await _ensureTokenLoaded();
    _setLoading(true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/events/create'),
        headers: {
          'Authorization': 'Bearer $_token',
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

      if (res.statusCode == 201 || res.statusCode == 200) {
        final newEvent =
            church_event_model.ChurchEvent.fromJson(json.decode(res.body));
        _events.insert(0, newEvent);
        notifyListeners();
      } else {
        throw Exception('Failed to create event');
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> submitPrayerRequest(
      int groupId, String content, bool isAnonymous) async {
    await _ensureTokenLoaded();
    _setLoading(true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/groups/$groupId/prayers'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'content': content,
          'isAnonymous': isAnonymous,
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final newRequest =
            prayer_model.PrayerRequest.fromJson(json.decode(res.body));
        _prayerRequests.insert(0, newRequest);
        notifyListeners();
      } else {
        throw Exception('Failed to submit prayer request');
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

// convenience
  Future<void> _ensureTokenLoaded() async {
    if (_token == null) await _loadToken();
  }
}
