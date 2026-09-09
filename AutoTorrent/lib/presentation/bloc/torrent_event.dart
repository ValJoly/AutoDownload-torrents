import 'package:equatable/equatable.dart';

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
