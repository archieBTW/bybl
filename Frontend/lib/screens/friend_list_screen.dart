import 'package:TheWord/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/settings_provider.dart';

class FriendListScreen extends StatelessWidget {
  Future<void> _refreshFriends(BuildContext context) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.fetchFriends();
    await friendProvider.fetchSuggestedFriends();
  }

  @override
  Widget build(BuildContext context) {
    final friendProvider = Provider.of<FriendProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final notificationsProvider = Provider.of<NotificationProvider>(context);

    return Scaffold(
      body: friendProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => _refreshFriends(context),
        child: ListView(
          padding: const EdgeInsets.all(8.0),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Make new friends',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
            ),
            friendProvider.suggestedFriends.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'No suggested friends at the moment.',
                style: TextStyle(
                  fontSize: 16.0,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
                : SizedBox(
              height: 180,
              child: PageView.builder(
                itemCount: friendProvider.suggestedFriends.length,
                controller: PageController(viewportFraction: 0.8),
                itemBuilder: (context, index) {
                  final suggestedFriend = friendProvider.suggestedFriends[index];
                  return Card(
                    color: settingsProvider.currentColor,
                    margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                    elevation: 5,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestedFriend.username,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: settingsProvider.getFontColor(settingsProvider.currentColor!),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${suggestedFriend.mutualFriends} mutual friends',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: settingsProvider.getFontColor(settingsProvider.currentColor!),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () async {
                                final success = await notificationsProvider.sendFriendRequest(suggestedFriend.userID);
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Friend request sent to ${suggestedFriend.username}'),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to send friend request to ${suggestedFriend.username}'),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                notificationsProvider.isFriendRequested(suggestedFriend.userID)
                                    ? 'Friend Request Sent'
                                    : 'Add Friend',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 20, color: Colors.black),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Friends',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),
            ),
            friendProvider.friends.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'You have no friends added yet.',
                style: TextStyle(
                  fontSize: 16.0,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
                : SizedBox(
              height: 180,
              child: PageView.builder(
                itemCount: friendProvider.friends.length,
                controller: PageController(viewportFraction: 0.8),
                itemBuilder: (context, index) {
                  final friend = friendProvider.friends[index];
                  return Card(
                    color: settingsProvider.currentColor,
                    margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                    elevation: 5,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.username,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: settingsProvider.getFontColor(settingsProvider.currentColor!),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${friend.mutualFriends} mutual friends',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: settingsProvider.getFontColor(settingsProvider.currentColor!),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () async {
                                await friendProvider.removeFriend(friend.userID);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${friend.username} has been removed from your friends'),
                                  ),
                                );
                              },
                              child: const Text('Remove'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

