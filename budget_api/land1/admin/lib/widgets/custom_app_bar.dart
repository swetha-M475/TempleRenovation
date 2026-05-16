import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBackPressed;
  final Widget? trailing;
  final List<Widget>? additionalContent;

  const CustomAppBar({
    Key? key,
    required this.title,
    this.subtitle,
    this.onBackPressed,
    this.trailing,
    this.additionalContent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onBackPressed != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: onBackPressed,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    const SizedBox.shrink(),
                  if (trailing != null) trailing!,
                ],
              ),
              if (onBackPressed != null) const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: Color(0xFFC7D2FE),
                    fontSize: 14,
                  ),
                ),
              ],
              if (additionalContent != null) ...[
                const SizedBox(height: 16),
                ...additionalContent!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Usage Example:
// CustomAppBar(
//   title: 'Dashboard',
//   subtitle: 'Manage Projects & Users',
//   trailing: NotificationBell(),
//   additionalContent: [TabBar()],
// )
