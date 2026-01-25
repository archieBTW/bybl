import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:TheWord/providers/church_provider.dart';
import 'package:TheWord/models/church.dart';
import 'package:TheWord/screens/church_detail_screen.dart';
import 'package:TheWord/screens/church_registration_screen.dart';

class ChurchScreen extends StatefulWidget {
  const ChurchScreen({Key? key}) : super(key: key);

  @override
  State<ChurchScreen> createState() => _ChurchScreenState();
}

class _ChurchScreenState extends State<ChurchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChurchProvider>().fetchChurches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChurchProvider>(
      builder: (context, churchProvider, child) {
        // If user is a member, show their church details
        // if (churchProvider.isMember && churchProvider.selectedChurch != null) {
        // return const ChurchDetailScreen();
        // }

        final theme = Theme.of(context);
        final backgroundColor = theme.brightness == Brightness.light
            ? theme.cardColor.withOpacity(0.9)
            : theme.cardColor;

        // If no churches found, show message and registration button
        if (churchProvider.churches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No churches found'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChurchRegistrationScreen(),
                      ),
                    );
                  },
                  child: const Text('Register a Church'),
                ),
              ],
            ),
          );
        }

        // Show list of churches for exploration
        return ListView.builder(
          itemCount: churchProvider.churches.length,
          itemBuilder: (context, index) {
            final church = churchProvider.churches[index];
            print('Building church card for: ${church.name}');
            return Card(
              color: backgroundColor,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: church.avatarUrl != null &&
                            church.avatarUrl!.isNotEmpty
                        ? NetworkImage(
                            'https://api.bybl.dev/api/avatar?type=church&id=${church.churchID}')
                        : null,
                    child:
                        (church.avatarUrl == null || church.avatarUrl!.isEmpty)
                            ? const Icon(Icons.church)
                            : null,
                  ),
                  title: Text(church.name),
                  subtitle: Text(church.city),
                  onTap: () {
                    print('Selected church: ${church.name}');
                    churchProvider.selectChurch(church.churchID);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChurchDetailScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
