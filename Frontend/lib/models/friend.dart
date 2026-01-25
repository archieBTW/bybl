class Friend {
  final int userID;
  final String username;
  final String? avatarUrl;
  final int mutualFriends;
  final int totalLikeCount;

  Friend({
    required this.userID,
    required this.username,
    this.avatarUrl,
    required this.mutualFriends,
    required this.totalLikeCount,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      userID: json['user_id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      mutualFriends: json['mutual_friends'] ?? 0,
      totalLikeCount: json['total_like_count'] ?? 0,
    );
  }
}
