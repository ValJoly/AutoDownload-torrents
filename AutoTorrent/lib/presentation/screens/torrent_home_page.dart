import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_session.dart';
import '../../data/models/torrent_item.dart';
import '../bloc/torrent_bloc.dart';
import '../bloc/torrent_event.dart';
import '../bloc/torrent_state.dart';

class TorrentHomePage extends StatefulWidget {
  const TorrentHomePage({required this.session, super.key});

  final AuthSession session;

  @override
  State<TorrentHomePage> createState() => _TorrentHomePageState();
}

class _TorrentHomePageState extends State<TorrentHomePage> {
  final _searchController = TextEditingController();
  String _library = 'audiobooks';
  String _source = 'tr4cker';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final sessionToken = widget.session.accessToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      context.read<TorrentBloc>().add(
        const SearchValidationFailed('Sign in to your bridge to search.'),
      );
      return;
    }
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      context.read<TorrentBloc>().add(
        const SearchValidationFailed(
          'Enter a title, author, or keyword to search.',
        ),
      );
      return;
    }

    context.read<TorrentBloc>().add(
      SearchRequested(
        widget.session.bridgeUrl,
        query,
        _library,
        sessionToken,
        source: _source,
      ),
    );
  }

  Future<void> _launch(TorrentItem torrent) async {
    final sessionToken = widget.session.accessToken;
    if (sessionToken == null || sessionToken.isEmpty) {
      context.read<TorrentBloc>().add(
        const SearchValidationFailed(
          'Sign in to your bridge to launch downloads.',
        ),
      );
      return;
    }
    context.read<TorrentBloc>().add(
      LaunchRequested(
        widget.session.bridgeUrl,
        torrent,
        _library,
        sessionToken,
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await widget.session.signOut();
    } catch (_) {
      // Local credentials are cleared even if the bridge cannot be reached.
    }
    if (mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TorrentBloc, TorrentState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 20,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 11),
                const Text(
                  'SkyForge',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () => context.push('/downloads'),
                tooltip: 'Download history',
                icon: Badge(
                  isLabelVisible: state.activeDownloadCount > 0,
                  label: Text(
                    state.activeDownloadCount > 99
                        ? '99+'
                        : '${state.activeDownloadCount}',
                  ),
                  child: const Icon(Icons.downloading_outlined),
                ),
              ),
              IconButton(
                onPressed: () => context.push('/free-books'),
                tooltip: 'Free books',
                icon: const Icon(Icons.menu_book_outlined),
              ),
              if (widget.session.isOwner)
                IconButton(
                  onPressed: () => context.go('/invites'),
                  tooltip: 'Manage invitations',
                  icon: const Icon(Icons.group_add_outlined),
                ),
              IconButton(
                onPressed: _signOut,
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'Find something to download',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Search a tracker and send a torrent to your home computer.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: 'Search titles, authors, or keywords',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            onPressed: state.loading ? null : _search,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Icon(
                            Icons.travel_explore_outlined,
                            size: 18,
                            color: Colors.black54,
                          ),
                          Text('Tracker', style: theme.textTheme.labelLarge),
                          ChoiceChip(
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor: Colors.transparent,
                            label: Text(
                              'TR4CKER',
                              style: TextStyle(
                                color: _source == 'tr4cker'
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            selected: _source == 'tr4cker',
                            onSelected: (_) =>
                                setState(() => _source = 'tr4cker'),
                          ),
                          ChoiceChip(
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor: Colors.transparent,
                            label: Text(
                              'C411',
                              style: TextStyle(
                                color: _source == 'c411'
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            selected: _source == 'c411',
                            onSelected: (_) => setState(() => _source = 'c411'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Icon(
                            Icons.folder_outlined,
                            size: 18,
                            color: Colors.black54,
                          ),
                          Text('Library', style: theme.textTheme.labelLarge),
                          ChoiceChip(
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor: Colors.transparent,
                            side: BorderSide(
                              color: state.library == 'audiobooks'
                                  ? Colors.transparent
                                  : Color(0xFFEAA4BD),
                              width: 1,
                            ),
                            label: Text(
                              'Audiobooks',
                              style: TextStyle(
                                color: state.library == 'audiobooks'
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: state.library == 'audiobooks'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: state.library == 'audiobooks',
                            onSelected: (_) {
                              setState(() => _library = 'audiobooks');
                              context.read<TorrentBloc>().add(
                                const LibraryChanged('audiobooks'),
                              );
                            },
                          ),
                          ChoiceChip(
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor: Colors.transparent,
                            side: BorderSide(
                              color: state.library == 'books'
                                  ? Colors.transparent
                                  : Color(0xFFEAA4BD),
                              width: 1,
                            ),
                            label: Text(
                              'Books',
                              style: TextStyle(
                                color: state.library == 'books'
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: state.library == 'books'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: state.library == 'books',
                            onSelected: (_) {
                              setState(() => _library = 'books');
                              context.read<TorrentBloc>().add(
                                const LibraryChanged('books'),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (state.loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (state.error != null)
                        _ErrorCard(message: state.error!, onRetry: _search)
                      else if (state.results.isEmpty)
                        const _EmptyState()
                      else ...[
                        Text(
                          '${state.results.length} results',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...state.results.map(
                          (torrent) => _TorrentCard(
                            torrent: torrent,
                            onLaunch: () => _launch(torrent),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TorrentCard extends StatelessWidget {
  const _TorrentCard({required this.torrent, required this.onLaunch});

  final TorrentItem torrent;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              torrent.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Stat(icon: Icons.sd_storage_outlined, text: torrent.size),
                _Stat(
                  icon: Icons.upload_outlined,
                  text: '${torrent.seeders} seeders',
                  color: Colors.green.shade700,
                ),
                _Stat(
                  icon: Icons.folder_copy_outlined,
                  text: '${torrent.files} files',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLaunch,
                icon: const Icon(Icons.download_rounded, size: 19),
                label: const Text('Download to computer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.color});
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
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
