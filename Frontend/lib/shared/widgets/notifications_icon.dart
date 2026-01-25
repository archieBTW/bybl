import 'package:TheWord/providers/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotificationIcon extends StatefulWidget {
  final Color fontColor;

  const NotificationIcon({Key? key, required this.fontColor}) : super(key: key);

  @override
  _NotificationIconState createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.8,
      upperBound: 1.2,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final unreadCount = notificationProvider.unreadCount;

    // Play pop animation when unreadCount changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (unreadCount > 0) {
        _controller.forward().then((_) => _controller.reverse());
      }
    });

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.notifications, color: widget.fontColor),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: AnimatedScale(
              scale: _controller.value,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
