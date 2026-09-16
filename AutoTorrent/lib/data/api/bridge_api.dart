import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/torrent_item.dart';

class BridgeException implements Exception {
  BridgeException(this.message);

  final String message;
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
  String _base(String value) => value.trim().replaceFirst(RegExp(r'/$'), '');

  String _categoryForLibrary(String library) {
    return library == 'books' ? 'livres' : 'livres-audio';
  }

  Future<List<TorrentItem>> search(
    String bridgeUrl,
    String query,
    String library,
  ) async {
    final uri = Uri.parse('${_base(bridgeUrl)}/api/torrents').replace(
      queryParameters: {'q': query, 'cat': _categoryForLibrary(library)},
    );
    final client = http.Client();
    try {
      final response = await client
          .get(uri)
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
    String username,
    String password,
  ) async {
    final uri = Uri.parse('${_base(bridgeUrl)}/api/torrents/$slug/launch');
    final client = http.Client();
    try {
      final basicAuth = base64.encode(utf8.encode('$username:$password'));
      final response = await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Basic $basicAuth',
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

  Future<DownloadJob> downloadStatus(String bridgeUrl, String jobId) async {
    final response = await http
        .get(Uri.parse('${_base(bridgeUrl)}/api/downloads/$jobId'))
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

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BridgeException(
        'Bridge error (${response.statusCode}). Check the bridge logs.',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw BridgeException('The bridge returned invalid JSON.');
    }
  }
}
