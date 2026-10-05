import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:async';

import '../../data/api/bridge_api.dart';
import 'torrent_event.dart';
import 'torrent_state.dart';

class TorrentBloc extends Bloc<TorrentEvent, TorrentState> {
  TorrentBloc(
    this._api, {
    this._onUnauthorized,
    String? initialBridgeUrl,
    String? initialSessionToken,
  }) : super(const TorrentState()) {
    on<SearchRequested>(_onSearchRequested);
    on<LegalBooksSearchRequested>(_onLegalBooksSearchRequested);
    on<SearchValidationFailed>(_onSearchValidationFailed);
    on<LibraryChanged>(_onLibraryChanged);
    on<LaunchRequested>(_onLaunchRequested);
    on<LegalBookDownloadRequested>(_onLegalBookDownloadRequested);
    on<DownloadStatusRequested>(_onDownloadStatusRequested);
    on<DownloadsFetched>(_onDownloadsFetched);
    if (initialBridgeUrl?.isNotEmpty == true &&
        initialSessionToken?.isNotEmpty == true) {
      add(
        DownloadsFetched(
          initialBridgeUrl!,
          initialSessionToken!,
          showLoading: true,
        ),
      );
    }
  }

  final BridgeApi _api;
  final Future<void> Function()? _onUnauthorized;
  Timer? _statusTimer;

  Future<void> _invalidateUnauthorized(Object error) async {
    if (error is BridgeException && error.statusCode == 401) {
      await _onUnauthorized?.call();
    }
  }

  List<DownloadJob> _withJob(List<DownloadJob> jobs, DownloadJob replacement) {
    final next = jobs.where((job) => job.id != replacement.id).toList()
      ..add(replacement);
    next.sort((a, b) {
      final aDate =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return next;
  }

  void _syncPolling(
    String bridgeUrl,
    String sessionToken, {
    bool immediate = false,
  }) {
    if (!state.hasActiveDownloads) {
      _statusTimer?.cancel();
      _statusTimer = null;
      return;
    }
    _statusTimer?.cancel();
    if (immediate) add(DownloadsFetched(bridgeUrl, sessionToken));
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      add(DownloadsFetched(bridgeUrl, sessionToken));
    });
  }

  Future<void> _onDownloadsFetched(
    DownloadsFetched event,
    Emitter<TorrentState> emit,
  ) async {
    if (event.showLoading) {
      emit(state.copyWith(downloadsLoading: true, downloadsError: null));
    }
    try {
      final downloads = await _api.listDownloads(
        event.bridgeUrl,
        event.sessionToken,
      );
      emit(
        state.copyWith(
          downloads: downloads,
          downloadsLoading: false,
          downloadsError: null,
        ),
      );
      _syncPolling(event.bridgeUrl, event.sessionToken);
    } catch (error) {
      await _invalidateUnauthorized(error);
      if (event.showLoading) {
        emit(
          state.copyWith(
            downloadsLoading: false,
            downloadsError: error is BridgeException ? error.message : 'Could not load download history. Check the bridge connection.',
          ),
        );
      }
      // Keep the last known download list when a refresh is temporarily unavailable.
    }
  }

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
        event.sessionToken,
        source: event.source,
      );
      emit(state.copyWith(loading: false, results: results, error: null));
    } catch (error) {
      await _invalidateUnauthorized(error);
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

  Future<void> _onLegalBooksSearchRequested(
    LegalBooksSearchRequested event,
    Emitter<TorrentState> emit,
  ) async {
    emit(state.copyWith(loading: true, error: null, legalResults: const []));
    try {
      final results = await _api.searchLegalBooks(
        event.bridgeUrl,
        event.query,
        event.language,
        event.sessionToken,
        gutenbergOnly: event.gutenbergOnly,
      );
      emit(state.copyWith(loading: false, legalResults: results, error: null));
    } catch (error) {
      await _invalidateUnauthorized(error);
      emit(
        state.copyWith(
          loading: false,
          error: error is BridgeException
              ? error.message
              : 'Could not search the legal-books catalog.',
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
    emit(state.copyWith(error: null));
    try {
      final job = await _api.launch(
        event.bridgeUrl,
        event.torrent.slug,
        event.library,
        event.sessionToken,
        source: event.torrent.source,
      );
      emit(
        state.copyWith(error: null, downloads: _withJob(state.downloads, job)),
      );
      _syncPolling(event.bridgeUrl, event.sessionToken, immediate: true);
    } catch (error) {
      await _invalidateUnauthorized(error);
      emit(
        state.copyWith(
          error: error is BridgeException
              ? error.message
              : 'Could not start the download on the computer.',
        ),
      );
      if (error is! BridgeException || error.statusCode != 401) {
        add(DownloadsFetched(event.bridgeUrl, event.sessionToken));
      }
    }
  }

  Future<void> _onLegalBookDownloadRequested(
    LegalBookDownloadRequested event,
    Emitter<TorrentState> emit,
  ) async {
    emit(state.copyWith(error: null));
    try {
      final job = await _api.downloadLegalBook(
        event.bridgeUrl,
        event.book.id,
        event.format,
        event.sessionToken,
      );
      emit(state.copyWith(downloads: _withJob(state.downloads, job)));
      _syncPolling(event.bridgeUrl, event.sessionToken);
    } catch (error) {
      await _invalidateUnauthorized(error);
      emit(
        state.copyWith(
          error: error is BridgeException
              ? error.message
              : 'Could not start the book download on the bridge.',
        ),
      );
    }
  }

  Future<void> _onDownloadStatusRequested(
    DownloadStatusRequested event,
    Emitter<TorrentState> emit,
  ) async {
    try {
      final job = await _api.downloadStatus(
        event.bridgeUrl,
        event.job.id,
        event.sessionToken,
      );
      emit(state.copyWith(downloads: _withJob(state.downloads, job)));
      _syncPolling(event.bridgeUrl, event.sessionToken);
    } catch (error) {
      await _invalidateUnauthorized(error);
      // Keep the last known state while a single status poll is unavailable.
    }
  }

  @override
  Future<void> close() {
    _statusTimer?.cancel();
    return super.close();
  }
}
