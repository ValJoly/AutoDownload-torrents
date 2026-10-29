import 'package:flutter/material.dart';

const brutalBorderWidth = 2.5;
const brutalRadius = 4.0;
const brutalShadowOffset = Offset(4, 4);

/// Outline and shadow colour: black on light themes, off-white on dark ones.
Color brutalInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFF5F0E6)
    : const Color(0xFF111111);

/// A flat box with a thick outline and a hard, un-blurred offset shadow.
class BrutalBox extends StatelessWidget {
  const BrutalBox({
    required this.child,
    this.color,
    this.margin = EdgeInsets.zero,
    this.shadowOffset = brutalShadowOffset,
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry margin;
  final Offset shadowOffset;

  @override
  Widget build(BuildContext context) {
    final ink = brutalInk(context);
    final theme = Theme.of(context);
    final base = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color == null ? base : Color.alphaBlend(color!, base),
          borderRadius: BorderRadius.circular(brutalRadius),
          border: Border.all(color: ink, width: brutalBorderWidth),
          boxShadow: [BoxShadow(color: ink, offset: shadowOffset)],
        ),
        child: child,
      ),
    );
  }
}

/// Gives a single-line text field a hard offset shadow. The shadow has the
/// default field height so validation messages below it stay clear.
class BrutalField extends StatelessWidget {
  const BrutalField({required this.child, super.key});

  static const _fieldHeight = 56.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: brutalShadowOffset.dx,
        top: brutalShadowOffset.dy,
        right: 0,
        height: _fieldHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: brutalInk(context),
            borderRadius: BorderRadius.circular(brutalRadius),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4),
        child: child,
      ),
    ],
  );
}

class BrutalCard extends StatelessWidget {
  const BrutalCard({
    required this.child,
    this.color,
    this.margin = const EdgeInsets.only(bottom: 14, right: 4),
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) =>
      BrutalBox(color: color, margin: margin, child: child);
}
