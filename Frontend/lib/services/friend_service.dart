import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/friend.dart';

class FriendService {
  final String _baseUrl = 'https://api.bybl.dev/api';

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<Friend>> getFriends() async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.get(
      Uri.parse('$_baseUrl/user/me/friends'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Friend.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load friends');
    }
  }

  Future<void> addFriend(int friendId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.post(
      Uri.parse('$_baseUrl/user/$friendId/add-friend'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send friend request');
    }
  }

  Future<void> removeFriend(int friendId) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.post(
      Uri.parse('$_baseUrl/user/$friendId/remove-friend'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove friend');
    }
  }

  Future<void> respondToFriendRequest(int friendId, bool accept) async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.post(
      Uri.parse('$_baseUrl/user/$friendId/respond-friend-request'),
      headers: {'Authorization': 'Bearer $token'},
      body: jsonEncode({'accept': accept}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to respond to friend request');
    }
  }

  Future<List<Friend>> getFriendRequests() async {
    String? token = await _getToken();
    if (token == null) throw Exception("Token not found");

    final response = await http.get(
      Uri.parse('$_baseUrl/user/me/friend-requests'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Friend.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load friend requests');
    }
  }
}
