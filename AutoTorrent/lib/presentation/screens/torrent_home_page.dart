import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_keys.dart';
import '../../data/api/bridge_api.dart';
import '../../data/models/torrent_item.dart';
import '../bloc/torrent_bloc.dart';
import '../bloc/torrent_event.dart';
import '../bloc/torrent_state.dart';

class TorrentHomePage extends StatefulWidget {
  const TorrentHomePage({super.key});

  @override
  State<TorrentHomePage> createState() => _TorrentHomePageState();
}

class _TorrentHomePageState extends State<TorrentHomePage> {
  final _bridgeController = TextEditingController(
    text: 'http://192.168.1.72:8384',
  );
  final _searchController = TextEditingController();
  String _library = 'audiobooks';

  @override
  void dispose() {
    _bridgeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
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
      SearchRequested(_bridgeController.text, query, _library),
    );
  }

  Future<void> _launch(TorrentItem torrent) async {
    context.read<TorrentBloc>().add(
      LaunchRequested(_bridgeController.text, torrent, _library),
    );
  }

  Future<void> _showSettings() async {
    final controller = TextEditingController(text: _bridgeController.text);
    final rootContext = AppKeys.navigatorKey.currentContext;
    if (rootContext == null) {
      return;
    }

    await showDialog<void>(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bridge connection'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Bridge URL',
            hintText: 'http://192.168.1.72:8384',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) _bridgeController.text = value;
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
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
                  'AutoTorrent',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _showSettings,
                tooltip: 'Bridge settings',
                icon: const Icon(Icons.tune_rounded),
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
                        'Search through TR4CKER and send a torrent to your home computer.',
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
                      Row(
                        children: [
                          const Icon(
                            Icons.folder_outlined,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Text('Save to', style: theme.textTheme.labelLarge),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Audiobooks'),
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
                            label: const Text('Books'),
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
                      if (state.activeDownload != null) ...[
                        _DownloadStatusCard(job: state.activeDownload!),
                        const SizedBox(height: 20),
                      ],
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

class _DownloadStatusCard extends StatelessWidget {
  const _DownloadStatusCard({required this.job});

  final DownloadJob job;

  @override
  Widget build(BuildContext context) {
    final completed = job.status == 'completed';
    final failed = job.status == 'failed';
    final color = failed
        ? Theme.of(context).colorScheme.error
        : completed
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      color: color.withAlpha(22),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              failed
                  ? Icons.error_outline
                  : completed
                  ? Icons.check_circle_outline
                  : Icons.downloading_rounded,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (!completed && !failed) ...[
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: job.progress,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ],
              ),
            ),
            if (job.progress != null)
              Text('${(job.progress! * 100).round()}%'),
          ],
        ),
      ),
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
