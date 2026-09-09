import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/api/bridge_api.dart';
import 'torrent_event.dart';
import 'torrent_state.dart';

class TorrentBloc extends Bloc<TorrentEvent, TorrentState> {
  TorrentBloc(this._api) : super(const TorrentState()) {
    on<SearchRequested>(_onSearchRequested);
    on<SearchValidationFailed>(_onSearchValidationFailed);
    on<LibraryChanged>(_onLibraryChanged);
  }

  final BridgeApi _api;

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
}
