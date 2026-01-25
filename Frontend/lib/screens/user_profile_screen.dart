// lib/screens/user_profile_screen.dart

import 'package:TheWord/shared/widgets/editable_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/widgets/initial_avatar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('https://api.bybl.dev/api/users/${widget.userId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userData = data;
          isLoading = false;
        });
      } else {
        print('Failed to fetch user profile: ${response.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('🔥 Error: $e\n$stack');
      print('Error fetching user profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(userData.toString());
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text('Failed to load user'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      EditableAvatar(
                        radius: 60,
                        imageUrl:
                            'https://api.bybl.dev/api/avatar?type=user&id=${widget.userId}',
                        fallbackIcon: Icons.person,
                        onEdit: null,
                      ),

                      // CircleAvatar(
                      //   radius: 60,
                      //   backgroundImage: userData!['AvatarURL'] != null &&
                      //           userData!['AvatarURL'].isNotEmpty
                      //       ? NetworkImage(
                      //           'https://api.bybl.dev/api/user/avatar/${widget.userId}')
                      //       : null,
                      //   child: (userData!['AvatarURL'] == null ||
                      //           userData!['AvatarURL'].isEmpty)
                      //       ? InitialAvatar(username: userData!['Username'])
                      //       : null,
                      // ),
                      const SizedBox(height: 20),
                      Text(
                        userData!['username'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Divider(),
                      // ListTile(
                      // title: const Text('Email'),
                      // subtitle: Text(userData!['Email'] ?? 'Unknown'),
                      // ),
                      // ListTile(
                      // title: const Text('Public Profile'),
                      // subtitle:
                      // Text(userData!['PublicProfile'] ? 'Yes' : 'No'),
                      // ),
                      ListTile(
                        title: const Text('Preferred Translation'),
                        subtitle: Text(userData!['translation_name'] ?? 'None'),
                      ),
                      if ((userData!['churchId'] ?? 0) != 0)
                        ListTile(
                          title: const Text('Church Member'),
                          subtitle: Text('Church ID: ${userData!['ChurchID']}'),
                          // Later you could fetch the church name here
                        ),
                    ],
                  ),
                ),
    );
  }
}
