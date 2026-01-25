class ChurchMember {
  final int userId;
  final String username;
  final String email;
  final bool isAdmin;
  final DateTime joinedAt;
  final List<String>? groups;

  ChurchMember({
    required this.userId,
    required this.username,
    required this.email,
    required this.isAdmin,
    required this.joinedAt,
    this.groups,
  });

  factory ChurchMember.fromJson(Map<String, dynamic> json) {
    return ChurchMember(
      userId: json['UserID'] ?? json['user_id'],
      username: json['Username'] ?? json['username'],
      email: json['Email'] ?? json['email'],
      isAdmin: json['IsAdmin'] ?? json['is_admin'] ?? false,
      joinedAt: json['JoinedAt'] != null
          ? DateTime.parse(json['JoinedAt'])
          : DateTime.now(),
      groups: json['Groups'] != null ? List<String>.from(json['Groups']) : null,
    );
  }
}
