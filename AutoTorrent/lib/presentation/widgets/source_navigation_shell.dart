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
          margin: const EdgeInsets.fromLTRB(14, 6, 18, 12),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              spacing: 6,
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
    final colors = Theme.of(context).colorScheme;
    final ink = brutalInk(context);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: onPressed,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          borderRadius: BorderRadius.circular(brutalRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(brutalRadius - 1),
              border: Border.all(
                color: selected ? ink : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  destination.icon,
                  color: selected ? colors.onPrimary : ink,
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: selected ? colors.onPrimary : ink,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
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
