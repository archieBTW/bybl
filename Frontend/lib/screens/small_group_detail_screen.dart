import 'package:TheWord/providers/group_provider.dart';
import 'package:TheWord/providers/settings_provider.dart';
import 'package:TheWord/services/settings_service.dart';
import 'package:TheWord/shared/widgets/editable_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:TheWord/providers/church_provider.dart';
import 'package:TheWord/models/small_group.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmallGroupDetailScreen extends StatefulWidget {
  const SmallGroupDetailScreen({Key? key}) : super(key: key);

  @override
  State<SmallGroupDetailScreen> createState() => _SmallGroupDetailScreenState();
}

class _SmallGroupDetailScreenState extends State<SmallGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _prayerRequestController =
      TextEditingController();
  bool _isAnonymous = false;
  Color? cardColor;
  ThemeData? theme;
  int _avatarTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _prayerRequestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChurchProvider>(
      builder: (context, churchProvider, child) {
        theme = Theme.of(context);
        cardColor = theme?.cardColor;
        if (churchProvider.isLoading || churchProvider.selectedGroup == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final settingsProvider = Provider.of<SettingsProvider>(context);
        final group = churchProvider.selectedGroup!;

        final rootCtx = context;

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            bottom: TabBar(
              controller: _tabController,
              labelColor: settingsProvider.fontColor,
              unselectedLabelColor: settingsProvider.fontColor.withOpacity(0.7),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Posts'),
                Tab(text: 'Events'),
                Tab(text: 'Prayer'),
              ].where((tab) => tab.text != 'Prayer' || group.isMember).toList(),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(group, rootCtx),
              _buildMessagesTab(group),
              _buildEventsTab(group),
              if (group.isMember) _buildPrayerTab(group),
            ],
          ),
          floatingActionButton: group.isLeader ||
                  (group.churchId == churchProvider.userChurchId &&
                      churchProvider.isAdmin)
              ? FloatingActionButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ------------------- CREATE MESSAGE -----------------------
                          ListTile(
                            leading: const Icon(Icons.post_add),
                            title: const Text('Create Group Announcement'),
                            onTap: () async {
                              Navigator.pop(ctx); // close sheet first
                              final result =
                                  await showDialog<Map<String, String>>(
                                context: rootCtx,
                                builder: (_) => _CreateGroupMessageDialog(),
                              );
                              if (result != null) {
                                try {
                                  await Provider.of<GroupProvider>(rootCtx,
                                          listen: false)
                                      .createMessage(group.groupId,
                                          result['title']!, result['content']!);

                                  await churchProvider.selectGroup(
                                      group.groupId); // refresh selectedGroup

                                  if (!mounted) return;
                                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Message posted')),
                                  );
                                } catch (e, stack) {
                                  debugPrint('🔥 Error: $e\n$stack');
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                                      SnackBar(content: Text('Error: $e')));
                                }
                              }
                            },
                          ),
                          // ------------------- CREATE EVENT ------------------------
                          ListTile(
                            leading: const Icon(Icons.event),
                            title: const Text('Create Event'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final result =
                                  await showDialog<Map<String, dynamic>>(
                                context: rootCtx,
                                builder: (_) => _CreateGroupEventDialog(),
                              );
                              if (result != null) {
                                try {
                                  await Provider.of<GroupProvider>(rootCtx,
                                          listen: false)
                                      .createEvent(
                                    group.groupId,
                                    result['title'],
                                    result['description'],
                                    result['startTime'],
                                    result['endTime'],
                                    result['location'],
                                  );

                                  await churchProvider
                                      .selectGroup(group.groupId);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Event created')),
                                  );
                                } catch (e, stack) {
                                  debugPrint('🔥 Error: $e\n$stack');
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                                      SnackBar(content: Text('Error: $e')));
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

  Future<void> _pickAndUploadGroupLogo(int groupId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.bybl.dev/api/groups/$groupId/logo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files
          .add(await http.MultipartFile.fromPath('logo', pickedFile.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group logo updated!')),
        );
        if (mounted) {
          await Provider.of<ChurchProvider>(context, listen: false)
              .selectGroup(groupId);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to upload logo: ${response.reasonPhrase}')),
        );
      }
    }
  }

  // Widget _buildOverviewTab(SmallGroup group, BuildContext rootCtx) {
  //   final groupProvider = Provider.of<GroupProvider>(context, listen: false);
  //   final churchProvider = Provider.of<ChurchProvider>(context, listen: false);

  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.all(16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Center(
  //           child: EditableAvatar(
  //             radius: 60,
  //             imageUrl:
  //                 'https://api.bybl.dev/api/avatar?type=group&id=${group.groupId}',
  //             fallbackIcon: Icons.group,
  //             onEdit: () => SettingsService().handleAvatarUpload(
  //               context: context,
  //               uploadUrl:
  //                   'https://api.bybl.dev/api/groups/${group.groupId}/avatar',
  //               onSuccess: () async {
  //                 await Provider.of<ChurchProvider>(context, listen: false)
  //                     .selectGroup(group.groupId);
  //                 setState(() {}); // Refresh after upload
  //               },
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         Text(
  //           group.description ?? '',
  //           style: Theme.of(context).textTheme.bodyLarge,
  //         ),
  //         const SizedBox(height: 16),
  //         const Text(
  //           'Meeting Information',
  //           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //         ),
  //         const SizedBox(height: 8),
  //         Text('Day: ${group.meetingDay}'),
  //         Text('Time: ${group.meetingTime}'),
  //         Text('Location: ${group.meetingLocation}'),
  //         const SizedBox(height: 20),
  //         if (!group.isMember)
  //           ElevatedButton(
  //             onPressed: () async {
  //               final success = await groupProvider.joinGroup(group.groupId);
  //               if (!mounted) return;
  //               if (success) {
  //                 await churchProvider
  //                     .selectGroup(group.groupId); // refresh selectedGroup
  //               }
  //               ScaffoldMessenger.of(rootCtx).showSnackBar(
  //                 SnackBar(
  //                   content: Text(success
  //                       ? 'Successfully joined group'
  //                       : 'Failed to join group'),
  //                 ),
  //               );
  //             },
  //             child: const Text('Join Group'),
  //           )
  //         else
  //           ElevatedButton(
  //             onPressed: () async {
  //               final success = await groupProvider.leaveGroup(group.groupId);
  //               if (!mounted) return;
  //               if (success) {
  //                 await churchProvider.selectGroup(group.groupId);
  //               }
  //               ScaffoldMessenger.of(rootCtx).showSnackBar(
  //                 SnackBar(
  //                   content: Text(success
  //                       ? 'You left the group'
  //                       : 'Failed to leave group'),
  //                 ),
  //               );
  //             },
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.red,
  //             ),
  //             child: const Text('Leave Group'),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildOverviewTab(SmallGroup group, BuildContext rootCtx) {
    final theme = Theme.of(context);
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final churchProvider = Provider.of<ChurchProvider>(context, listen: false);

    bool shouldTruncate = (group.description?.length ?? 0) > 250;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Section: Avatar + About Group
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditableAvatar(
                radius: 50,
                imageUrl:
                    'https://api.bybl.dev/api/avatar?type=group&id=${group.groupId}&ts=$_avatarTimestamp',
                fallbackIcon: Icons.group,
                onEdit: () => SettingsService().handleAvatarUpload(
                  context: context,
                  uploadUrl:
                      'https://api.bybl.dev/api/groups/${group.groupId}/avatar',
                  onSuccess: () async {
                    await Provider.of<ChurchProvider>(context, listen: false)
                        .selectGroup(group.groupId);
                    setState(() {
                      _avatarTimestamp = DateTime.now().millisecondsSinceEpoch;
                    });
                  },
                ),
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
                        const SizedBox(height: 8),
                        Text(
                          shouldTruncate
                              ? '${group.description?.substring(0, 250)}...'
                              : group.description?.isNotEmpty == true
                                  ? group.description!
                                  : 'No description provided.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (shouldTruncate)
                          TextButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('About Group'),
                                  content: SingleChildScrollView(
                                    child: Text(group.description ?? ''),
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

          const SizedBox(height: 24),
          Card(
            color: theme.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Day: ${group.meetingDay ?? "N/A"}',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('Time: ${group.meetingTime ?? "N/A"}',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text('Location: ${group.meetingLocation ?? "N/A"}',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Join / Leave Button
          if (!group.isMember)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton(
                onPressed: () async {
                  final success = await groupProvider.joinGroup(group.groupId);
                  if (!mounted) return;
                  if (success) {
                    await churchProvider.selectGroup(group.groupId);
                  }
                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Successfully joined group'
                          : 'Failed to join group'),
                    ),
                  );
                },
                child: const Text('Join Group'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton(
                onPressed: () async {
                  final success = await groupProvider.leaveGroup(group.groupId);
                  if (!mounted) return;
                  if (success) {
                    await churchProvider.selectGroup(group.groupId);
                  }
                  ScaffoldMessenger.of(rootCtx).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'You left the group'
                          : 'Failed to leave group'),
                    ),
                  );
                },
                child: const Text('Leave Group'),
              ),
            ),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EVENTS TAB
  // ---------------------------------------------------------------------------
  Widget _buildEventsTab(SmallGroup group) {
    if (group.events == null || group.events!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No upcoming events for this group.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.events!.length,
      itemBuilder: (context, index) {
        final event = group.events![index];
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event!.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(event.description ?? ''),
                const SizedBox(height: 8),
                Text('${event.startTime} - ${event.endTime ?? 'No end time'}'),
                const SizedBox(height: 8),
                Text('Location: ${event.location}'),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MESSAGES TAB
  // ---------------------------------------------------------------------------
  Widget _buildMessagesTab(SmallGroup group) {
    if (group.messages == null || group.messages!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No Announcements yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: group.messages!.length,
      itemBuilder: (context, index) {
        final message = group.messages![index];
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(message!.title ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.content ?? ''),
                const SizedBox(height: 4),
                Text('Posted by: ${message.username}'),
                Text('Posted on: ${message.createdAt.toString()}'),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PRAYER TAB
  // ---------------------------------------------------------------------------
  Widget _buildPrayerTab(SmallGroup group) {
    final fontColor =
        Provider.of<SettingsProvider>(context, listen: false).fontColor;

    return Column(
      children: [
        const SizedBox(height: 8), // same top spacing
        Expanded(
          child: (group.prayerRequests == null || group.prayerRequests!.isEmpty)
              ? Padding(
                  // empty-state icon
                  padding: const EdgeInsets.only(top: 24),
                  child: Center(
                    child: Image.asset(
                      'assets/icon/cross_nav.png',
                      width: 72,
                      height: 72,
                      color: fontColor, // respects theme
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: group.prayerRequests!.length,
                  itemBuilder: (context, index) {
                    final req = group.prayerRequests![index]!;
                    return Card(
                      color: cardColor,
                      child: ListTile(
                        title:
                            Text(req.isAnonymous ? 'Anonymous' : req.username),
                        subtitle: Text(req.content ?? ''),
                      ),
                    );
                  },
                ),
        ),
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
                maxLines: 5, // match church style
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _isAnonymous,
                    onChanged: (val) =>
                        setState(() => _isAnonymous = val ?? false),
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
                    await Provider.of<GroupProvider>(context, listen: false)
                        .submitPrayerRequest(
                      group.groupId,
                      content,
                      _isAnonymous,
                    );
                    _prayerRequestController.clear();

                    await Provider.of<ChurchProvider>(context, listen: false)
                        .selectGroup(group.groupId); // refresh selectedGroup

                    setState(() => _isAnonymous = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Prayer request submitted'),
                      ),
                    );
                  } catch (e, stack) {
                    debugPrint('🔥 Error: $e\n$stack');
                    if (!mounted) return;
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

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------
class _CreateGroupMessageDialog extends StatelessWidget {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 3),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty &&
                _contentController.text.isNotEmpty) {
              Navigator.pop(context, {
                'title': _titleController.text,
                'content': _contentController.text
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _CreateGroupEventDialog extends StatefulWidget {
  @override
  _CreateGroupEventDialogState createState() => _CreateGroupEventDialogState();
}

class _CreateGroupEventDialogState extends State<_CreateGroupEventDialog> {
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
          final dt = DateTime(
              picked.year, picked.month, picked.day, time.hour, time.minute);
          if (isStartTime) {
            _startTime = dt;
          } else {
            _endTime = dt;
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
                decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3),
            const SizedBox(height: 8),
            TextField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 8),
            ListTile(
                title: const Text('Start Time'),
                subtitle: Text(_startTime.toString()),
                onTap: () => _selectDateTime(true)),
            ListTile(
                title: const Text('End Time'),
                subtitle: Text(_endTime.toString()),
                onTap: () => _selectDateTime(false)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
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
