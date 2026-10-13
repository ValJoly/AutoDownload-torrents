import 'package:auto_torrent/core/auth_session.dart';
import 'package:auto_torrent/data/api/bridge_api.dart';
import 'package:auto_torrent/data/models/torrent_item.dart';
import 'package:auto_torrent/presentation/bloc/torrent_bloc.dart';
import 'package:auto_torrent/presentation/bloc/torrent_event.dart';
import 'package:auto_torrent/presentation/screens/downloads_screen.dart';
import 'package:auto_torrent/presentation/screens/free_books_screen.dart';
import 'package:auto_torrent/presentation/screens/torrent_home_page.dart';
import 'package:auto_torrent/presentation/widgets/source_navigation_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _DownloadsApi extends BridgeApi {
  _DownloadsApi(
    this.downloads, {
    this.error,
    this.legalBooks = const [],
    this.legalBookJob,
    this.searchResults = const [],
    this.launchJob,
  });

  final List<DownloadJob> downloads;
  final List<LegalBook> legalBooks;
  final DownloadJob? legalBookJob;
  final List<TorrentItem> searchResults;
  final DownloadJob? launchJob;
  Object? error;
  String? requestedBridgeUrl;
  String? requestedSessionToken;
  String? launchedTorrentSource;
  String? searchedLegalBookQuery;
  String? searchedLegalBookLanguage;
  bool? searchedGutenbergOnly;
  String? downloadedLegalBookId;
  String? downloadedLegalBookFormat;

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

  @override
  Future<List<LegalBook>> searchLegalBooks(
    String bridgeUrl,
    String query,
    String language,
    String sessionToken, {
    bool gutenbergOnly = false,
  }) async {
    searchedLegalBookQuery = query;
    searchedLegalBookLanguage = language;
    searchedGutenbergOnly = gutenbergOnly;
    return legalBooks;
  }

  @override
  Future<List<TorrentItem>> search(
    String bridgeUrl,
    String query,
    String library,
    String sessionToken, {
    String source = 'tr4cker',
  }) async => searchResults;

  @override
  Future<DownloadJob> launch(
    String bridgeUrl,
    String slug,
    String library,
    String sessionToken, {
    String source = 'tr4cker',
  }) async {
    launchedTorrentSource = source;
    return launchJob!;
  }

  @override
  Future<DownloadJob> downloadLegalBook(
    String bridgeUrl,
    String bookId,
    String format,
    String sessionToken,
  ) async {
    downloadedLegalBookId = bookId;
    downloadedLegalBookFormat = format;
    return legalBookJob!;
  }
}

