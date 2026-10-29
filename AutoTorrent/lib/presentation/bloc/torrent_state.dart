import 'package:equatable/equatable.dart';

import '../../data/models/torrent_item.dart';
import '../../data/api/bridge_api.dart';

const freeBooksSource = 'books';

class SearchPane extends Equatable {
  const SearchPane({
    this.loading = false,
    this.library = 'audiobooks',
    this.results = const [],
    this.legalResults = const [],
    this.error,
  });

  final bool loading;
  final String library;
  final List<TorrentItem> results;
  final List<LegalBook> legalResults;
  final String? error;

  SearchPane copyWith({
    bool? loading,
    String? library,
    List<TorrentItem>? results,
    List<LegalBook>? legalResults,
    String? error,
  }) {
    return SearchPane(
      loading: loading ?? this.loading,
      library: library ?? this.library,
      results: results ?? this.results,
      legalResults: legalResults ?? this.legalResults,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, library, results, legalResults, error];
}

class TorrentState extends Equatable {
  const TorrentState({
    this.panes = const {},
    this.downloads = const [],
    this.downloadsLoading = false,
    this.downloadsError,
  });

  final Map<String, SearchPane> panes;
  final List<DownloadJob> downloads;
  final bool downloadsLoading;
  final String? downloadsError;

  SearchPane pane(String source) => panes[source] ?? const SearchPane();

  int get activeDownloadCount =>
      downloads.where((job) => !job.isTerminal).length;

  bool get hasActiveDownloads => downloads.any((job) => !job.isTerminal);

  TorrentState withPane(String source, SearchPane Function(SearchPane) update) {
    return copyWith(panes: {...panes, source: update(pane(source))});
  }

  TorrentState copyWith({
    Map<String, SearchPane>? panes,
    List<DownloadJob>? downloads,
    bool? downloadsLoading,
    String? downloadsError,
  }) {
    return TorrentState(
      panes: panes ?? this.panes,
      downloads: downloads ?? this.downloads,
      downloadsLoading: downloadsLoading ?? this.downloadsLoading,
      downloadsError: downloadsError,
    );
  }

  @override
  List<Object?> get props => [
    panes,
    downloads,
    downloadsLoading,
    downloadsError,
  ];
}
