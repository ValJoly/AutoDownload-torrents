import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/auth_session.dart';
import '../../data/models/torrent_item.dart';
import '../bloc/torrent_bloc.dart';
import '../bloc/torrent_event.dart';
import '../bloc/torrent_state.dart';
import '../widgets/book_cover.dart';
import '../widgets/source_app_bar.dart';

class TorrentHomePage extends StatefulWidget {
  const TorrentHomePage({
    required this.session,
    required this.source,
    super.key,
  });

  final AuthSession session;
  final String source;

  @override
  State<TorrentHomePage> createState() => _TorrentHomePageState();
}

class _TorrentHomePageState extends State<TorrentHomePage> {
  final _searchController = TextEditingController();
  String _library = 'audiobooks';

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
        source: widget.source,
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
        source: widget.source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TorrentBloc, TorrentState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: SourceAppBar(
            session: widget.session,
            activeDownloadCount: state.activeDownloadCount,
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
                        'Search ${widget.source.toUpperCase()} and send a torrent to your home computer.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
                      SingleChildScrollView(
                        key: const Key('library-selector-scroll'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text('Library', style: theme.textTheme.labelLarge),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: Colors.transparent,
                              side: BorderSide(
                                color: state.library == 'audiobooks'
                                    ? Colors.transparent
                                    : theme.colorScheme.primary,
                                width: 1,
                              ),
                              label: Text(
                                'Audiobooks',
                                style: TextStyle(
                                  color: state.library == 'audiobooks'
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
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
                            const SizedBox(width: 8),
                            ChoiceChip(
                              selectedColor: theme.colorScheme.primary,
                              backgroundColor: Colors.transparent,
                              side: BorderSide(
                                color: state.library == 'books'
                                    ? Colors.transparent
                                    : theme.colorScheme.primary,
                                width: 1,
                              ),
                              label: Text(
                                'Books',
                                style: TextStyle(
                                  color: state.library == 'books'
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
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
                            session: widget.session,
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

class _TorrentCard extends StatefulWidget {
  const _TorrentCard({
    required this.torrent,
    required this.session,
    required this.onLaunch,
  });

  final TorrentItem torrent;
  final AuthSession session;
  final VoidCallback onLaunch;

  @override
  State<_TorrentCard> createState() => _TorrentCardState();
}

class _TorrentCardState extends State<_TorrentCard> {
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.torrent.coverUrl;
    if (_coverUrl == null) _loadCover();
  }

  Future<void> _loadCover() async {
    final token = widget.session.accessToken;
    if (token == null || token.isEmpty) return;
    final url = await widget.session.api.coverUrl(
      widget.session.bridgeUrl,
      widget.torrent.name,
      token,
    );
    if (mounted && url != null) setState(() => _coverUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final torrent = widget.torrent;
    final onLaunch = widget.onLaunch;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(url: _coverUrl),
            const SizedBox(width: 12),
            Expanded(
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
                      _Stat(
                        icon: Icons.sd_storage_outlined,
                        text: torrent.size,
                      ),
                      _Stat(
                        icon: Icons.upload_outlined,
                        text: '${torrent.seeders} seeders',
                        color: Theme.of(context).colorScheme.tertiary,
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
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? mutedColor),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color ?? mutedColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
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
        Text(
          'The bridge must be running on your computer.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
