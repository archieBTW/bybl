import 'package:TheWord/models/prayer_request.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:TheWord/models/church.dart';
import 'package:TheWord/models/small_group.dart';
import 'package:TheWord/services/church_service.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

class ChurchProvider with ChangeNotifier {
  final ChurchService _churchService = ChurchService();
  List<Church> _churches = [];
  Church? _selectedChurch;
  SmallGroup? _selectedGroup;
  bool _isLoading = false;
  String? _userChurchName;

  bool _isAdmin = false;
  int? _userChurchId;

  List<Church> get churches => _churches;
  Church? get selectedChurch => _selectedChurch;
  SmallGroup? get selectedGroup => _selectedGroup;
  bool get isLoading => _isLoading;
  bool get isMember => _userChurchId != null && _userChurchId != 0;
  bool get isAdmin => _isAdmin;
  int? get userChurchId => _userChurchId;
  String? get userChurchName => _userChurchName;

  Future<void> fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('user');
    final userData = json.decode(user!);
    _isAdmin = userData['IsAdmin'] ?? false;
    _userChurchId = userData['ChurchID'];
  }

  Future<void> fetchChurches({bool notify = true}) async {
    _isLoading = true;
    if (notify) {
      notifyListeners();
    }

    try {
      _churches = await _churchService.getChurches();
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
    } finally {
      _isLoading = false;
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<void> selectChurch(int churchID) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedChurch = await _churchService.getChurchDetails(churchID);
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> preloadAvatars(BuildContext context) async {
    await Future.wait(_churches.map((church) async {
      if (church.avatarUrl != null && church.avatarUrl!.isNotEmpty) {
        try {
          await precacheImage(
            NetworkImage(
                'https://api.bybl.dev/api/avatar?type=church&id=${church.churchID}'),
            context,
          );
        } catch (e, stack) {
          debugPrint('🔥 Error: $e\n$stack');
        }
      }
    }));
  }

  Future<void> selectGroup(int groupID) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedGroup = await _churchService.getGroupDetails(groupID);
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedChurch() {
    _selectedChurch = null;
    notifyListeners();
  }

  void clearSelectedGroup() {
    _selectedGroup = null;
    notifyListeners();
  }

  Future<void> joinChurch(int churchId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _churchService.joinChurch(churchId);
      _userChurchId = churchId;
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> leaveChurch() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _churchService.leaveChurch();
      _userChurchId = null;
      _userChurchName = null;
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearUserChurchStatus() {
    _userChurchId = null;
    _userChurchName = null;
    notifyListeners();
  }

  Future<void> createPost(int churchId, String title, String content) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _churchService.createPost(churchId, title, content);

      await selectChurch(churchId);
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _isLoading = true;
    notifyListeners();

    try {
      await _churchService.createEvent(
        churchId,
        title,
        description,
        startTime,
        endTime,
        location,
      );

      await selectChurch(churchId);
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _isLoading = true;
    notifyListeners();

    try {
      await _churchService.createGroup(
        churchId,
        name,
        description,
        meetingDay,
        meetingTime,
        meetingLocation,
      );
      // Refresh church details to get the new group
      await selectChurch(churchId);
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() async {
    _churches = [];
    _selectedChurch = null;
    _selectedGroup = null;
    _isLoading = false;
    _isAdmin = false;
    _userChurchId = null;
    _userChurchName = null;

    notifyListeners();
  }

  Future<void> submitPrayerRequest(
      int churchId, String content, bool isAnonymous) async {
    final url = Uri.parse(
        'https://api.bybl.dev/api/churches/$churchId/prayers'); // Replace with actual endpoint

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'content': content,
          'isAnonymous': isAnonymous,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        final newRequest = PrayerRequest.fromJson(data);

        // Optionally update local list
        _selectedChurch?.prayerRequests.insert(0, newRequest);
        notifyListeners();
      } else {
        throw Exception('Failed to submit prayer request');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
    }
  }

  Future<void> deleteChurchMessage(int messageId) async {
    final url =
        Uri.parse('https://api.bybl.dev/api/churches/messages/$messageId');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _selectedChurch?.messages.removeWhere((m) => m.messageId == messageId);
        notifyListeners();
      } else {
        throw Exception('Failed to delete church message');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<void> deleteSmallGroup(int groupId) async {
    final url = Uri.parse('https://api.bybl.dev/api/groups/$groupId');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _selectedChurch?.smallGroups.removeWhere((g) => g.groupId == groupId);
        notifyListeners();
      } else {
        throw Exception('Failed to delete small group');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<void> deleteChurchPrayerRequest(int requestId) async {
    final url =
        Uri.parse('https://api.bybl.dev/api/churches/prayers/$requestId');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _selectedChurch?.prayerRequests
            .removeWhere((r) => r.requestId == requestId);
        notifyListeners();
      } else {
        throw Exception('Failed to delete prayer request');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }

  Future<void> deleteChurchEvent(int eventId) async {
    final url = Uri.parse('https://api.bybl.dev/api/events/$eventId');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _selectedChurch?.events.removeWhere((e) => e.eventId == eventId);
        notifyListeners();
      } else {
        throw Exception('Failed to delete church event');
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      rethrow;
    }
  }
}