void main() {
  testWidgets('bottom tabs switch between the three sources', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _DownloadsApi(const []);
    final session = AuthSession(api: api)
      ..bridgeUrl = 'http://bridge.local'
      ..accessToken = 'session-token'
      ..role = 'owner';
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              SourceNavigationShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      TorrentHomePage(session: session, source: 'tr4cker'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/c411',
                  builder: (context, state) =>
                      TorrentHomePage(session: session, source: 'c411'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/free-books',
                  builder: (context, state) =>
                      FreeBooksScreen(session: session),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/downloads',
          builder: (context, state) => DownloadsScreen(session: session),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => TorrentBloc(api),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final libraryCenter = tester.getCenter(find.text('Library'));
    final audioChipCenter = tester.getCenter(find.text('Audiobooks'));
    final bookChipCenter = tester.getCenter(find.text('Books'));
    expect((libraryCenter.dy - audioChipCenter.dy).abs(), lessThan(1));
    expect((audioChipCenter.dy - bookChipCenter.dy).abs(), lessThan(1));
    expect(find.text('Audiobooks'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('SkyForge'), findsOneWidget);
    expect(find.byTooltip('Download history'), findsOneWidget);
    expect(find.byTooltip('Appearance settings'), findsOneWidget);
    expect(find.byTooltip('Manage invitations'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('TR4CKER'), findsOneWidget);
    expect(find.byTooltip('C411'), findsOneWidget);
    expect(find.byTooltip('Free books'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('C411'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(
      find.text('Search C411 and send a torrent to your home computer.'),
      findsOneWidget,
    );
    expect(find.text('SkyForge'), findsOneWidget);
    expect(find.byTooltip('Manage invitations'), findsOneWidget);

    await tester.tap(find.text('Free books'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(FreeBooksScreen), findsOneWidget);
    expect(find.text('Project Gutenberg'), findsOneWidget);
    expect(find.text('SkyForge'), findsOneWidget);
    expect(find.byTooltip('Download history'), findsOneWidget);
    expect(find.byTooltip('Appearance settings'), findsOneWidget);
    expect(find.byTooltip('Manage invitations'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);
    await tester.tap(find.byTooltip('Download history'));
    await tester.pumpAndSettle();
    expect(find.byType(DownloadsScreen), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    router.dispose();
  });

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

  test('legal search keeps results separate from torrent results', () async {
    final api = _DownloadsApi(
      const [],
      legalBooks: const [
        LegalBook(
          id: 'volume-1',
          title: 'Les Misérables',
          languages: ['fr'],
          formats: ['epub'],
        ),
      ],
    );
    final bloc = TorrentBloc(api);
    bloc.add(
      const LegalBooksSearchRequested(
        'http://bridge.local',
        'Victor Hugo',
        'fr',
        'session-token',
      ),
    );

    final state = await bloc.stream.firstWhere(
      (state) => state.legalResults.isNotEmpty,
    );

    expect(api.searchedLegalBookQuery, 'Victor Hugo');
    expect(state.legalResults.single.id, 'volume-1');
    expect(state.results, isEmpty);
    await bloc.close();
  });

  test(
    'legal book action requests a direct format and tracks its job',
    () async {
      final api = _DownloadsApi(
        const [],
        legalBookJob: const DownloadJob(
          id: 'legal-job-1',
          slug: 'volume-1',
          client: 'project_gutenberg',
          status: 'preparing',
        ),
      );
      const book = LegalBook(
        id: 'volume-1',
        title: 'Les Misérables',
        formats: ['epub'],
      );
      final bloc = TorrentBloc(api);
      bloc.add(
        const LegalBookDownloadRequested(
          'http://bridge.local',
          book,
          'epub',
          'session-token',
        ),
      );

      final state = await bloc.stream.firstWhere(
        (state) => state.downloads.any((job) => job.id == 'legal-job-1'),
      );

      expect(api.downloadedLegalBookId, 'volume-1');
      expect(api.downloadedLegalBookFormat, 'epub');
      expect(state.downloads.single.client, 'project_gutenberg');
      await bloc.close();
    },
  );

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

  testWidgets('launch uses the selected provider, not result metadata', (
    tester,
  ) async {
    final api = _DownloadsApi(
      const [],
      searchResults: [
        TorrentItem(
          slug: 'jeff-vandermeer-annihilation-epub-aa35dd49',
          name: 'Jeff VanderMeer - Annihilation [ePub]',
          size: '1 MB',
          seeders: 3,
          files: 1,
          source: 'torrent-indexer-name',
        ),
      ],
      launchJob: const DownloadJob(id: 'job-1', status: 'preparing'),
    );
    final session = AuthSession(api: api)
      ..bridgeUrl = 'http://bridge.local'
      ..accessToken = 'session-token';
    final bloc = TorrentBloc(api);

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => bloc,
        child: MaterialApp(
          home: TorrentHomePage(session: session, source: 'tr4cker'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'annihilation');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.text('Jeff VanderMeer - Annihilation [ePub]'), findsOneWidget);
    await tester.tap(find.text('Download to computer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.launchedTorrentSource, 'tr4cker');
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
        child: MaterialApp(
          home: TorrentHomePage(session: session, source: 'tr4cker'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1'), findsOneWidget);
    expect(find.byTooltip('Download history'), findsOneWidget);
  });

  testWidgets('Free books defaults to French and shows Gutendex EPUB actions', (
    tester,
  ) async {
    final api = _DownloadsApi(
      const [],
      legalBooks: const [
        LegalBook(
          id: 'volume-1',
          title: 'Les Misérables',
          authors: ['Victor Hugo'],
          publishedDate: '1862',
          languages: ['fr'],
          copyright: false,
          previewLink: 'https://www.gutenberg.org/ebooks/1342',
          formats: ['epub'],
        ),
      ],
    );
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
        child: MaterialApp(home: FreeBooksScreen(session: session)),
      ),
    );
    await tester.pump();

    expect(find.text('French'), findsOneWidget);
    final sourceToggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('gutenberg-only-toggle')),
    );
    expect(sourceToggle.value, isFalse);
    await tester.tap(find.byKey(const Key('gutenberg-only-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spanish').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Victor Hugo');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.searchedLegalBookQuery, 'Victor Hugo');
    expect(api.searchedLegalBookLanguage, 'es');
    expect(api.searchedGutenbergOnly, isTrue);
    expect(find.text('Les Misérables'), findsOneWidget);
    expect(find.text('Project Gutenberg · French'), findsOneWidget);
    expect(
      find.text('Catalog marks this book as public domain in the US.'),
      findsOneWidget,
    );
    expect(find.text('Open in Project Gutenberg'), findsOneWidget);
    expect(find.text('Download EPUB to computer'), findsOneWidget);
    expect(find.text('Download to computer'), findsNothing);
  });

  testWidgets('EPUB action uses direct book download, not torrent launch', (
    tester,
  ) async {
    const book = LegalBook(
      id: 'volume-1',
      title: 'Les Misérables',
      formats: ['epub'],
    );
    final api = _DownloadsApi(
      const [],
      legalBooks: const [book],
      legalBookJob: const DownloadJob(
        id: 'legal-job-1',
        slug: 'volume-1',
        client: 'project_gutenberg',
        status: 'preparing',
      ),
    );
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
        child: MaterialApp(home: FreeBooksScreen(session: session)),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Victor Hugo');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Download EPUB to computer'));
    await tester.pump();

    expect(api.downloadedLegalBookId, 'volume-1');
    expect(api.downloadedLegalBookFormat, 'epub');
    expect(
      find.text('Book download added to download history.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Google fallback books open their source page without local EPUB',
    (tester) async {
      final api = _DownloadsApi(
        const [],
        legalBooks: const [
          LegalBook(
            id: 'google-volume-1',
            title: 'Les Misérables',
            authors: ['Victor Hugo'],
            languages: ['fr'],
            source: 'Google Books',
            previewLink: 'https://books.google.com/books?id=google-volume-1',
            formats: [],
          ),
        ],
      );
      final session = AuthSession(api: api)
        ..bridgeUrl = 'http://bridge.local'
        ..accessToken = 'session-token';

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => TorrentBloc(api),
          child: MaterialApp(home: FreeBooksScreen(session: session)),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Victor Hugo');
      await tester.tap(find.byTooltip('Search free books'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Google Books · French'), findsOneWidget);
      expect(find.text('Open in Google Books'), findsOneWidget);
      expect(find.text('Download EPUB to computer'), findsNothing);
    },
  );
}
