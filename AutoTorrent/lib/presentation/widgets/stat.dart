import 'package:flutter/material.dart';

class Stat extends StatelessWidget {
  const Stat({super.key, required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.black45),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color ?? Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}
