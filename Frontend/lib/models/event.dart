class ChurchEvent {
  final int eventId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime? endTime;
  final String? location;
  final int churchId;
  final int? groupId;
  final String? groupName;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChurchEvent({
    required this.eventId,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.location,
    required this.churchId,
    this.groupId,
    this.groupName,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChurchEvent.fromJson(Map<String, dynamic> json) {
    return ChurchEvent(
      eventId: json['EventID'] ?? json['event_id'],
      title: json['Title'] ?? json['title'],
      description: json['Description'] ?? json['description'],
      startTime: json['StartTime'] != null
          ? DateTime.parse(json['StartTime'])
          : DateTime.now(),
      endTime: json['EndTime'] != null ? DateTime.parse(json['EndTime']) : null,
      location: json['Location'] ?? json['location'],
      churchId: json['ChurchID'] ?? json['church_id'],
      groupId: json['GroupID'] ?? json['group_id'],
      groupName: json['GroupName'] ?? json['group_name'],
      createdBy: json['CreatedBy'] ?? json['created_by'],
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
      'EventID': eventId,
      'Title': title,
      'Description': description,
      'StartTime': startTime.toIso8601String(),
      'EndTime': endTime?.toIso8601String(),
      'Location': location,
      'ChurchID': churchId,
      'GroupID': groupId,
      'GroupName': groupName,
      'CreatedBy': createdBy,
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt.toIso8601String(),
    };
  }
}
