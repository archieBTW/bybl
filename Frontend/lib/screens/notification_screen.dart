import 'package:TheWord/providers/bible_provider.dart';
import 'package:TheWord/providers/friend_provider.dart';
import 'package:TheWord/providers/verse_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../shared/widgets/notification_card.dart';
import 'comment_screen.dart';

class NotificationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final friendsProvider = Provider.of<FriendProvider>(context, listen: false);
    return Scaffold(
      body: notificationProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notificationProvider.friendRequests.isEmpty &&
                  notificationProvider.commentNotifications.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "You're all caught up!",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (notificationProvider.friendRequests.isNotEmpty)
                      Expanded(
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Friend Requests',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: notificationProvider.friendRequests
                                      .map((request) {
                                    return NotificationCard(
                                      title: request.username,
                                      content:
                                          'Friend request from ${request.username}',
                                      actions: [
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: () async {
                                            await notificationProvider
                                                .respondFriendRequest(
                                                    request.userID,
                                                    accept: true);
                                            friendsProvider.fetchFriends();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () async {
                                            await notificationProvider
                                                .respondFriendRequest(
                                                    request.userID,
                                                    accept: false);
                                            await friendsProvider
                                                .fetchFriends();
                                          },
                                        ),
                                      ],
                                      onDelete: () async {
                                        await notificationProvider
                                            .respondFriendRequest(
                                                request.userID,
                                                accept: false);
                                        await friendsProvider.fetchFriends();
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (notificationProvider.friendRequests.isNotEmpty &&
                        notificationProvider.commentNotifications.isNotEmpty)
                      Container(
                        width: 1.0,
                        color: Colors.grey,
                      ),
                    if (notificationProvider.commentNotifications.isNotEmpty)
                      Expanded(
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Comment Notifications',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: notificationProvider
                                      .commentNotifications
                                      .map((notification) {
                                    return Dismissible(
                                      key: Key(notification.notificationId
                                          .toString()),
                                      direction: DismissDirection.endToStart,
                                      onDismissed: (direction) async {
                                        await notificationProvider
                                            .deleteCommentNotification(
                                                notification.notificationId);
                                      },
                                      background: Container(
                                        color: Colors.red,
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10.0),
                                        child: const Icon(Icons.delete,
                                            color: Colors.white),
                                      ),
                                      child: NotificationCard(
                                        title: 'New Comment',
                                        content: notification.content,
                                        actions: [
                                          IconButton(
                                            icon: Icon(Icons.close,
                                                color: Colors.red),
                                            onPressed: () async {
                                              if (notification.userVerseId !=
                                                  null) {
                                                var verse = await Provider.of<
                                                            VerseProvider>(
                                                        context,
                                                        listen: false)
                                                    .getVerseByUserVerseId(
                                                        notification.userVerseId
                                                            .toString());
                                                await notificationProvider
                                                    .deleteCommentNotification(
                                                        notification
                                                            .notificationId);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          CommentsScreen(
                                                              verse: verse)),
                                                );
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon:
                                                const Icon(Icons.arrow_forward),
                                            onPressed: () async {
                                              if (notification.userVerseId !=
                                                  null) {
                                                var verse = await Provider.of<
                                                            VerseProvider>(
                                                        context,
                                                        listen: false)
                                                    .getVerseByUserVerseId(
                                                        notification.userVerseId
                                                            .toString());
                                                await notificationProvider
                                                    .deleteCommentNotification(
                                                        notification
                                                            .notificationId);
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (context) =>
                                                          CommentsScreen(
                                                              verse: verse)),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                        onDelete: () async {
                                          await notificationProvider
                                              .deleteCommentNotification(
                                                  notification.notificationId);
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
