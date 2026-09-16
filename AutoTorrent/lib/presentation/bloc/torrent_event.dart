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
    this.username,
    this.password,
  );

  final String bridgeUrl;
  final String query;
  final String library;
  final String username;
  final String password;

  @override
  List<Object?> get props => [
    bridgeUrl,
    query,
    library,
    username,
    password,
  ];
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
    this.username,
    this.password,
  );

  final String bridgeUrl;
  final TorrentItem torrent;
  final String library;
  final String username;
  final String password;

  @override
  List<Object?> get props => [bridgeUrl, torrent, library, username, password];
}

class DownloadStatusRequested extends TorrentEvent {
  const DownloadStatusRequested(
    this.bridgeUrl,
    this.job,
    this.username,
    this.password,
  );

  final String bridgeUrl;
  final DownloadJob job;
  final String username;
  final String password;

  @override
  List<Object?> get props => [bridgeUrl, job, username, password];
}
