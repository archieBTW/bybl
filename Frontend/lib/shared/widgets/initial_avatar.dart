import 'package:flutter/material.dart';

class InitialAvatar extends StatelessWidget {
  final String username;
  final double radius;

  const InitialAvatar({
    Key? key,
    required this.username,
    this.radius = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final initial =
        username.trim().isNotEmpty ? username.trim()[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[400],
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
