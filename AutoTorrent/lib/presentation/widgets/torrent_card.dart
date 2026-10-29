import 'package:flutter/material.dart';

import '../../data/models/torrent_item.dart';
import 'brutal.dart';
import 'stat.dart';

class TorrentCard extends StatelessWidget {
  const TorrentCard({super.key, required this.torrent, required this.onLaunch});

  final TorrentItem torrent;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BrutalCard(
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
                Stat(icon: Icons.sd_storage_outlined, text: torrent.size),
                Stat(
                  icon: Icons.upload_outlined,
                  text: '${torrent.seeders} seeders',
                  color: Colors.green.shade700,
                ),
                Stat(
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
