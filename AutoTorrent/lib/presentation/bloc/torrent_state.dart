import 'package:equatable/equatable.dart';

import '../../data/models/torrent_item.dart';
import '../../data/api/bridge_api.dart';

class TorrentState extends Equatable {
  const TorrentState({
    this.loading = false,
    this.library = 'audiobooks',
    this.results = const [],
    this.error,
    this.activeDownload,
  });

  final bool loading;
  final String library;
  final List<TorrentItem> results;
  final String? error;
  final DownloadJob? activeDownload;

  TorrentState copyWith({
    bool? loading,
    String? library,
    List<TorrentItem>? results,
    String? error,
    DownloadJob? activeDownload,
  }) {
    return TorrentState(
      loading: loading ?? this.loading,
      library: library ?? this.library,
      results: results ?? this.results,
      error: error,
      activeDownload: activeDownload ?? this.activeDownload,
    );
  }

  @override
  List<Object?> get props => [loading, library, results, error, activeDownload];
}
