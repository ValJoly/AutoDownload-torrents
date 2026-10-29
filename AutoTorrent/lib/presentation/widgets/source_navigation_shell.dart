import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'brutal.dart';

class SourceNavigationShell extends StatelessWidget {
  const SourceNavigationShell({
    required this.navigationShell,
    required this.availableProviders,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final Set<String> availableProviders;

  static const _destinations = [
    _SourceDestination(
      label: 'TR4CKER',
      icon: Icons.travel_explore_outlined,
      branchIndex: 0,
      provider: 'tr4cker',
    ),
    _SourceDestination(
      label: 'C411',
      icon: Icons.public_outlined,
      branchIndex: 1,
      provider: 'c411',
    ),
    _SourceDestination(
      label: 'Free books',
      icon: Icons.menu_book_outlined,
      branchIndex: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations
        .where(
          (destination) =>
              destination.provider == null ||
              availableProviders.contains(destination.provider),
        )
        .toList();

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: BrutalBox(
          margin: isBrutal(context)
              ? const EdgeInsets.fromLTRB(14, 6, 18, 12)
              : const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Padding(
            padding: EdgeInsets.all(isBrutal(context) ? 6 : 5),
            child: Row(
              spacing: isBrutal(context) ? 6 : 0,
              children: [
                for (final destination in destinations)
                  Expanded(
                    child: _NavigationDestinationButton(
                      destination: destination,
                      selected:
                          navigationShell.currentIndex ==
                          destination.branchIndex,
                      onPressed: () => navigationShell.goBranch(
                        destination.branchIndex,
                        initialLocation:
                            destination.branchIndex ==
                            navigationShell.currentIndex,
                      ),
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
    final brutal = isBrutal(context);
    final colors = Theme.of(context).colorScheme;
    final ink = brutalInk(context);
    final fill = brutal ? colors.primary : colors.primaryContainer;
    final onFill = brutal ? colors.onPrimary : colors.onPrimaryContainer;
    final idle = brutal ? ink : colors.onSurfaceVariant;
    final radius = cornerRadius(context, 24);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: onPressed,
          splashColor: brutal ? Colors.transparent : null,
          highlightColor: brutal ? Colors.transparent : null,
          hoverColor: brutal ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: brutal ? 50 : 58,
            padding: EdgeInsets.symmetric(horizontal: brutal ? 6 : 8),
            decoration: BoxDecoration(
              color: selected ? fill : Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
              border: brutal
                  ? Border.all(
                      color: selected ? ink : Colors.transparent,
                      width: 2,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  destination.icon,
                  color: selected ? onFill : idle,
                  size: brutal ? 20 : 21,
                ),
                SizedBox(height: brutal ? 2 : 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: selected ? onFill : idle,
                    fontWeight: brutal || selected
                        ? FontWeight.w800
                        : FontWeight.w500,
                    height: brutal ? 1.1 : null,
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
  const _SourceDestination({
    required this.label,
    required this.icon,
    required this.branchIndex,
    this.provider,
  });

  final String label;
  final IconData icon;
  final int branchIndex;
  final String? provider;
}
