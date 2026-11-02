import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  const DownloadJob({
    required this.id,
    required this.status,
    this.slug = '',
    this.info = '',
    this.downloadDir = '',
    this.phase = 'unknown',
    this.message,
    this.client = 'unknown',
    this.progress,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.downloadSpeed = 0,
    this.etaSeconds,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String status;
  final String slug;
  final String info;
  final String downloadDir;
  final String phase;
  final String? message;
  final String client;
  final double? progress;
  final int downloadedBytes;
  final int? totalBytes;
  final int downloadSpeed;
  final int? etaSeconds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DownloadJob.fromJson(Map<String, dynamic> json) => DownloadJob(
    id: '${json['job_id'] ?? ''}',
    status: '${json['status'] ?? 'unknown'}',
    slug: '${json['slug'] ?? ''}',
    info: '${json['info'] ?? ''}',
    downloadDir: '${json['download_dir'] ?? ''}',
    phase: '${json['phase'] ?? 'unknown'}',
    message: json['message'] as String?,
    client: '${json['client'] ?? 'unknown'}',
    progress: (json['progress'] as num?)?.toDouble(),
    downloadedBytes: (json['downloaded_bytes'] as num?)?.toInt() ?? 0,
    totalBytes: (json['total_bytes'] as num?)?.toInt(),
    downloadSpeed: (json['download_speed'] as num?)?.toInt() ?? 0,
    etaSeconds: (json['eta_seconds'] as num?)?.toInt(),
    createdAt: _parseEpochSeconds(json['created_at']),
    updatedAt: _parseEpochSeconds(json['updated_at']),
  );

  /// A human-readable label for this download; prefers the resolved torrent
  /// name when available, falling back to the requested slug.
  String get displayName =>
      info.isNotEmpty ? info : (slug.isNotEmpty ? slug : 'Download');

  bool get isTerminal => {
    'completed',
    'failed',
    'handed_off',
    'unknown',
    'interrupted',
  }.contains(status);

  String get label {
    if (client == 'project_gutenberg') {
      if (status == 'completed') return 'Book saved to Books folder';
      if (status == 'failed') return 'Book download failed';
      if (status == 'preparing' ||
          status == 'starting' ||
          status == 'running') {
        return 'Preparing legal book download';
      }
    }
    if (status == 'completed') return 'Download completed';
    if (status == 'failed') return 'Download failed';
    if (status == 'interrupted') {
      return 'Interrupted by a bridge restart';
    }
    if (status == 'handed_off' || status == 'unknown') {
      return 'Client started; progress is unavailable';
    }
    switch (phase) {
      case 'preparing':
        return 'Fetching torrent metadata';
      case 'starting':
        return 'Starting download client';
      case 'queued':
        return 'Queued in aria2';
      case 'paused':
        return 'Download paused';
      case 'monitoring':
        return 'External client started; progress is unavailable';
      case 'downloading':
        return 'Downloading';
      default:
        return message ?? 'Starting download';
    }
  }
}

class LegalBook {
  const LegalBook({
    required this.id,
    required this.title,
    required this.formats,
    this.authors = const [],
    this.publishedDate = '',
    this.description = '',
    this.languages = const [],
    this.copyright,
    this.source = 'Project Gutenberg',
    this.previewLink,
    this.coverUrl,
  });

  final String? coverUrl;
  final String id;
  final String title;
  final List<String> authors;
  final String publishedDate;
  final String description;
  final List<String> languages;
  final bool? copyright;
  final String source;
  final List<String> formats;
  final String? previewLink;

  factory LegalBook.fromJson(Map<String, dynamic> json) => LegalBook(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? 'Untitled'}',
    authors: (json['authors'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    publishedDate: '${json['published_date'] ?? ''}',
    description: '${json['description'] ?? ''}',
    languages: (json['languages'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    copyright: json['copyright'] as bool?,
    source: '${json['source'] ?? 'Project Gutenberg'}',
    formats: (json['formats'] as List? ?? const [])
        .whereType<String>()
        .toList(),
    previewLink: json['preview_link'] as String?,
    coverUrl: json['cover_url'] as String?,
  );
}

DateTime? _parseEpochSeconds(dynamic value) {
  if (value is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    (value * 1000).round(),
    isUtc: true,
  );
}

/// Trims the address, drops trailing slashes and adds a missing scheme so a
/// bare host is not treated as a relative URL (https, except for localhost,
/// IP addresses and explicit ports, which default to http).
String normalizeBridgeAddress(String value) {
  var address = value.trim().replaceFirst(RegExp(r'/+$'), '');
  if (address.isEmpty || address.contains('://')) return address;
  final host = address.split('/').first;
  final local =
      host.contains(':') ||
      host == 'localhost' ||
      RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  return '${local ? 'http' : 'https'}://$address';
}

class BridgeApi {
  BridgeApi({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;

  String _base(String value) => normalizeBridgeAddress(value);

  String _categoryForLibrary(String library) {
    return library == 'books' ? 'livres' : 'livres-audio';
  }

  Future<Set<String>> availableProviders(String bridgeUrl) async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(Uri.parse('${_base(bridgeUrl)}/api/providers'))
          .timeout(const Duration(seconds: 12));
      final data = _decode(response);
      if (data is! Map<String, dynamic> ||
          data['tr4cker'] is! bool ||
          data['c411'] is! bool) {
        throw BridgeException(
          'The bridge returned invalid provider availability data.',
        );
      }
      return {
        if (data['tr4cker'] as bool) 'tr4cker',
        if (data['c411'] as bool) 'c411',
      };
    } on TimeoutException {
      throw BridgeException('Checking available providers timed out.');
    } finally {
      client.close();
    }
  }

  Future<void> checkConnectivity(String bridgeUrl) async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(Uri.parse('${_base(bridgeUrl)}/health'))
          .timeout(const Duration(seconds: 12));
      final data = _decode(response);
      if (data is! Map<String, dynamic> || data['status'] != 'ok') {
        throw BridgeException(
          'The bridge health check returned an unhealthy response.',
        );
      }
    } on TimeoutException {
      throw BridgeException('The bridge connectivity check timed out.');
    } finally {
      client.close();
    }
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
    String sessionToken, {
    String source = 'tr4cker',
  }) async {
    final uri = Uri.parse('${_base(bridgeUrl)}/api/torrents').replace(
      queryParameters: {
        'q': query,
        'cat': _categoryForLibrary(library),
        'source': source,
      },
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
      debugPrint('[$source] search "$query" -> ${jsonEncode(data)}');
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

  Future<String?> coverUrl(
    String bridgeUrl,
    String title,
    String sessionToken,
  ) async {
    final uri = Uri.parse('${_base(bridgeUrl)}/api/covers')
        .replace(queryParameters: {'title': title});
    final client = _clientFactory();
    try {
      final response = await client
          .get(uri, headers: _authHeaders(sessionToken))
          .timeout(const Duration(seconds: 10));
      final data = _decode(response);
      return data is Map<String, dynamic> ? data['cover_url'] as String? : null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<List<LegalBook>> searchLegalBooks(
    String bridgeUrl,
    String query,
    String language,
    String sessionToken, {
    bool gutenbergOnly = false,
  }) async {
    final uri = Uri.parse('${_base(bridgeUrl)}/api/books/free/search').replace(
      queryParameters: {
        'q': query.trim(),
        'lang': language,
        'gutenberg_only': '$gutenbergOnly',
      },
    );
    final client = _clientFactory();
    try {
      final response = await client
          .get(uri, headers: _authHeaders(sessionToken))
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw TimeoutException(
              'The legal-books search timed out.',
              const Duration(seconds: 25),
            ),
          );
      final data = _decode(response);
      if (data is! Map<String, dynamic> || data['results'] is! List) {
        throw BridgeException(
          'The bridge returned an unexpected legal-books response.',
        );
      }
      if (data['language'] != language) {
        throw BridgeException(
          'The bridge returned results for a different language.',
        );
      }
      return (data['results'] as List)
          .whereType<Map<String, dynamic>>()
          .map(LegalBook.fromJson)
          .toList();
    } on TimeoutException {
      throw BridgeException('The legal-books search timed out.');
    } finally {
      client.close();
    }
  }

  Future<DownloadJob> downloadLegalBook(
    String bridgeUrl,
    String bookId,
    String format,
    String sessionToken,
  ) async {
    final uri = Uri.parse(
      '${_base(bridgeUrl)}/api/books/free/${Uri.encodeComponent(bookId)}/download',
    );
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              ..._authHeaders(sessionToken),
            },
            body: jsonEncode({'format': format}),
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException(
              'The legal-book download request timed out.',
              const Duration(seconds: 12),
            ),
          );
      final data = _decode(response);
      if (data is! Map<String, dynamic>) {
        throw BridgeException(
          'The bridge returned an unexpected book-download response.',
        );
      }
      return DownloadJob.fromJson(data);
    } on TimeoutException {
      throw BridgeException('The legal-book download request timed out.');
    } finally {
      client.close();
    }
  }

  Future<DownloadJob> launch(
    String bridgeUrl,
    String slug,
    String library,
    String sessionToken, {
    String source = 'tr4cker',
  }) async {
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
            body: jsonEncode({'library': library, 'source': source}),
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

  Future<List<DownloadJob>> listDownloads(
    String bridgeUrl,
    String sessionToken,
  ) async {
    const pageSize = 100;
    final client = _clientFactory();
    try {
      final downloads = <DownloadJob>[];
      var offset = 0;
      while (true) {
        final uri = Uri.parse(
          '${_base(bridgeUrl)}/api/downloads',
        ).replace(queryParameters: {'limit': '$pageSize', 'offset': '$offset'});
        final response = await client
            .get(uri, headers: _authHeaders(sessionToken))
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => throw TimeoutException(
                'The bridge did not respond in time.',
                const Duration(seconds: 8),
              ),
            );
        final data = _decode(response);
        if (data is! List) {
          throw BridgeException(
            'The bridge returned an unexpected downloads list.',
          );
        }
        final page = data
            .whereType<Map<String, dynamic>>()
            .map(DownloadJob.fromJson)
            .toList();
        downloads.addAll(page);
        if (page.length < pageSize) return downloads;
        offset += pageSize;
      }
    } on TimeoutException {
      throw BridgeException(
        'The bridge downloads request timed out. Check the bridge server.',
      );
    } finally {
      client.close();
    }
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
