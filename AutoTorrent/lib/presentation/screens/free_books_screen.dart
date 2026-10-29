import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth_session.dart';
import '../../data/api/bridge_api.dart';
import '../bloc/torrent_bloc.dart';
import '../bloc/torrent_event.dart';
import '../bloc/torrent_state.dart';
import '../widgets/book_cover.dart';
import '../widgets/source_app_bar.dart';

const _bookLanguages = {
  'fr': 'French',
  'en': 'English',
  'es': 'Spanish',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
};

class FreeBooksScreen extends StatefulWidget {
  const FreeBooksScreen({required this.session, super.key});

  final AuthSession session;

  @override
  State<FreeBooksScreen> createState() => _FreeBooksScreenState();
}

class _FreeBooksScreenState extends State<FreeBooksScreen> {
  final _searchController = TextEditingController();
  String _language = 'fr';
  bool _gutenbergOnly = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final token = widget.session.accessToken;
    if (token == null || token.isEmpty) {
      context.read<TorrentBloc>().add(
        const SearchValidationFailed('Sign in to search free books.'),
      );
      return;
    }
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      context.read<TorrentBloc>().add(
        const SearchValidationFailed('Enter a title, author, or keyword.'),
      );
      return;
    }
    setState(() => _hasSearched = true);
    context.read<TorrentBloc>().add(
      LegalBooksSearchRequested(
        widget.session.bridgeUrl,
        query,
        _language,
        token,
        gutenbergOnly: _gutenbergOnly,
      ),
    );
  }

  void _download(LegalBook book) {
    final token = widget.session.accessToken;
    if (token == null || token.isEmpty) {
      context.read<TorrentBloc>().add(
        const SearchValidationFailed('Sign in to download free books.'),
      );
      return;
    }
    context.read<TorrentBloc>().add(
      LegalBookDownloadRequested(widget.session.bridgeUrl, book, 'epub', token),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Book download added to download history.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<TorrentBloc, TorrentState>(
      builder: (context, state) => Scaffold(
        appBar: SourceAppBar(
          session: widget.session,
          activeDownloadCount: state.activeDownloadCount,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Project Gutenberg',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Search free ebooks by title or author. French is selected by default.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Book language'),
                items: _bookLanguages.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (language) {
                  if (language != null) setState(() => _language = language);
                },
              ),
              SwitchListTile.adaptive(
                key: const Key('gutenberg-only-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Project Gutenberg only'),
                subtitle: const Text('Do not use Google Books as a fallback'),
                value: _gutenbergOnly,
                onChanged: (value) => setState(() => _gutenbergOnly = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Search books by title or author',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Search free books',
                    onPressed: state.loading ? null : _search,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (state.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (state.error != null)
                _FreeBooksError(message: state.error!, onRetry: _search)
              else if (state.legalResults.isEmpty && _hasSearched)
                const _FreeBooksEmpty()
              else if (state.legalResults.isNotEmpty) ...[
                Text(
                  '${state.legalResults.length} books',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...state.legalResults.map(
                  (book) => _FreeBookCard(
                    book: book,
                    onDownload: () => _download(book),
                  ),
                ),
              ] else
                const _FreeBooksPrompt(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeBookCard extends StatelessWidget {
  const _FreeBookCard({required this.book, required this.onDownload});

  final LegalBook book;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewUri = Uri.tryParse(book.previewLink ?? '');
    final previewHost = switch (book.source) {
      'Project Gutenberg' => 'www.gutenberg.org',
      'Google Books' => 'books.google.com',
      _ => null,
    };
    final canOpenPreview =
        previewUri != null &&
        previewUri.scheme == 'https' &&
        previewUri.host == previewHost &&
        previewUri.userInfo.isEmpty;
    final languages = book.languages
        .map((language) => _bookLanguages[language] ?? language.toUpperCase())
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(url: book.coverUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (book.authors.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(book.authors.join(', ')),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${book.source}${languages.isEmpty ? '' : ' · $languages'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (book.copyright != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.copyright == false
                          ? 'Catalog marks this book as public domain in the US.'
                          : 'Catalog marks this book as copyrighted in the US.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (book.publishedDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Released ${book.publishedDate}'),
                  ],
                  if (book.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      book.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (canOpenPreview)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        previewUri,
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('Open in ${book.source}'),
                    ),
                  if (book.formats.contains('epub'))
                    FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download EPUB to computer'),
                    )
                  else
                    Text(
                      'Open the source page for reading and download options.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeBooksPrompt extends StatelessWidget {
  const _FreeBooksPrompt();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 36),
    child: Text('Enter a search term to browse free books.'),
  );
}

class _FreeBooksEmpty extends StatelessWidget {
  const _FreeBooksEmpty();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 36),
    child: Text('No matching books found. Try another search or language.'),
  );
}

class _FreeBooksError extends StatelessWidget {
  const _FreeBooksError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
    ],
  );
}
