import 'package:flutter/material.dart';

class StatusBar extends StatelessWidget {
  final int pendingCount;
  final int ongoingCount;
  final int completedCount;

  const StatusBar({
    Key? key,
    required this.pendingCount,
    required this.ongoingCount,
    required this.completedCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusCard(
            label: 'Pending',
            count: pendingCount,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusCard(
            label: 'Ongoing',
            count: ongoingCount,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatusCard(
            label: 'Completed',
            count: completedCount,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusCard({
    Key? key,
    required this.label,
    required this.count,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.shade100,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

extension on Color {
  get shade100 => null;
}

// Usage Example:
// StatusBar(
//   pendingCount: 5,
//   ongoingCount: 3,
//   completedCount: 10,
// )
