import 'package:equatable/equatable.dart';

import '../../data/api/bridge_api.dart';
import '../../data/models/torrent_item.dart';

abstract class TorrentEvent extends Equatable {
  const TorrentEvent();

  @override
  List<Object?> get props => [];
}

class SearchRequested extends TorrentEvent {
  const SearchRequested(
    this.bridgeUrl,
    this.query,
    this.library,
    this.sessionToken,
  );

  final String bridgeUrl;
  final String query;
  final String library;
  final String sessionToken;

  @override
  List<Object?> get props => [bridgeUrl, query, library, sessionToken];
}

class SearchValidationFailed extends TorrentEvent {
  const SearchValidationFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class LibraryChanged extends TorrentEvent {
  const LibraryChanged(this.library);

  final String library;

  @override
  List<Object?> get props => [library];
}

class LaunchRequested extends TorrentEvent {
  const LaunchRequested(
    this.bridgeUrl,
    this.torrent,
    this.library,
    this.sessionToken,
  );

  final String bridgeUrl;
  final TorrentItem torrent;
  final String library;
  final String sessionToken;

  @override
  List<Object?> get props => [bridgeUrl, torrent, library, sessionToken];
}

class DownloadStatusRequested extends TorrentEvent {
  const DownloadStatusRequested(this.bridgeUrl, this.job, this.sessionToken);

  final String bridgeUrl;
  final DownloadJob job;
  final String sessionToken;

  @override
  List<Object?> get props => [bridgeUrl, job, sessionToken];
}

class DownloadsFetched extends TorrentEvent {
  const DownloadsFetched(
    this.bridgeUrl,
    this.sessionToken, {
    this.showLoading = false,
  });

  final String bridgeUrl;
  final String sessionToken;
  final bool showLoading;

  @override
  List<Object?> get props => [bridgeUrl, sessionToken, showLoading];
}
