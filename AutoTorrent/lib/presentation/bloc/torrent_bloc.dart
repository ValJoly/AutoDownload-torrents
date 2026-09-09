import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

import '../../data/api/bridge_api.dart';
import 'torrent_event.dart';
import 'torrent_state.dart';

class TorrentBloc extends Bloc<TorrentEvent, TorrentState> {
  TorrentBloc(this._api) : super(const TorrentState()) {
    on<SearchRequested>(_onSearchRequested);
    on<SearchValidationFailed>(_onSearchValidationFailed);
    on<LibraryChanged>(_onLibraryChanged);
    on<LaunchRequested>(_onLaunchRequested);
    on<DownloadStatusRequested>(_onDownloadStatusRequested);
  }

  final BridgeApi _api;
  Timer? _statusTimer;

  Future<void> _onSearchRequested(
    SearchRequested event,
    Emitter<TorrentState> emit,
  ) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final results = await _api.search(
        event.bridgeUrl,
        event.query,
        event.library,
      );
      emit(state.copyWith(loading: false, results: results, error: null));
    } catch (error) {
      emit(
        state.copyWith(
          loading: false,
          error: error is BridgeException
              ? error.message
              : 'Could not reach the bridge. Check its address and connection.',
        ),
      );
    }
  }

  void _onSearchValidationFailed(
    SearchValidationFailed event,
    Emitter<TorrentState> emit,
  ) {
    emit(state.copyWith(loading: false, error: event.message));
  }

  void _onLibraryChanged(LibraryChanged event, Emitter<TorrentState> emit) {
    emit(state.copyWith(library: event.library, error: null));
  }

  Future<void> _onLaunchRequested(
    LaunchRequested event,
    Emitter<TorrentState> emit,
  ) async {
    try {
      final job = await _api.launch(
        event.bridgeUrl,
        event.torrent.slug,
        event.library,
      );
      emit(state.copyWith(error: null, activeDownload: job));
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        add(DownloadStatusRequested(event.bridgeUrl, job));
      });
    } catch (error) {
      emit(
        state.copyWith(
          error: error is BridgeException
              ? error.message
              : 'Could not start the download on the computer.',
        ),
      );
    }
  }

  Future<void> _onDownloadStatusRequested(
    DownloadStatusRequested event,
    Emitter<TorrentState> emit,
  ) async {
    try {
      final job = await _api.downloadStatus(event.bridgeUrl, event.job.id);
      emit(state.copyWith(activeDownload: job));
      if (job.status == 'completed' || job.status == 'failed') {
        _statusTimer?.cancel();
      }
    } catch (_) {
      // Keep the last known state while a single status poll is unavailable.
    }
  }

  @override
  Future<void> close() {
    _statusTimer?.cancel();
    return super.close();
  }
}
