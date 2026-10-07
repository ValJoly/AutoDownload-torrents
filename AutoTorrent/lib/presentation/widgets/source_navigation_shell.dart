import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SourceNavigationShell extends StatelessWidget {
  const SourceNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _SourceDestination(label: 'TR4CKER', icon: Icons.travel_explore_outlined),
    _SourceDestination(label: 'C411', icon: Icons.public_outlined),
    _SourceDestination(label: 'Free books', icon: Icons.menu_book_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.outlineVariant.withAlpha(100)),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withAlpha(36),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  for (var index = 0; index < _destinations.length; index++)
                    Expanded(
                      child: _NavigationDestinationButton(
                        destination: _destinations[index],
                        selected: navigationShell.currentIndex == index,
                        onPressed: () => navigationShell.goBranch(
                          index,
                          initialLocation:
                              index == navigationShell.currentIndex,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationDestinationButton extends StatelessWidget {
  const _NavigationDestinationButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final _SourceDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOutCubic,
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOutCubic,
                  builder: (context, color, _) =>
                      Icon(destination.icon, color: color, size: 21),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOutCubic,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceDestination {
  const _SourceDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
