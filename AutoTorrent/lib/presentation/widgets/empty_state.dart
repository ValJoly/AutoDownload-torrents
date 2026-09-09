import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 54),
        child: Column(
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 58,
              color: Theme.of(context).colorScheme.primary.withAlpha(150),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your search results will appear here',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            const Text(
              'The bridge must be running on your computer.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
}
