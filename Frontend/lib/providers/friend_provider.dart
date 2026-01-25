import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart'; // <-- needed for precacheImage

import '../models/friend.dart';

class FriendProvider with ChangeNotifier {
  List<Friend> friends = [];
  List<Friend> suggestedFriends = [];

  bool isLoading = true;

  reset() {
    friends = [];
    suggestedFriends = [];
  }

  Future<void> preloadAvatars(List<Friend> list, BuildContext context) async {
    await Future.wait(list.map((friend) async {
      if (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty) {
        try {
          await precacheImage(
            NetworkImage(
                'https://api.bybl.dev/api/avatar?type=user&id=${friend.userID}'),
            context,
          );
        } catch (e, stack) {
          debugPrint('🔥 Error: $e\n$stack');
        }
      }
    }));
  }

  Future<void> fetchFriends({BuildContext? context}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        print('No token found for fetchFriends');
        return;
      }

      isLoading = true;
      notifyListeners();

      final response = await http.get(
        Uri.parse('https://api.bybl.dev/api/friends'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.trim().toLowerCase().startsWith('<!doctype html>')) {
          friends = [];
          return;
        }

        var responseBody = json.decode(response.body);
        if (responseBody != null) {
          friends = (responseBody as List<dynamic>)
              .map<Friend>((data) => Friend.fromJson(data))
              .toList();

          if (context != null) {
            await preloadAvatars(friends, context);
          }
        }
      } else {
        friends = [];
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      friends = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSuggestedFriends({BuildContext? context}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        return;
      }

      isLoading = true;
      notifyListeners();

      final response = await http.get(
        Uri.parse('https://api.bybl.dev/api/friends/suggested'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.trim().toLowerCase().startsWith('<!doctype html>')) {
          suggestedFriends = [];
          return;
        }

        var responseBody = json.decode(response.body);
        if (responseBody != null) {
          suggestedFriends = (responseBody as List<dynamic>)
              .map<Friend>((data) => Friend.fromJson(data))
              .toList();

          if (context != null) {
            await preloadAvatars(suggestedFriends, context);
          }
        }
      } else {
        suggestedFriends = [];
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      suggestedFriends = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeFriend(int friendId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.delete(
      Uri.parse('https://api.bybl.dev/api/friends/$friendId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      friends.removeWhere((friend) => friend.userID == friendId);
      await fetchFriends();
      await fetchSuggestedFriends();
      notifyListeners();
    }
  }

  Future<void> searchFriends(String query, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return;
    if (query.isEmpty) fetchSuggestedFriends(context: context);

    isLoading = true;
    notifyListeners();

    final response = await http.get(
      Uri.parse('https://api.bybl.dev/api/friends/search?q=$query'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      var responseBody = json.decode(response.body);
      if (responseBody != null) {
        suggestedFriends = (responseBody as List<dynamic>)
            .map<Friend>((data) => Friend.fromJson(data))
            .toList();

        await preloadAvatars(suggestedFriends, context);
      } else {
        suggestedFriends = [];
      }
    } else {
      print('Failed to search friends: ${response.body}');
    }

    isLoading = false;
    notifyListeners();
  }
}
