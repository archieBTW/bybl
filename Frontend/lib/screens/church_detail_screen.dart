import 'package:TheWord/providers/settings_provider.dart';
import 'package:TheWord/services/settings_service.dart';
import 'package:TheWord/shared/widgets/editable_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:TheWord/providers/church_provider.dart';
import 'package:TheWord/models/church.dart';
import 'package:TheWord/models/event.dart';
import 'package:TheWord/models/message.dart';
import 'package:TheWord/models/prayer_request.dart';
import 'package:TheWord/screens/small_group_detail_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ChurchDetailScreen extends StatefulWidget {
  const ChurchDetailScreen({Key? key}) : super(key: key);

  @override
  State<ChurchDetailScreen> createState() => _ChurchDetailScreenState();
}

class _ChurchDetailScreenState extends State<ChurchDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _churchTabController;
  final TextEditingController _prayerRequestController =
      TextEditingController();
  bool _isAnonymous = false;
  ThemeData? theme;
  int _avatarTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _churchTabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: 0,
    );
  }

  @override
  void dispose() {
    _churchTabController.dispose();
    _prayerRequestController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadChurchLogo(int churchId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.bybl.dev/api/churches/$churchId/logo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files
          .add(await http.MultipartFile.fromPath('logo', pickedFile.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Church logo updated!')),
        );
        if (mounted) {
          await Provider.of<ChurchProvider>(context, listen: false)
              .fetchChurches();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to upload logo: ${response.reasonPhrase}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChurchProvider>(
      builder: (context, churchProvider, child) {
        theme = Theme.of(context);

        if (churchProvider.isLoading || churchProvider.selectedChurch == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final settingsProvider = Provider.of<SettingsProvider>(context);

        final church = churchProvider.selectedChurch!;
        final bool isAdmin = churchProvider.isAdmin &&
            church.churchID == churchProvider.userChurchId;
        final bool isMember = churchProvider.isMember &&
            church.churchID == churchProvider.userChurchId;

        return Scaffold(
          appBar: AppBar(
              title: Text(church.name),
              actions: [
                if (!isMember)
                  TextButton(
                    onPressed: () async {
                      try {
                        await churchProvider.joinChurch(church.churchID);
                        if (mounted) {
                          await Provider.of<SettingsProvider>(context,
                                  listen: false)
                              .loadSettings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Successfully joined the church')),
                          );
                        }
                      } catch (e, stack) {
                        debugPrint('🔥 Error: $e\n$stack');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error joining church: $e')),
                          );
                        }
                      }
                    },
                    child: Text('Join Church',
                        style: TextStyle(color: settingsProvider.fontColor)),
                  ),
                if (isMember && !isAdmin)
                  TextButton(
                    onPressed: () async {
                      try {
                        await churchProvider.leaveChurch();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Successfully left the church')),
                          );
                        }
                      } catch (e, stack) {
                        debugPrint('🔥 Error: $e\n$stack');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error leaving church: $e')),
                          );
                        }
                      }
                    },
                    child: Text('Leave Church',
                        style: TextStyle(color: settingsProvider.fontColor)),
                  ),
              ],
              bottom: TabBar(
                controller: _churchTabController,
                labelColor: settingsProvider.fontColor,
                unselectedLabelColor:
                    settingsProvider.fontColor.withOpacity(0.7),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Groups'),
                  Tab(text: 'Events'),
                  Tab(text: 'Prayer'),
                ]
                    .where((tab) =>
                        tab.text != 'Prayer' || churchProvider.isMember)
                    .toList(),
              )),
          body: TabBarView(
            controller: _churchTabController,
            children: [
              _buildOverviewTab(church, isAdmin, churchProvider),
              _buildSmallGroupsTab(church),
              _buildEventsTab(church),
              if (churchProvider.isMember)
                _buildPrayerTab(church, churchProvider.isAdmin),
            ],
          ),
          floatingActionButton: isAdmin && isMember
              ? FloatingActionButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.post_add),
                            title: const Text('Create Post'),
                            onTap: () async {
                              Navigator.pop(context);
                              final result =
                                  await showDialog<Map<String, String>>(
                                context: context,
                                builder: (context) => CreatePostDialog(),
                              );
                              if (result != null) {
                                try {
                                  await churchProvider.createPost(
                                    church.churchID,
                                    result['title']!,
                                    result['content']!,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Post created successfully')),
                                    );
                                  }
                                } catch (e, stack) {
                                  debugPrint('🔥 Error: $e\n$stack');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Error creating post: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.event),
                            title: const Text('Create Event'),
                            onTap: () async {
                              Navigator.pop(context);
                              final result =
                                  await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (context) => CreateEventDialog(),
                              );
                              if (result != null) {
                                try {
                                  await churchProvider.createEvent(
                                    church.churchID,
                                    result['title']!,
                                    result['description']!,
                                    result['startTime']!,
                                    result['endTime']!,
                                    result['location']!,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Event created successfully')),
                                    );
                                  }
                                } catch (e, stack) {
                                  debugPrint('🔥 Error: $e\n$stack');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Error creating event: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.group_add),
                            title: const Text('Create Small Group'),
                            onTap: () async {
                              Navigator.pop(context);
                              final result =
                                  await showDialog<Map<String, String>>(
                                context: context,
                                builder: (context) => CreateGroupDialog(),
                              );
                              if (result != null) {
                                try {
                                  await churchProvider.createGroup(
                                    church.churchID,
                                    result['name']!,
                                    result['description']!,
                                    result['meetingDay']!,
                                    result['meetingTime']!,
                                    result['meetingLocation']!,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Group created successfully')),
                                    );
                                  }
                                } catch (e, stack) {
                                  debugPrint('🔥 Error: $e\n$stack');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Error creating group: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Widget _buildOverviewTab(
      Church church, bool isAdmin, ChurchProvider churchProvider) {
    final theme = Theme.of(context);

    bool shouldTruncate = church.description.length > 250; // ~5 lines

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: Avatar + About Us side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditableAvatar(
                radius: 50,
                imageUrl:
                    'https://api.bybl.dev/api/avatar?type=church&id=${church.churchID}',
                fallbackIcon: Icons.church,
                onEdit: isAdmin
                    ? () => SettingsService().handleAvatarUpload(
                          context: context,
                          uploadUrl:
                              'https://api.bybl.dev/api/churches/${church.churchID}/avatar',
                          onSuccess: () async {
                            await Provider.of<ChurchProvider>(context,
                                    listen: false)
                                .selectChurch(church.churchID);
                            setState(() {
                              _avatarTimestamp =
                                  DateTime.now().millisecondsSinceEpoch;
                            });
                          },
                        )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  color: theme.cardColor,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Us',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shouldTruncate
                              ? '${church.description.substring(0, 250)}...'
                              : church.description.isNotEmpty
                                  ? church.description
                                  : 'No description provided.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (shouldTruncate)
                          TextButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('About Us'),
                                  content: SingleChildScrollView(
                                    child: Text(church.description),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Close'),
                                    )
                                  ],
                                ),
                              );
                            },
                            child: const Text('Read More'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _buildContactRow(Icons.location_on,
                        '${church.address}, ${church.city}, ${church.state} ${church.zipCode}, ${church.country}'),
                    _buildContactRow(Icons.phone, church.phone),
                    _buildContactRow(Icons.email, church.email),
                    _buildContactRow(Icons.language, church.website),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // const Divider(),

          // Announcements Section (only if any announcements exist)
          if (church.messages.isNotEmpty)
            Text(
              'Announcements',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          if (church.messages.isNotEmpty) const SizedBox(height: 8),

          if (church.messages.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 92, bottom: 92),
                child: Image.asset(
                  'assets/icon/cross_nav.png',
                  width: 72,
                  height: 72,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: church.messages.length,
              itemBuilder: (context, index) {
                final message = church.messages[index];
                return Card(
                  color: theme.cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                      message.title ?? 'Announcement',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(message.content),
                        const SizedBox(height: 8),
                        Text(
                          _formatDateTime(message.createdAt),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: isAdmin
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await context
                                  .read<ChurchProvider>()
                                  .deleteChurchMessage(message.messageId);
                            },
                          )
                        : null,
                  ),
                );
              },
            ),

          const SizedBox(height: 24),
          // const Divider(),

          // Bottom Contact Info
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (text.isNotEmpty) {
                if (icon == Icons.phone) {
                  final phoneNumber = text.replaceAll(RegExp(r'[^\d]'), '');
                  launchUrl(Uri.parse('tel:$phoneNumber'));
                } else if (icon == Icons.email) {
                  launchUrl(Uri.parse('mailto:$text'));
                } else if (icon == Icons.language) {
                  final url = text.startsWith('http') ? text : 'https://$text';
                  launchUrl(Uri.parse(url));
                }
              }
            },
            child: Text(
              text.isNotEmpty ? text : 'Not provided',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.none,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallGroupsTab(Church church) {
    if (church.smallGroups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No small groups available yet.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: church.smallGroups.length,
      itemBuilder: (context, index) {
        final group = church.smallGroups[index];
        return Card(
          color: theme?.cardColor,
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(
                'https://api.bybl.dev/api/avatar?type=group&id=${group.groupId}',
              ),
              child: const Icon(Icons.group), // fallback while loading
            ),
            title: Text(group.name),
            subtitle: Text(
                '${group.meetingDay ?? 'No Day'} at ${group.meetingTime ?? 'No Time'}'),
            onTap: () {
              context.read<ChurchProvider>().selectGroup(group.groupId);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SmallGroupDetailScreen(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEventsTab(Church church) {
    final isAdmin = Provider.of<ChurchProvider>(context, listen: false).isAdmin;

    if (church.events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No upcoming events yet.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: church.events.length,
      itemBuilder: (context, index) {
        final event = church.events[index];
        return Card(
          color: theme?.cardColor,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await Provider.of<ChurchProvider>(context,
                                  listen: false)
                              .deleteChurchEvent(event.eventId);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (event.description != null) ...[
                  Text(
                    event.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDateTime(event.startTime)} - ${event.endTime != null ? _formatDateTime(event.endTime!) : 'No end time'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event.location ?? 'Location not specified',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                if (event.groupName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.group, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Hosted by: ${event.groupName}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour % 12;
    final amPm = dateTime.hour < 12 ? 'AM' : 'PM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final month = dateTime.month;
    final day = dateTime.day;
    final year = dateTime.year;

    return '$month/$day/$year ${hour == 0 ? 12 : hour}:$minute $amPm';
  }

  Widget _buildPrayerTab(Church church, bool isAdmin) {
    final fontColor =
        Provider.of<SettingsProvider>(context, listen: false).fontColor;

    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: church.prayerRequests.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: Image.asset(
                      'assets/icon/cross_nav.png',
                      width: 72,
                      height: 72,
                      color: fontColor,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: church.prayerRequests.length,
                  itemBuilder: (context, index) {
                    final request = church.prayerRequests[index];
                    return Card(
                      color: theme?.cardColor,
                      child: ListTile(
                        title: Text(request.isAnonymous
                            ? 'Anonymous'
                            : request.username),
                        subtitle: Text(request.content),
                        trailing: isAdmin
                            ? IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await Provider.of<ChurchProvider>(context,
                                          listen: false)
                                      .deleteChurchPrayerRequest(
                                          request.requestId);
                                },
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
        if (!isAdmin)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _prayerRequestController,
                  decoration: const InputDecoration(
                    labelText: 'Your Prayer Request',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 5,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _isAnonymous,
                      onChanged: (value) {
                        setState(() {
                          _isAnonymous = value ?? false;
                        });
                      },
                    ),
                    const Text('Post anonymously'),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final content = _prayerRequestController.text.trim();
                    if (content.isEmpty) return;

                    try {
                      await Provider.of<ChurchProvider>(context, listen: false)
                          .submitPrayerRequest(
                        church.churchID,
                        content,
                        _isAnonymous,
                      );
                      _prayerRequestController.clear();
                      setState(() {
                        _isAnonymous = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Prayer request submitted')),
                      );
                    } catch (e, stack) {
                      debugPrint('🔥 Error: $e\n$stack');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Submit Prayer Request'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CreatePostDialog extends StatelessWidget {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(labelText: 'Content'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty &&
                _contentController.text.isNotEmpty) {
              Navigator.pop(context, {
                'title': _titleController.text,
                'content': _contentController.text,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class CreateEventDialog extends StatefulWidget {
  @override
  _CreateEventDialogState createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));

  Future<void> _selectDateTime(bool isStartTime) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartTime ? _startTime : _endTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(isStartTime ? _startTime : _endTime),
      );
      if (time != null) {
        setState(() {
          final dateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          if (isStartTime) {
            _startTime = dateTime;
          } else {
            _endTime = dateTime;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_startTime.toString()),
              onTap: () => _selectDateTime(true),
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(_endTime.toString()),
              onTap: () => _selectDateTime(false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty &&
                _descriptionController.text.isNotEmpty &&
                _locationController.text.isNotEmpty) {
              Navigator.pop(context, {
                'title': _titleController.text,
                'description': _descriptionController.text,
                'location': _locationController.text,
                'startTime': _startTime,
                'endTime': _endTime,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class CreateGroupDialog extends StatefulWidget {
  @override
  _CreateGroupDialogState createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _meetingLocationController =
      TextEditingController();

  String? _selectedDay;
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Small Group'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDay,
              hint: const Text('Select Meeting Day'),
              items: _daysOfWeek
                  .map((day) => DropdownMenuItem(value: day, child: Text(day)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDay = value;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Meeting Time'),
              subtitle: Text(_selectedTime.format(context)),
              onTap: _selectTime,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _meetingLocationController,
              decoration: const InputDecoration(labelText: 'Meeting Location'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _descriptionController.text.isNotEmpty &&
                _selectedDay != null &&
                _meetingLocationController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'description': _descriptionController.text,
                'meetingDay': _selectedDay!,
                'meetingTime': _selectedTime.format(context),
                'meetingLocation': _meetingLocationController.text,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
