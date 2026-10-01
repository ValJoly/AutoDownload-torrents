import 'package:auto_torrent/core/auth_session.dart';
import 'package:auto_torrent/data/api/bridge_api.dart';
import 'package:auto_torrent/presentation/bloc/torrent_bloc.dart';
import 'package:auto_torrent/presentation/bloc/torrent_event.dart';
import 'package:auto_torrent/presentation/screens/downloads_screen.dart';
import 'package:auto_torrent/presentation/screens/torrent_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _DownloadsApi extends BridgeApi {
  _DownloadsApi(this.downloads, {this.error});

  final List<DownloadJob> downloads;
  Object? error;
  String? requestedBridgeUrl;
  String? requestedSessionToken;

  @override
  Future<List<DownloadJob>> listDownloads(
    String bridgeUrl,
    String sessionToken,
  ) async {
    requestedBridgeUrl = bridgeUrl;
    requestedSessionToken = sessionToken;
    if (error != null) throw error!;
    return downloads;
  }
}

void main() {
  test(
    'loads saved downloads when created with an authenticated session',
    () async {
      final api = _DownloadsApi([
        const DownloadJob(
          id: 'job-1',
          slug: 'book-one',
          info: 'Book One',
          status: 'completed',
        ),
        const DownloadJob(
          id: 'job-2',
          slug: 'book-two',
          info: 'Book Two',
          status: 'interrupted',
        ),
      ]);
      final bloc = TorrentBloc(
        api,
        initialBridgeUrl: 'http://bridge.local',
        initialSessionToken: 'session-token',
      );

      final state = await bloc.stream.firstWhere(
        (state) => state.downloads.length == 2,
      );

      expect(state.downloads.map((job) => job.id), ['job-1', 'job-2']);
      expect(api.requestedBridgeUrl, 'http://bridge.local');
      expect(api.requestedSessionToken, 'session-token');
      await bloc.close();
    },
  );

  test('manual history refresh reports recoverable errors', () async {
    final api = _DownloadsApi(
      const [],
      error: BridgeException('History is temporarily unavailable.'),
    );
    final bloc = TorrentBloc(api);
    bloc.add(
      const DownloadsFetched(
        'http://bridge.local',
        'session-token',
        showLoading: true,
      ),
    );

    final state = await bloc.stream.firstWhere(
      (state) => state.downloadsError != null,
    );

    expect(state.downloadsLoading, isFalse);
    expect(state.downloadsError, 'History is temporarily unavailable.');
    await bloc.close();
  });

  testWidgets('history page shows each saved download and its status', (
    tester,
  ) async {
    final api = _DownloadsApi([
      const DownloadJob(
        id: 'job-1',
        slug: 'book-one',
        info: 'Book One',
        status: 'completed',
      ),
      const DownloadJob(
        id: 'job-2',
        slug: 'book-two',
        info: 'Book Two',
        status: 'failed',
      ),
    ]);
    final session = AuthSession(api: api)
      ..bridgeUrl = 'http://bridge.local'
      ..accessToken = 'session-token';
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => TorrentBloc(
          api,
          initialBridgeUrl: session.bridgeUrl,
          initialSessionToken: session.accessToken,
        ),
        child: MaterialApp(home: DownloadsScreen(session: session)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Book One'), findsOneWidget);
    expect(find.text('Book Two'), findsOneWidget);
    expect(find.text('Download completed'), findsOneWidget);
    expect(find.text('Download failed'), findsOneWidget);
  });

  testWidgets('history page shows an empty state when no jobs exist', (
    tester,
  ) async {
    final api = _DownloadsApi(const []);
    final session = AuthSession(api: api)
      ..bridgeUrl = 'http://bridge.local'
      ..accessToken = 'session-token';

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => TorrentBloc(
          api,
          initialBridgeUrl: session.bridgeUrl,
          initialSessionToken: session.accessToken,
        ),
        child: MaterialApp(home: DownloadsScreen(session: session)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No downloads yet.'), findsOneWidget);
  });

  testWidgets('history page can retry after a recoverable load error', (
    tester,
  ) async {
    final api = _DownloadsApi(const [
      DownloadJob(
        id: 'job-1',
        slug: 'book-one',
        info: 'Book One',
        status: 'completed',
      ),
    ], error: BridgeException('History is temporarily unavailable.'));
    final session = AuthSession(api: api)
      ..bridgeUrl = 'http://bridge.local'
      ..accessToken = 'session-token';

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => TorrentBloc(
          api,
          initialBridgeUrl: session.bridgeUrl,
          initialSessionToken: session.accessToken,
        ),
        child: MaterialApp(home: DownloadsScreen(session: session)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('History is temporarily unavailable.'), findsOneWidget);

    api.error = null;
    await tester.tap(find.byTooltip('Retry loading downloads'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Book One'), findsOneWidget);
    expect(find.text('History is temporarily unavailable.'), findsNothing);
  });

  testWidgets('search toolbar badge counts only active downloads', (
    tester,
  ) async {
    final api = _DownloadsApi([
      const DownloadJob(id: 'job-active', status: 'running'),
      const DownloadJob(id: 'job-done', status: 'completed'),
      const DownloadJob(id: 'job-error', status: 'failed'),
    ]);
    final session = AuthSession(api: api)
      ..bridgeUrl = 'http://bridge.local'
      ..accessToken = 'session-token';

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => TorrentBloc(
          api,
          initialBridgeUrl: session.bridgeUrl,
          initialSessionToken: session.accessToken,
        ),
        child: MaterialApp(home: TorrentHomePage(session: session)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Download history'), findsOneWidget);
  });
}
