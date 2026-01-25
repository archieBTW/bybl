// import 'message.dart';
// import 'event.dart';
// import 'prayer_request.dart';

// class SmallGroup {
//   final int groupId;
//   final int churchId;
//   final String name;
//   final String? description;
//   final String? meetingDay;
//   final String? meetingTime;
//   final String? meetingLocation;
//   final int leaderId;
//   final int memberCount;
//   final bool isLeader;
//   final DateTime createdAt;
//   final DateTime updatedAt;
//   final List<Message?>? messages;
//   final List<ChurchEvent?>? events;
//   final List<PrayerRequest?>? prayerRequests;
//   final bool isMember;

//   SmallGroup({
//     required this.groupId,
//     required this.churchId,
//     required this.name,
//     this.description,
//     this.meetingDay,
//     this.meetingTime,
//     this.meetingLocation,
//     required this.leaderId,
//     this.memberCount = 0,
//     this.isLeader = false,
//     required this.createdAt,
//     required this.updatedAt,
//     required this.messages,
//     required this.events,
//     required this.prayerRequests,
//     this.isMember = false,
//   });

//   factory SmallGroup.fromJson(Map<String, dynamic> json) {
//     return SmallGroup(
//       groupId: json['GroupID'] ?? json['group_id'] ?? 0,
//       churchId: json['ChurchID'] ?? json['church_id'] ?? 0,
//       name: json['Name'] ?? json['name'] ?? '',
//       description: json['Description'] ?? json['description'],
//       meetingDay: json['MeetingDay'] ?? json['meeting_day'],
//       meetingTime: json['MeetingTime'] ?? json['meeting_time'],
//       meetingLocation: json['MeetingLocation'] ?? json['meeting_location'],
//       leaderId: json['LeaderID'] ?? json['leader_id'] ?? 0,
//       memberCount: json['MemberCount'] ?? json['member_count'] ?? 0,
//       isLeader: json['IsLeader'] ?? json['is_leader'] ?? false,
//       isMember: json['IsMember'] ?? json['is_member'] ?? false,
//       createdAt: json['CreatedAt'] != null
//           ? DateTime.parse(json['CreatedAt'])
//           : DateTime.now(),
//       updatedAt: json['UpdatedAt'] != null
//           ? DateTime.parse(json['UpdatedAt'])
//           : DateTime.now(),
//       messages: (json['messages'] as List?)
//               ?.map((message) => Message.fromJson(message))
//               .toList() ??
//           [],
//       events: (json['events'] as List?)
//               ?.map((event) => ChurchEvent.fromJson(event))
//               .toList() ??
//           [],
//       prayerRequests: (json['prayerRequests'] as List?)
//               ?.map((request) => PrayerRequest.fromJson(request))
//               .toList() ??
//           [],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'GroupID': groupId,
//       'ChurchID': churchId,
//       'Name': name,
//       'Description': description,
//       'MeetingDay': meetingDay,
//       'MeetingTime': meetingTime,
//       'MeetingLocation': meetingLocation,
//       'LeaderID': leaderId,
//       'MemberCount': memberCount,
//       'IsLeader': isLeader,
//       'IsMember': isMember,
//       'CreatedAt': createdAt.toIso8601String(),
//       'UpdatedAt': updatedAt.toIso8601String(),
//       'messages': messages?.map((message) => message?.toJson()).toList() ?? [],
//       'events': events?.map((event) => event?.toJson()).toList() ?? [],
//       'prayerRequests':
//           prayerRequests?.map((request) => request?.toJson()).toList() ?? [],
//     };
//   }
// }
// import 'package:TheWord/models/event.dart';
// import 'package:TheWord/models/message.dart';
// import 'package:TheWord/models/prayer_request.dart';

// class SmallGroup {
//   final int groupId;
//   final int churchId;
//   final String name;
//   final String? description;
//   final String? meetingDay;
//   final String? meetingTime;
//   final String? meetingLocation;
//   final int leaderId;
//   final int memberCount;
//   final bool isLeader;
//   final bool isMember;
//   final String? avatarUrl; // <-- new
//   final DateTime createdAt;
//   final DateTime updatedAt;
//   final List<Message?>? messages;
//   final List<ChurchEvent?>? events;
//   final List<PrayerRequest?>? prayerRequests;

//   SmallGroup({
//     required this.groupId,
//     required this.churchId,
//     required this.name,
//     this.description,
//     this.meetingDay,
//     this.meetingTime,
//     this.meetingLocation,
//     required this.leaderId,
//     this.memberCount = 0,
//     this.isLeader = false,
//     this.isMember = false,
//     this.avatarUrl,
//     required this.createdAt,
//     required this.updatedAt,
//     this.messages,
//     this.events,
//     this.prayerRequests,
//   });

