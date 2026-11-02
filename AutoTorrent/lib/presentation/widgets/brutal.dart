import 'package:flutter/material.dart';

const brutalBorderWidth = 2.5;
const brutalRadius = 4.0;
const brutalShadowOffset = Offset(4, 4);

/// Outline and shadow colour: black on light themes, off-white on dark ones.
Color brutalInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFF5F0E6)
    : const Color(0xFF111111);

/// Marks a theme as the neubrutalism style. Widgets in this file fall back to
/// the classic rounded look when it is absent.
class BrutalStyle extends ThemeExtension<BrutalStyle> {
  const BrutalStyle();

  @override
  BrutalStyle copyWith() => const BrutalStyle();

  @override
  BrutalStyle lerp(BrutalStyle? other, double t) => this;
}

bool isBrutal(BuildContext context) =>
    Theme.of(context).extension<BrutalStyle>() != null;

/// [brutalRadius] in neubrutalism, otherwise the [classic] radius.
double cornerRadius(BuildContext context, double classic) =>
    isBrutal(context) ? brutalRadius : classic;

/// Thick ink outline in neubrutalism, none otherwise.
Border? brutalOutline(
  BuildContext context, {
  double width = brutalBorderWidth,
}) => isBrutal(context)
    ? Border.all(color: brutalInk(context), width: width)
    : null;

/// A flat box with a thick outline and a hard, un-blurred offset shadow.
/// Without the neubrutalism style it is a plain rounded card.
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
    final brutal = isBrutal(context);
    final ink = brutalInk(context);
    final theme = Theme.of(context);
    final base = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color == null ? base : Color.alphaBlend(color!, base),
          borderRadius: BorderRadius.circular(cornerRadius(context, 18)),
          border: brutalOutline(context),
          boxShadow: brutal
              ? [BoxShadow(color: ink, offset: shadowOffset)]
              : null,
        ),
        // Transparent Material so ListTiles/InkWells inside can still paint.
        child: Material(type: MaterialType.transparency, child: child),
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
  Widget build(BuildContext context) {
    final brutal = isBrutal(context);
    // Same tree in both styles so the field keeps its state when switching.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (brutal)
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
          padding: EdgeInsets.only(
            right: brutal ? 4 : 0,
            bottom: brutal ? 4 : 0,
          ),
          child: child,
        ),
      ],
    );
  }
}

class BrutalCard extends StatelessWidget {
  const BrutalCard({required this.child, this.color, this.margin, super.key});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => BrutalBox(
    color: color,
    margin:
        margin ??
        (isBrutal(context)
            ? const EdgeInsets.only(bottom: 14, right: 4)
            : const EdgeInsets.only(bottom: 12)),
    child: child,
  );
}
