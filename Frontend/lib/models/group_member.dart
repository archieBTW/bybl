class GroupMember {
  final int userId;
  final String username;
  final String email;
  final bool isLeader;
  final DateTime joinedAt;
  final bool? isMember; // Optional, only if you're passing this from backend

  GroupMember({
    required this.userId,
    required this.username,
    required this.email,
    required this.isLeader,
    required this.joinedAt,
    this.isMember = false, // Optional with default
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['UserID'] ?? json['user_id'],
      username: json['Username'] ?? json['username'],
      email: json['Email'] ?? json['email'],
      isLeader: json['isLeader'] ?? json['is_leader'] ?? false,
      joinedAt: json['JoinedAt'] != null
          ? DateTime.parse(json['JoinedAt'])
          : DateTime.now(),
      isMember: json['isMember'] ?? json['is_member'] ?? false, // optional
    );
  }
}
