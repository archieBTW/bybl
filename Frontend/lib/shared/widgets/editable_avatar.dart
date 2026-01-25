import 'package:flutter/material.dart';

class EditableAvatar extends StatelessWidget {
  final double radius;
  final String? imageUrl;
  final IconData fallbackIcon;
  final VoidCallback? onEdit;

  const EditableAvatar({
    Key? key,
    required this.radius,
    required this.imageUrl,
    required this.fallbackIcon,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          key: ValueKey(imageUrl),
          radius: radius,
          backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
              ? NetworkImage(imageUrl!)
              : null,
          child: (imageUrl == null || imageUrl!.isEmpty)
              ? Icon(fallbackIcon, size: radius)
              : null,
        ),
        if (this.onEdit != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor,
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.edit, size: 18, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
