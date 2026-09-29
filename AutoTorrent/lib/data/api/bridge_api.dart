import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/torrent_item.dart';

class BridgeException implements Exception {
  BridgeException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

class BridgeSession {
  const BridgeSession({
    required this.accessToken,
    required this.username,
    this.userId = '',
    this.role = 'member',
  });

  final String accessToken;
  final String username;
  final String userId;
  final String role;
}

class BridgeInvite {
  const BridgeInvite({
    required this.id,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String status;
  final DateTime expiresAt;

  factory BridgeInvite.fromJson(Map<String, dynamic> json) => BridgeInvite(
    id: '${json['invite_id'] ?? ''}',
    status: '${json['status'] ?? 'unknown'}',
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      ((json['expires_at'] as num?) ?? 0).round() * 1000,
      isUtc: true,
    ),
  );
}

class CreatedBridgeInvite {
  const CreatedBridgeInvite({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  final String id;
  final String code;
  final DateTime expiresAt;
}

class DownloadJob {
  const DownloadJob({required this.id, required this.status, this.progress});

  final String id;
  final String status;
  final double? progress;

  factory DownloadJob.fromJson(Map<String, dynamic> json) => DownloadJob(
    id: '${json['job_id'] ?? ''}',
    status: '${json['status'] ?? 'unknown'}',
    progress: (json['progress'] as num?)?.toDouble(),
  );

  String get label {
    switch (status) {
      case 'running':
        return 'Downloading on computer';
      case 'completed':
        return 'Download completed';
      case 'failed':
        return 'Download failed';
      default:
        return 'Starting download';
    }
  }
}

class BridgeApi {
  BridgeApi({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;

  String _base(String value) => value.trim().replaceFirst(RegExp(r'/$'), '');

  String _categoryForLibrary(String library) {
    return library == 'books' ? 'livres' : 'livres-audio';
  }

  Future<BridgeSession> login(
    String bridgeUrl,
    String username,
    String password,
  ) async {
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('${_base(bridgeUrl)}/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 12));
      final data = _decode(response);
      if (data is! Map<String, dynamic> || data['access_token'] is! String) {
        throw BridgeException('The bridge returned an invalid login response.');
      }
      return _parseSession(data, username.trim());
    } on TimeoutException {
      throw BridgeException('The bridge login timed out. Check its address.');
    } finally {
      client.close();
    }
  }

  Future<BridgeSession> register(
    String bridgeUrl,
    String code,
    String username,
    String password,
  ) async {
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('${_base(bridgeUrl)}/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': code.trim(),
              'username': username.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 12));
      final data = _decode(response);
      if (data is! Map<String, dynamic> || data['access_token'] is! String) {
        throw BridgeException(
          'The bridge returned an invalid signup response.',
        );
      }
      return _parseSession(data, username.trim());
    } on TimeoutException {
      throw BridgeException('The bridge signup timed out. Check its address.');
    } finally {
      client.close();
    }
  }

  Future<BridgeSession> currentUser(
    String bridgeUrl,
    String sessionToken,
  ) async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(
            Uri.parse('${_base(bridgeUrl)}/api/auth/me'),
            headers: _authHeaders(sessionToken),
          )
          .timeout(const Duration(seconds: 12));
      final data = _decode(response);
      if (data is! Map<String, dynamic>) {
        throw BridgeException(
          'The bridge returned an invalid account response.',
        );
      }
      return BridgeSession(
        accessToken: sessionToken,
        userId: '${data['user_id'] ?? data['id'] ?? ''}',
        username: '${data['username'] ?? ''}',
        role: '${data['role'] ?? 'member'}',
      );
    } on TimeoutException {
      throw BridgeException('The bridge account check timed out.');
    } finally {
      client.close();
    }
  }

  Future<CreatedBridgeInvite> createInvite(
    String bridgeUrl,
    String sessionToken, {
    Duration lifetime = const Duration(days: 7),
  }) async {
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('${_base(bridgeUrl)}/api/auth/invites'),
            headers: {
              'Content-Type': 'application/json',
              ..._authHeaders(sessionToken),
            },
            body: jsonEncode({'expires_in_seconds': lifetime.inSeconds}),
          )
          .timeout(const Duration(seconds: 12));
      final data = _decode(response);
      if (data is! Map<String, dynamic> || data['code'] is! String) {
        throw BridgeException('The bridge returned an invalid invitation.');
      }
      return CreatedBridgeInvite(
        id: '${data['invite_id'] ?? ''}',
        code: data['code'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(
          ((data['expires_at'] as num?) ?? 0).round() * 1000,
          isUtc: true,
        ),
      );
    } on TimeoutException {
      throw BridgeException('Creating an invitation timed out.');
    } finally {
      client.close();
    }
  }

