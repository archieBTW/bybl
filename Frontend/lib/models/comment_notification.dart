class CommentNotification {
  final int notificationId;
  final int userId;
  final String content;
  final int? userVerseId; // Nullable because it can be null for comment notifications
  final int? commentId;   // Nullable because it can be null for verse notifications
  final DateTime createdAt;

  CommentNotification({
    required this.notificationId,
    required this.userId,
    required this.content,
    this.userVerseId,
    this.commentId,
    required this.createdAt,
  });

  factory CommentNotification.fromJson(Map<String, dynamic> json) {
    return CommentNotification(
      notificationId: json['NotificationID'],
      userId: json['UserID'],
      content: json['Content'],
      userVerseId: json['UserVerseID'],
      commentId: json['Comment'],
      createdAt: DateTime.parse(json['CreatedAt']),
    );
  }
}
