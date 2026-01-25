import 'package:TheWord/models/event.dart';
import 'package:TheWord/models/message.dart';
import 'package:TheWord/models/small_group.dart';
import 'package:TheWord/models/prayer_request.dart';

class Church {
  final int churchID;
  final String name;
  final String description;
  final String address;
  final String city;
  final String state;
  final String country;
  final String zipCode;
  final double? latitude;
  final double? longitude;
  final String website;
  final String phone;
  final String email;
  final String? logoURL; // (optional older logo url)
  final String? avatarUrl; // (new church avatar image url)
  final List<SmallGroup> smallGroups;
  final List<Message> messages;
  final List<ChurchEvent> events;
  final List<PrayerRequest> prayerRequests;

  Church({
    required this.churchID,
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    required this.zipCode,
    this.latitude,
    this.longitude,
    required this.website,
    required this.phone,
    required this.email,
    this.logoURL,
    this.avatarUrl,
    required this.smallGroups,
    required this.messages,
    required this.events,
    required this.prayerRequests,
  });

  factory Church.fromJson(Map<String, dynamic> json) {
    final churchData = json["church"] ?? json;

    return Church(
      churchID: churchData['ChurchID'] ?? churchData['church_id'],
      name: churchData['Name'] ?? churchData['name'],
      description: churchData['Description'] ?? churchData['description'],
      address: churchData['Address'] ?? churchData['address'],
      city: churchData['City'] ?? churchData['city'],
      state: churchData['State'] ?? churchData['state'],
      country: churchData['Country'] ?? churchData['country'],
      zipCode: churchData['ZipCode'] ?? churchData['zip_code'],
      latitude: churchData['Latitude'] != null
          ? (churchData['Latitude'] is int
              ? (churchData['Latitude'] as int).toDouble()
              : churchData['Latitude'])
          : null,
      longitude: churchData['Longitude'] != null
          ? (churchData['Longitude'] is int
              ? (churchData['Longitude'] as int).toDouble()
              : churchData['Longitude'])
          : null,
      website: churchData['Website'] ?? churchData['website'],
      phone: churchData['Phone'] ?? churchData['phone'],
      email: churchData['Email'] ?? churchData['email'],
      logoURL: churchData['LogoURL'] ?? churchData['logo_url'],
      avatarUrl: churchData['AvatarURL'] ?? churchData['avatar_url'],
      smallGroups: (json['groups'] as List?)
              ?.map((group) => SmallGroup.fromJson(group))
              .toList() ??
          [],
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
      'ChurchID': churchID,
      'Name': name,
      'Description': description,
      'Address': address,
      'City': city,
      'State': state,
      'Country': country,
      'ZipCode': zipCode,
      'Latitude': latitude,
      'Longitude': longitude,
      'Website': website,
      'Phone': phone,
      'Email': email,
      'LogoURL': logoURL,
      'AvatarURL': avatarUrl,
      'groups': smallGroups.map((group) => group.toJson()).toList(),
      'messages': messages.map((message) => message.toJson()).toList(),
      'events': events.map((event) => event.toJson()).toList(),
      'prayerRequests':
          prayerRequests.map((request) => request.toJson()).toList(),
    };
  }
}
