import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_session.dart';

class SourceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SourceAppBar({
    required this.session,
    required this.activeDownloadCount,
    super.key,
  });

  final AuthSession session;
  final int activeDownloadCount;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _signOut(BuildContext context) async {
    try {
      await session.signOut();
    } catch (_) {
      // Local credentials are cleared even if the bridge cannot be reached.
    }
    if (context.mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.bolt,
              color: theme.colorScheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'SkyForge',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/downloads'),
          tooltip: 'Download history',
          icon: Badge(
            isLabelVisible: activeDownloadCount > 0,
            label: Text(
              activeDownloadCount > 99 ? '99+' : '$activeDownloadCount',
            ),
            child: const Icon(Icons.downloading_outlined),
          ),
        ),
        IconButton(
          onPressed: () => context.push('/settings'),
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
        ),
        if (session.isOwner)
          IconButton(
            onPressed: () => context.go('/invites'),
            tooltip: 'Manage invitations',
            icon: const Icon(Icons.group_add_outlined),
          ),
        IconButton(
          onPressed: () => _signOut(context),
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}
