import 'package:flutter/material.dart';

import 'brutal.dart';

class BookCover extends StatelessWidget {
  const BookCover({super.key, this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 64,
      height: 96,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book_outlined),
    );
    final cover = url;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(brutalRadius),
        border: Border.all(color: brutalInk(context), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(brutalRadius),
        child: cover == null
            ? placeholder
            : Image.network(
                cover,
                width: 64,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
