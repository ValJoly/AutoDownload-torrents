import 'package:flutter/material.dart';

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ],
      ),
    ),
  );
}
