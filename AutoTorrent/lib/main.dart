import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AutoTorrentApp());
}

class AutoTorrentApp extends StatelessWidget {
  const AutoTorrentApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF6F7F9);
    return MaterialApp(
      title: 'AutoTorrent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B4BDE),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: background,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF5B4BDE), width: 1.5),
          ),
        ),
      ),
      home: const TorrentHomePage(),
    );
  }
}

class TorrentHomePage extends StatefulWidget {
  const TorrentHomePage({super.key});

  @override
  State<TorrentHomePage> createState() => _TorrentHomePageState();
}

class _TorrentHomePageState extends State<TorrentHomePage> {
  final _bridgeController = TextEditingController(text: 'http://localhost:8384');
  final _searchController = TextEditingController();
  final _api = BridgeApi();
  List<TorrentItem> _results = [];
  bool _loading = false;
  String? _error;
  String _library = 'audiobooks';

  @override
  void dispose() {
    _bridgeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter a title, author, or keyword to search.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _api.search(
        _bridgeController.text,
        query,
      );
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launch(TorrentItem torrent) async {
    try {
      await _api.launch(_bridgeController.text, torrent.slug, _library);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sent "${torrent.name}" to the computer'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is BridgeException) return error.message;
    return 'Could not reach the bridge. Check its address and connection.';
  }

  Future<void> _showSettings() async {
    final controller = TextEditingController(text: _bridgeController.text);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bridge connection'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Bridge URL',
            hintText: 'http://192.168.1.10:8384',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) _bridgeController.text = value;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 11),
            const Text('AutoTorrent', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showSettings,
            tooltip: 'Bridge settings',
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text('Find something to download', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  Text(
                    'Search through TR4CKER and send a torrent to your home computer.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Search titles, authors, or keywords',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _loading ? null : _search,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      const Icon(Icons.folder_outlined, size: 18, color: Colors.black54),
                      const SizedBox(width: 8),
                      Text('Save to', style: theme.textTheme.labelLarge),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Audiobooks'),
                        selected: _library == 'audiobooks',
                        onSelected: (_) => setState(() => _library = 'audiobooks'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Books'),
                        selected: _library == 'books',
                        onSelected: (_) => setState(() => _library = 'books'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (_error != null)
                    _ErrorCard(message: _error!, onRetry: _search)
                  else if (_results.isEmpty)
                    const _EmptyState()
                  else ...[
                    Text('${_results.length} results', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ..._results.map((torrent) => _TorrentCard(torrent: torrent, onLaunch: () => _launch(torrent))),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TorrentCard extends StatelessWidget {
  const _TorrentCard({required this.torrent, required this.onLaunch});

  final TorrentItem torrent;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(torrent.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Stat(icon: Icons.sd_storage_outlined, text: torrent.size),
                _Stat(icon: Icons.upload_outlined, text: '${torrent.seeders} seeders', color: Colors.green.shade700),
                _Stat(icon: Icons.folder_copy_outlined, text: '${torrent.files} files'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLaunch,
                icon: const Icon(Icons.download_rounded, size: 19),
                label: const Text('Download to computer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.black45),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color ?? Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 54),
        child: Column(
          children: [
            Icon(Icons.travel_explore_rounded, size: 58, color: Theme.of(context).colorScheme.primary.withAlpha(150)),
            const SizedBox(height: 14),
            const Text('Your search results will appear here', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            const Text('The bridge must be running on your computer.', style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
              IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
      );
}

class TorrentItem {
  TorrentItem({required this.slug, required this.name, required this.size, required this.seeders, required this.files});
  final String slug;
  final String name;
  final String size;
  final int seeders;
  final int files;

  factory TorrentItem.fromJson(Map<String, dynamic> json) => TorrentItem(
        slug: '${json['slug'] ?? ''}',
        name: '${json['name'] ?? 'Unnamed torrent'}',
        size: _formatBytes(json['size_bytes']),
        seeders: _asInt(json['seeders']),
        files: _asInt(json['file_count']),
      );

  static int _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static String _formatBytes(dynamic value) {
    final bytes = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    if (bytes >= 1000000000) return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
    if (bytes >= 1000000) return '${(bytes / 1000000).toStringAsFixed(1)} MB';
    return '${(bytes / 1000).toStringAsFixed(0)} KB';
  }
}

class BridgeException implements Exception {
  BridgeException(this.message);
  final String message;
}

class BridgeApi {
  String _base(String value) => value.trim().replaceFirst(RegExp(r'/$'), '');

  Future<List<TorrentItem>> search(String bridgeUrl, String query) async {
    final response = await http.get(Uri.parse('${_base(bridgeUrl)}/api/torrents').replace(queryParameters: {'q': query, 'cat': 'livres-audio'}));
    final data = _decode(response);
    final list = data is Map<String, dynamic> ? data['torrents'] : data;
    if (list is! List) throw BridgeException('The bridge returned an unexpected search response.');
    return list.whereType<Map<String, dynamic>>().map(TorrentItem.fromJson).toList();
  }

  Future<void> launch(String bridgeUrl, String slug, String library) async {
    final response = await http.post(
      Uri.parse('${_base(bridgeUrl)}/api/torrents/$slug/launch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'library': library}),
    );
    _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BridgeException('Bridge error (${response.statusCode}). Check the bridge logs.');
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw BridgeException('The bridge returned invalid JSON.');
    }
  }
}
