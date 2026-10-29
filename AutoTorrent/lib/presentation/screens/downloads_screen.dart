import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_session.dart';
import '../../data/api/bridge_api.dart';
import '../bloc/torrent_bloc.dart';
import '../bloc/torrent_event.dart';
import '../bloc/torrent_state.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({required this.session, super.key});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TorrentBloc, TorrentState>(
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: const Text('Downloads'),
          actions: [
            IconButton(
              onPressed: () => context.push('/settings'),
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: 'Refresh downloads',
              onPressed: state.downloadsLoading || session.accessToken == null
                  ? null
                  : () => context.read<TorrentBloc>().add(
                      DownloadsFetched(
                        session.bridgeUrl,
                        session.accessToken!,
                        showLoading: true,
                      ),
                    ),
              icon: state.downloadsLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: state.downloadsLoading && state.downloads.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.downloadsError != null && state.downloads.isEmpty
              ? _HistoryError(message: state.downloadsError!)
              : state.downloads.isEmpty
              ? const _HistoryEmpty()
              : RefreshIndicator(
                  onRefresh: () async {
                    final token = session.accessToken;
                    if (token != null) {
                      context.read<TorrentBloc>().add(
                        DownloadsFetched(
                          session.bridgeUrl,
                          token,
                          showLoading: true,
                        ),
                      );
                      await context.read<TorrentBloc>().stream.firstWhere(
                        (next) => !next.downloadsLoading,
                      );
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (state.downloadsError != null)
                        _HistoryError(message: state.downloadsError!),
                      ...state.downloads.map(
                        (job) => _DownloadHistoryItem(job: job),
                      ),
                    ],
                  ),
                ),
        ),
        floatingActionButton: state.downloadsError != null
            ? FloatingActionButton.small(
                tooltip: 'Retry loading downloads',
                onPressed: session.accessToken == null
                    ? null
                    : () => context.read<TorrentBloc>().add(
                        DownloadsFetched(
                          session.bridgeUrl,
                          session.accessToken!,
                          showLoading: true,
                        ),
                      ),
                child: const Icon(Icons.refresh),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
    );
  }
}

class _DownloadHistoryItem extends StatelessWidget {
  const _DownloadHistoryItem({required this.job});

  final DownloadJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = job.status == 'completed';
    final failed = job.status == 'failed' || job.status == 'interrupted';
    final color = failed
        ? theme.colorScheme.error
        : completed
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: color.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  failed
                      ? Icons.error_outline
                      : completed
                      ? Icons.check_circle_outline
                      : job.isTerminal
                      ? Icons.open_in_new
                      : Icons.downloading_rounded,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    job.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (job.progress != null)
                  Text('${(job.progress! * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                job.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (job.message != null) ...[
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(job.message!, style: theme.textTheme.bodySmall),
              ),
            ],
            if (!job.isTerminal) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: job.progress,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 3,
                children: [
                  if (job.totalBytes != null)
                    Text(
                      '${_formatBytes(job.downloadedBytes)} of ${_formatBytes(job.totalBytes!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (job.downloadSpeed > 0)
                    Text(
                      '${_formatBytes(job.downloadSpeed)}/s',
                      style: theme.textTheme.bodySmall,
                    ),
                  if (job.etaSeconds != null)
                    Text(
                      '${job.etaSeconds}s remaining',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Text('No downloads yet.'),
    ),
  );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}
