import 'dart:convert';

import 'package:auto_torrent/data/api/bridge_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('availableProviders reports configured providers without secrets', () async {
    late http.Request capturedRequest;
    final api = BridgeApi(
      clientFactory: () => MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'tr4cker': true, 'c411': false}),
          200,
        );
      }),
    );

    final providers = await api.availableProviders('http://bridge.local/');

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/api/providers');
    expect(providers, {'tr4cker'});
  });

  test('availableProviders rejects invalid responses', () async {
    final api = BridgeApi(
      clientFactory: () => MockClient(
        (_) async => http.Response(jsonEncode({'tr4cker': true}), 200),
      ),
    );

    await expectLater(
      api.availableProviders('http://bridge.local'),
      throwsA(isA<BridgeException>()),
    );
  });

  test('checkConnectivity calls the bridge health route', () async {
    late http.Request capturedRequest;
    final api = BridgeApi(
      clientFactory: () => MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      }),
    );

    await api.checkConnectivity('http://bridge.local/');

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/health');
  });

  test('checkConnectivity rejects a non-healthy response', () async {
    final api = BridgeApi(
      clientFactory: () => MockClient(
        (_) async => http.Response(jsonEncode({'status': 'starting'}), 200),
      ),
    );

    await expectLater(
      api.checkConnectivity('http://bridge.local'),
      throwsA(isA<BridgeException>()),
    );
  });

  test('login exchanges credentials for the server access token', () async {
    late http.Request capturedRequest;
    final api = BridgeApi(
      clientFactory: () => MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'access_token': 'session-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {'id': 'user-id', 'username': 'reader', 'role': 'user'},
          }),
          200,
        );
      }),
    );

    final session = await api.login('http://bridge.local', 'reader', 'secret');

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/auth/login');
    expect(jsonDecode(capturedRequest.body), {
      'username': 'reader',
      'password': 'secret',
    });
    expect(session.accessToken, 'session-token');
    expect(session.username, 'reader');
  });

  test(
    'protected requests send a bearer token, never Basic credentials',
    () async {
      late http.Request capturedRequest;
      final api = BridgeApi(
        clientFactory: () => MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode([
              {
                'slug': '42',
                'name': 'French audiobook',
                'size_bytes': 2048,
                'seeders': 7,
                'file_count': 3,
                'source': 'c411',
              },
            ]),
            200,
          );
        }),
      );

      final results = await api.search(
        'http://bridge.local',
        'title',
        'books',
        'session-token',
        source: 'c411',
      );

      expect(capturedRequest.headers['authorization'], 'Bearer session-token');
      expect(capturedRequest.url.queryParameters['source'], 'c411');
      expect(results.single.source, 'c411');
    },
  );

  test('launch preserves the selected torrent source', () async {
    late http.Request capturedRequest;
    final api = BridgeApi(
      clientFactory: () => MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'job_id': 'job-1', 'status': 'preparing'}),
          202,
        );
      }),
    );

    await api.launch(
      'http://bridge.local',
      '42',
      'audiobooks',
      'session-token',
      source: 'c411',
    );

    expect(jsonDecode(capturedRequest.body), {
      'library': 'audiobooks',
      'source': 'c411',
    });
  });

  test(
    'legal book search sends language and parses Gutendex metadata',
    () async {
      late http.Request capturedRequest;
      final api = BridgeApi(
        clientFactory: () => MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'language': 'fr',
              'results': [
                {
                  'id': '1342',
                  'title': 'Les Misérables',
                  'authors': ['Victor Hugo'],
                  'published_date': '1862',
                  'languages': ['fr'],
                  'copyright': false,
                  'source': 'Google Books',
                  'formats': ['epub'],
                },
              ],
            }),
            200,
          );
        }),
      );

      final results = await api.searchLegalBooks(
        'http://bridge.local',
        'Victor Hugo',
        'fr',
        'session-token',
        gutenbergOnly: true,
      );

      expect(capturedRequest.url.path, '/api/books/free/search');
      expect(capturedRequest.url.queryParameters['q'], 'Victor Hugo');
      expect(capturedRequest.url.queryParameters['lang'], 'fr');
      expect(capturedRequest.url.queryParameters['gutenberg_only'], 'true');
      expect(capturedRequest.headers['authorization'], 'Bearer session-token');
      expect(results.single.title, 'Les Misérables');
      expect(results.single.languages, ['fr']);
      expect(results.single.copyright, isFalse);
      expect(results.single.source, 'Google Books');
      expect(results.single.formats, ['epub']);
    },
  );

  test('legal book download submits only ID and format', () async {
    late http.Request capturedRequest;
    final api = BridgeApi(
      clientFactory: () => MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'job_id': 'job-legal-1',
            'slug': 'volume-1',
            'client': 'project_gutenberg',
            'status': 'preparing',
            'phase': 'preparing',
          }),
          202,
        );
      }),
    );

    final job = await api.downloadLegalBook(
      'http://bridge.local',
      'volume-1',
      'epub',
      'session-token',
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/books/free/volume-1/download');
    expect(jsonDecode(capturedRequest.body), {'format': 'epub'});
    expect(capturedRequest.headers['authorization'], 'Bearer session-token');
    expect(job.client, 'project_gutenberg');
  });

  test('download job parses determinate aria2 progress details', () {
    final job = DownloadJob.fromJson({
      'job_id': 'job-1',
      'client': 'aria2c',
      'status': 'running',
      'phase': 'downloading',
      'message': 'Downloading with aria2.',
      'progress': 0.25,
      'downloaded_bytes': 256,
      'total_bytes': 1024,
      'download_speed': 128,
      'eta_seconds': 6,
    });

    expect(job.progress, 0.25);
    expect(job.downloadedBytes, 256);
    expect(job.totalBytes, 1024);
    expect(job.downloadSpeed, 128);
    expect(job.etaSeconds, 6);
    expect(job.phase, 'downloading');
  });

  test(
    'external launcher jobs preserve indeterminate progress and feedback',
    () {
      final job = DownloadJob.fromJson({
        'job_id': 'job-2',
        'client': 'configured',
        'status': 'handed_off',
        'phase': 'monitoring',
        'message': 'Launcher exited; transfer progress is unavailable.',
        'progress': null,
      });

      expect(job.progress, isNull);
      expect(job.client, 'configured');
      expect(job.message, contains('unavailable'));
      expect(job.label, contains('progress is unavailable'));
    },
  );

  test('legal book jobs use direct-download status labels', () {
    final preparing = DownloadJob.fromJson({
      'job_id': 'legal-job',
      'client': 'project_gutenberg',
      'status': 'preparing',
    });
    final completed = DownloadJob.fromJson({
      'job_id': 'legal-job',
      'client': 'project_gutenberg',
      'status': 'completed',
    });

    expect(preparing.label, 'Preparing legal book download');
    expect(completed.label, 'Book saved to Books folder');
  });

  test('listDownloads fetches every page with bearer authentication', () async {
    final requests = <http.Request>[];
    final api = BridgeApi(
      clientFactory: () => MockClient((request) async {
        requests.add(request);
        final offset = int.parse(request.url.queryParameters['offset']!);
        final jobs = offset == 0
            ? List.generate(
                100,
                (index) => {'job_id': 'job-$index', 'status': 'completed'},
              )
            : [
                {'job_id': 'job-100', 'status': 'completed'},
              ];
        return http.Response(jsonEncode(jobs), 200);
      }),
    );

    final downloads = await api.listDownloads(
      'http://bridge.local',
      'session-token',
    );

    expect(downloads, hasLength(101));
    expect(downloads.last.id, 'job-100');
    expect(requests.map((request) => request.url.queryParameters['offset']), [
      '0',
      '100',
    ]);
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer session-token',
      ),
      isTrue,
    );
  });

  test('logout revokes the current bearer session', () async {
    late http.Request capturedRequest;
    final api = BridgeApi(
      clientFactory: () => MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 204);
      }),
    );

    await api.logout('http://bridge.local', 'session-token');

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/auth/logout');
    expect(capturedRequest.headers['authorization'], 'Bearer session-token');
  });

  test(
    'registration redeems an invite and returns the member session',
    () async {
      late http.Request capturedRequest;
      final api = BridgeApi(
        clientFactory: () => MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'access_token': 'member-session',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'member-id',
                'username': 'reader',
                'role': 'member',
              },
            }),
            201,
          );
        }),
      );

      final session = await api.register(
        'http://bridge.local',
        'invite-code',
        'reader',
        'correct horse battery staple',
      );

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/auth/register');
      expect(jsonDecode(capturedRequest.body), {
        'code': 'invite-code',
        'username': 'reader',
        'password': 'correct horse battery staple',
      });
      expect(session.accessToken, 'member-session');
      expect(session.role, 'member');
    },
  );

  test(
    'owner invite methods use bearer auth and parse safe metadata',
    () async {
      final requests = <http.Request>[];
      final api = BridgeApi(
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'invite_id': 'invite-id',
                'code': 'one-time-code',
                'created_at': 1000,
                'expires_at': 2000,
                'expires_in_seconds': 1000,
              }),
              201,
            );
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'invite_id': 'invite-id',
                  'status': 'active',
                  'expires_at': 2000,
                },
              ]),
              200,
            );
          }
          return http.Response('', 204);
        }),
      );

      final created = await api.createInvite(
        'http://bridge.local',
        'owner-session',
      );
      final invites = await api.listInvites(
        'http://bridge.local',
        'owner-session',
      );
      await api.revokeInvite(
        'http://bridge.local',
        'owner-session',
        'invite-id',
      );

      expect(created.code, 'one-time-code');
      expect(invites.single.status, 'active');
      expect(requests.map((request) => request.method), [
        'POST',
        'GET',
        'DELETE',
      ]);
      expect(
        requests.every(
          (request) =>
              request.headers['authorization'] == 'Bearer owner-session',
        ),
        isTrue,
      );
    },
  );
}
