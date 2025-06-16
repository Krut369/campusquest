import 'package:flutter/material.dart';

class SubmissionCard extends StatelessWidget {
  final String title;
  final String subject;
  final Color color;
  final IconData? icon; // Optional icon
  final VoidCallback? onTap; // Optional onTap callback

  const SubmissionCard({
    Key? key,
    required this.title,
    required this.subject,
    required this.color,
    this.icon, // Optional parameter
    this.onTap, // Optional parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Handle tap events if provided
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2), // Shadow for depth
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 24,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 12), // Space between icon and text
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis, // Handle long titles
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis, // Handle long subjects
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}