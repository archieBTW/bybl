class Message {
  final int messageId;
  final String content;
  final String? title;
  final int churchId;
  final int? groupId;
  final int createdBy;
  final String username;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.messageId,
    required this.content,
    this.title,
    required this.churchId,
    this.groupId,
    required this.createdBy,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['MessageID'] ?? json['message_id'],
      content: json['Content'] ?? json['content'],
      title: json['Title'] ?? json['title'],
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
      'MessageID': messageId,
      'Content': content,
      'Title': title,
      'ChurchID': churchId,
      'GroupID': groupId,
      'CreatedBy': createdBy,
      'Username': username,
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt.toIso8601String(),
    };
  }
}
