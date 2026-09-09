import 'package:equatable/equatable.dart';

import '../../data/models/torrent_item.dart';

class TorrentState extends Equatable {
  const TorrentState({
    this.loading = false,
    this.library = 'audiobooks',
    this.results = const [],
    this.error,
  });

  final bool loading;
  final String library;
  final List<TorrentItem> results;
  final String? error;

  TorrentState copyWith({
    bool? loading,
    String? library,
    List<TorrentItem>? results,
    String? error,
  }) {
    return TorrentState(
      loading: loading ?? this.loading,
      library: library ?? this.library,
      results: results ?? this.results,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, library, results, error];
}
