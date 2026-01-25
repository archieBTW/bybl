class PrayerRequest {
  final int requestId;
  final String content;
  final bool isAnonymous;
  final int churchId;
  final int? groupId;
  final int createdBy;
  final String username;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrayerRequest({
    required this.requestId,
    required this.content,
    required this.isAnonymous,
    required this.churchId,
    this.groupId,
    required this.createdBy,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrayerRequest.fromJson(Map<String, dynamic> json) {
    return PrayerRequest(
      requestId: json['RequestID'] ?? json['request_id'],
      content: json['Content'] ?? json['content'],
      isAnonymous: json['IsAnonymous'] ?? json['is_anonymous'] ?? false,
      churchId: json['ChurchID'] ?? json['church_id'],
      groupId: json['GroupID'] ?? json['group_id'],
      createdBy: json['CreatedBy'] ?? json['created_by'],
      username: json['Username'] ?? json['username'],
      createdAt: json['CreatedAt'] != null
          ? DateTime.parse(json['CreatedAt'])
          : DateTime.now(),
      updatedAt: json['UpdatedAt'] != null
          ? DateTime.parse(json['UpdatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'RequestID': requestId,
      'Content': content,
      'IsAnonymous': isAnonymous,
      'ChurchID': churchId,
      'GroupID': groupId,
      'CreatedBy': createdBy,
      'Username': username,
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt.toIso8601String(),
    };
  }
}
