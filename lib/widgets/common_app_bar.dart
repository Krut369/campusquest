import 'package:flutter/material.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String userEmail;
  final VoidCallback? onNotificationPressed;

  const CommonAppBar({
    Key? key,
    required this.title,
    required this.userEmail,
    this.onNotificationPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        Row(
          children: [
            // Display user email
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                userEmail,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            // Notification icon
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.black),
              onPressed: onNotificationPressed,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}