  Future<List<BridgeInvite>> listInvites(
    String bridgeUrl,
    String sessionToken,
  ) async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(
            Uri.parse('${_base(bridgeUrl)}/api/auth/invites'),
            headers: _authHeaders(sessionToken),
          )
          .timeout(const Duration(seconds: 12));
      final data = _decode(response);
      if (data is! List) {
        throw BridgeException('The bridge returned invalid invitation data.');
      }
      return data
          .whereType<Map<String, dynamic>>()
          .map(BridgeInvite.fromJson)
          .toList();
    } on TimeoutException {
      throw BridgeException('Loading invitations timed out.');
    } finally {
      client.close();
    }
  }

  Future<void> revokeInvite(
    String bridgeUrl,
    String sessionToken,
    String inviteId,
  ) async {
    final client = _clientFactory();
    try {
      final response = await client
          .delete(
            Uri.parse('${_base(bridgeUrl)}/api/auth/invites/$inviteId'),
            headers: _authHeaders(sessionToken),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 204) {
        _decode(response);
      }
    } on TimeoutException {
      throw BridgeException('Revoking the invitation timed out.');
    } finally {
      client.close();
    }
  }

  BridgeSession _parseSession(
    Map<String, dynamic> data,
    String fallbackUsername,
  ) {
    final user = data['user'];
    return BridgeSession(
      accessToken: data['access_token'] as String,
      userId: user is Map<String, dynamic>
          ? '${user['id'] ?? user['user_id'] ?? ''}'
          : '',
      username: user is Map<String, dynamic>
          ? '${user['username'] ?? fallbackUsername}'
          : fallbackUsername,
      role: user is Map<String, dynamic>
          ? '${user['role'] ?? 'member'}'
          : 'member',
    );
  }

  Future<void> logout(String bridgeUrl, String sessionToken) async {
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('${_base(bridgeUrl)}/api/auth/logout'),
            headers: _authHeaders(sessionToken),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 204) {
        _decode(response);
      }
    } on TimeoutException {
      throw BridgeException('The bridge logout timed out.');
    } finally {
      client.close();
    }
  }

  Future<List<TorrentItem>> search(
    String bridgeUrl,
    String query,
    String library,
    String sessionToken,
  ) async {
    final uri = Uri.parse('${_base(bridgeUrl)}/api/torrents').replace(
      queryParameters: {'q': query, 'cat': _categoryForLibrary(library)},
    );
    final client = _clientFactory();
    try {
      final response = await client
          .get(uri, headers: _authHeaders(sessionToken))
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException(
              'The bridge did not respond in time.',
              const Duration(seconds: 12),
            ),
          );
      final data = _decode(response);
      final list = data is Map<String, dynamic> ? data['torrents'] : data;
      if (list is! List) {
        throw BridgeException(
          'The bridge returned an unexpected search response.',
        );
      }
      return list
          .whereType<Map<String, dynamic>>()
          .map(TorrentItem.fromJson)
          .toList();
    } on TimeoutException {
      throw BridgeException(
        'The bridge search timed out. Check the bridge address and server.',
      );
    } finally {
      client.close();
    }
  }

  Future<DownloadJob> launch(
    String bridgeUrl,
    String slug,
    String library,
    String sessionToken,
  ) async {
    final uri = Uri.parse('${_base(bridgeUrl)}/api/torrents/$slug/launch');
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ..._authHeaders(sessionToken),
            },
            body: jsonEncode({'library': library}),
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException(
              'The bridge did not respond in time.',
              const Duration(seconds: 12),
            ),
          );
      final data = _decode(response);
      if (data is! Map<String, dynamic>) {
        throw BridgeException(
          'The bridge returned an unexpected launch response.',
        );
      }
      return DownloadJob.fromJson(data);
    } on TimeoutException {
      throw BridgeException(
        'The bridge launch request timed out. Check the bridge address and server.',
      );
    } finally {
      client.close();
    }
  }

  Future<DownloadJob> downloadStatus(
    String bridgeUrl,
    String jobId,
    String sessionToken,
  ) async {
    final response = await http
        .get(
          Uri.parse('${_base(bridgeUrl)}/api/downloads/$jobId'),
          headers: _authHeaders(sessionToken),
        )
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException(
            'The bridge did not respond in time.',
            const Duration(seconds: 8),
          ),
        );
    final data = _decode(response);
    if (data is! Map<String, dynamic>) {
      throw BridgeException(
        'The bridge returned an unexpected status response.',
      );
    }
    return DownloadJob.fromJson(data);
  }

  Map<String, String> _authHeaders(String sessionToken) {
    return {'Authorization': 'Bearer $sessionToken'};
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BridgeException(
        'Bridge error (${response.statusCode}). Check the bridge logs.',
        statusCode: response.statusCode,
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw BridgeException('The bridge returned invalid JSON.');
    }
  }
}
