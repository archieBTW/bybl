import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/friend.dart';
import '../models/comment_notification.dart'; // Import the new model

class NotificationProvider extends ChangeNotifier {
  List<Friend> friendRequests = [];
  List<int> sentFriendRequests = [];
  List<CommentNotification> commentNotifications =
      []; // New list for comment notifications
  bool isLoading = false;

  int get unreadCount {
    return friendRequests.length + commentNotifications.length;
  }

  reset() {
    friendRequests = [];
    sentFriendRequests = [];
    commentNotifications = []; // Reset comment notifications
  }

  Future<void> fetchFriendRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    isLoading = true;
    notifyListeners();

    final response = await http.get(
      Uri.parse('https://api.bybl.dev/api/friends/requests'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      var responseBody = json.decode(response.body);
      friendRequests = responseBody != null
          ? (responseBody as List<dynamic>)
              .map<Friend>((data) => Friend.fromJson(data))
              .toList()
          : [];
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCommentNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    isLoading = true;
    notifyListeners();

    final response = await http.get(
      Uri.parse(
          'https://api.bybl.dev/api/commentRequests'), // Adjust this URL based on your actual API
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      var responseBody = json.decode(response.body);
      print(responseBody.toString());
      commentNotifications = responseBody != null
          ? (responseBody as List<dynamic>)
              .map<CommentNotification>(
                  (data) => CommentNotification.fromJson(data))
              .toList()
          : [];
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> deleteCommentNotification(int notificationId) async {
    final url = Uri.parse(
        'https://api.bybl.dev/api/notifications/comments/$notificationId');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    try {
      isLoading = true;
      notifyListeners(); // Update UI for loading state

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Adjust for your auth
        },
      );

      if (response.statusCode == 200) {
        // Remove notification from the list
        commentNotifications.removeWhere(
            (notification) => notification.notificationId == notificationId);
        await fetchCommentNotifications();
        notifyListeners();
      } else {
        // Handle error, for example log it or show a message
        throw Exception('Failed to delete notification');
      }
    } catch (error, stack) {
      debugPrint('🔥 Error: $error\n$stack');
    } finally {
      isLoading = false;
      notifyListeners(); // Update UI to indicate loading has finished
    }
  }

  Future<void> respondFriendRequest(int userId, {required bool accept}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('https://api.bybl.dev/api/friends/requests/$userId/respond'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'accept': accept}),
    );
    if (response.statusCode == 200) {
      await fetchFriendRequests();
      notifyListeners();
    }
  }

  bool isFriendRequested(int friendId) {
    return sentFriendRequests.contains(friendId);
  }

  Future<void> fetchAllNotifications() async {
    await fetchFriendRequests();
    await fetchCommentNotifications();
  }

  Future<bool> sendFriendRequest(int friendId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.post(
      Uri.parse('https://api.bybl.dev/api/friends/$friendId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      sentFriendRequests.add(friendId);
      notifyListeners();
      return true;
    } else {
      await fetchFriendRequests();
      notifyListeners();
    }
    return false;
  }
}