//   factory SmallGroup.fromJson(Map<String, dynamic> json) {
//     return SmallGroup(
//       groupId: json['GroupID'] ?? json['group_id'],
//       churchId: json['ChurchID'] ?? json['church_id'],
//       name: json['Name'] ?? json['name'],
//       description: json['Description'] ?? json['description'],
//       meetingDay: json['MeetingDay'] ?? json['meeting_day'],
//       meetingTime: json['MeetingTime'] ?? json['meeting_time'],
//       meetingLocation: json['MeetingLocation'] ?? json['meeting_location'],
//       leaderId: json['LeaderID'] ?? json['leader_id'],
//       memberCount: json['MemberCount'] ?? json['member_count'] ?? 0,
//       isLeader: json['IsLeader'] ?? json['is_leader'] ?? false,
//       isMember: json['IsMember'] ?? json['is_member'] ?? false,
//       avatarUrl: json['AvatarURL'] ?? json['avatar_url'], // new
//       createdAt: json['CreatedAt'] != null
//           ? DateTime.parse(json['CreatedAt'])
//           : DateTime.now(),
//       updatedAt: json['UpdatedAt'] != null
//           ? DateTime.parse(json['UpdatedAt'])
//           : DateTime.now(),
//       messages: (json['messages'] as List?)
//               ?.map((message) => Message.fromJson(message))
//               .toList() ??
//           [],
//       events: (json['events'] as List?)
//               ?.map((event) => ChurchEvent.fromJson(event))
//               .toList() ??
//           [],
//       prayerRequests: (json['prayerRequests'] as List?)
//               ?.map((request) => PrayerRequest.fromJson(request))
//               .toList() ??
//           [],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'GroupID': groupId,
//       'ChurchID': churchId,
//       'Name': name,
//       'Description': description,
//       'MeetingDay': meetingDay,
//       'MeetingTime': meetingTime,
//       'MeetingLocation': meetingLocation,
//       'LeaderID': leaderId,
//       'MemberCount': memberCount,
//       'IsLeader': isLeader,
//       'IsMember': isMember,
//       'AvatarURL': avatarUrl, // new
//       'CreatedAt': createdAt.toIso8601String(),
//       'UpdatedAt': updatedAt.toIso8601String(),
//       'messages': messages?.map((message) => message?.toJson()).toList() ?? [],
//       'events': events?.map((event) => event?.toJson()).toList() ?? [],
//       'prayerRequests':
//           prayerRequests?.map((request) => request?.toJson()).toList() ?? [],
//     };
//   }
// }

// models/small_group.dart
import 'message.dart';
import 'event.dart';
import 'prayer_request.dart';

class SmallGroup {
  final int groupId;
  final int churchId;
  final String name;
  final String? description;
  final String? meetingDay;
  final String? meetingTime;
  final String? meetingLocation;
  final int leaderId;
  final int memberCount;
  final bool isLeader;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message?>? messages;
  final List<ChurchEvent?>? events;
  final List<PrayerRequest?>? prayerRequests;
  final bool isMember;
  final String? logoURL; // <-- NEW

  SmallGroup({
    required this.groupId,
    required this.churchId,
    required this.name,
    this.description,
    this.meetingDay,
    this.meetingTime,
    this.meetingLocation,
    required this.leaderId,
    this.memberCount = 0,
    this.isLeader = false,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    required this.events,
    required this.prayerRequests,
    this.isMember = false,
    this.logoURL, // <-- NEW
  });

  factory SmallGroup.fromJson(Map<String, dynamic> json) {
    return SmallGroup(
      groupId: json['GroupID'] ?? json['group_id'] ?? 0,
      churchId: json['ChurchID'] ?? json['church_id'] ?? 0,
      name: json['Name'] ?? json['name'] ?? '',
      description: json['Description'] ?? json['description'],
      meetingDay: json['MeetingDay'] ?? json['meeting_day'],
      meetingTime: json['MeetingTime'] ?? json['meeting_time'],
      meetingLocation: json['MeetingLocation'] ?? json['meeting_location'],
      leaderId: json['LeaderID'] ?? json['leader_id'] ?? 0,
      memberCount: json['MemberCount'] ?? json['member_count'] ?? 0,
      isLeader: json['IsLeader'] ?? json['is_leader'] ?? false,
      isMember: json['IsMember'] ?? json['is_member'] ?? false,
      createdAt: json['CreatedAt'] != null
          ? DateTime.parse(json['CreatedAt'])
          : DateTime.now(),
      updatedAt: json['UpdatedAt'] != null
          ? DateTime.parse(json['UpdatedAt'])
          : DateTime.now(),
      logoURL: json['LogoURL'] ?? json['logo_url'], // <-- NEW
      messages: (json['messages'] as List?)
              ?.map((message) => Message.fromJson(message))
              .toList() ??
          [],
      events: (json['events'] as List?)
              ?.map((event) => ChurchEvent.fromJson(event))
              .toList() ??
          [],
      prayerRequests: (json['prayerRequests'] as List?)
              ?.map((request) => PrayerRequest.fromJson(request))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'GroupID': groupId,
      'ChurchID': churchId,
      'Name': name,
      'Description': description,
      'MeetingDay': meetingDay,
      'MeetingTime': meetingTime,
      'MeetingLocation': meetingLocation,
      'LeaderID': leaderId,
      'MemberCount': memberCount,
      'IsLeader': isLeader,
      'IsMember': isMember,
      'LogoURL': logoURL, // <-- NEW
      'CreatedAt': createdAt.toIso8601String(),
      'UpdatedAt': updatedAt.toIso8601String(),
      'messages': messages?.map((message) => message?.toJson()).toList() ?? [],
      'events': events?.map((event) => event?.toJson()).toList() ?? [],
      'prayerRequests':
          prayerRequests?.map((request) => request?.toJson()).toList() ?? [],
    };
  }
}
