class TorrentItem {
  TorrentItem({
    required this.slug,
    required this.name,
    required this.size,
    required this.seeders,
    required this.files,
    this.source = 'tr4cker',
    this.coverUrl,
  });

  final String? coverUrl;
  final String slug;
  final String name;
  final String size;
  final int seeders;
  final int files;
  final String source;

  factory TorrentItem.fromJson(Map<String, dynamic> json) => TorrentItem(
    slug: '${json['slug'] ?? ''}',
    name: '${json['name'] ?? 'Unnamed torrent'}',
    size: _formatBytes(json['size_bytes']),
    seeders: _asInt(json['seeders']),
    files: _asInt(json['file_count']),
    source: '${json['source'] ?? 'tr4cker'}',
    coverUrl: json['cover_url'] as String?,
  );

  static int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static String _formatBytes(dynamic value) {
    final bytes = value is num
        ? value.toDouble()
        : double.tryParse('$value') ?? 0;
    if (bytes >= 1000000000) {
      return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1000000) {
      return '${(bytes / 1000000).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1000).toStringAsFixed(0)} KB';
  }
}
