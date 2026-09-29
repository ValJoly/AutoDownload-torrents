import 'dart:convert';

import 'package:auto_torrent/data/api/bridge_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
          return http.Response('[]', 200);
        }),
      );

      await api.search(
        'http://bridge.local',
        'title',
        'books',
        'session-token',
      );

      expect(capturedRequest.headers['authorization'], 'Bearer session-token');
    },
  );

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
