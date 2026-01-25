import 'package:TheWord/services/streak_service.dart';
import 'package:flutter/material.dart';

class StreakWidget extends StatefulWidget {
  final StreakService service;
  const StreakWidget({super.key, required this.service});

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget> {
  int currentStreak = 0;
  int highestStreak = 0;
  String? lastRead;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    try {
      final data = await widget.service.getStreak();
      setState(() {
        currentStreak = data['streak'];
        highestStreak = data['highest_streak'];
        lastRead = data['last_read'];
      });
    } catch (e) {
      print('Error loading streak: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📅 Bible Reading Streak',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('🔥 Current: $currentStreak'),
            Text('🏆 Highest: $highestStreak'),
            if (lastRead != null) Text('🕓 Last read: $lastRead'),
          ],
        ),
      ),
    );
  }
}
