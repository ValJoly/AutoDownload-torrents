import 'package:equatable/equatable.dart';

import '../../data/api/bridge_api.dart';
import '../../data/models/torrent_item.dart';

abstract class TorrentEvent extends Equatable {
  const TorrentEvent();

  @override
  List<Object?> get props => [];
}

class SearchRequested extends TorrentEvent {
  const SearchRequested(this.bridgeUrl, this.query, this.library);

  final String bridgeUrl;
  final String query;
  final String library;

  @override
  List<Object?> get props => [bridgeUrl, query, library];
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
  const LaunchRequested(this.bridgeUrl, this.torrent, this.library);

  final String bridgeUrl;
  final TorrentItem torrent;
  final String library;

  @override
  List<Object?> get props => [bridgeUrl, torrent, library];
}

class DownloadStatusRequested extends TorrentEvent {
  const DownloadStatusRequested(this.bridgeUrl, this.job);

  final String bridgeUrl;
  final DownloadJob job;

  @override
  List<Object?> get props => [bridgeUrl, job];
}
