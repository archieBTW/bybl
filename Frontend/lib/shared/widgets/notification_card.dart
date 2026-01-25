import 'package:flutter/material.dart';

class NotificationCard extends StatelessWidget {
  final String title;
  final String content;
  final List<Widget> actions;
  final VoidCallback onDelete;

  const NotificationCard({super.key, 
    required this.title,
    required this.content,
    required this.actions,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.light
        ? theme.cardColor.withOpacity(0.9)
        : theme.cardColor.withOpacity(0.7);

    return Card(
      margin: const EdgeInsets.all(8.0),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ...actions],


            ),
          ],
        ),
      ),
    );
  }
}
