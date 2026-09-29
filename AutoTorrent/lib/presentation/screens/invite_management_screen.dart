import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_session.dart';
import '../../data/api/bridge_api.dart';

class InviteManagementScreen extends StatefulWidget {
  const InviteManagementScreen({required this.session, super.key});

  final AuthSession session;

  @override
  State<InviteManagementScreen> createState() => _InviteManagementScreenState();
}

class _InviteManagementScreenState extends State<InviteManagementScreen> {
  List<BridgeInvite> _invites = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invites = await widget.session.listInvites();
      if (mounted) setState(() => _invites = invites);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createInvite() async {
    try {
      final invite = await widget.session.createInvite();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Invitation created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Copy this code now. It will not be shown again.'),
              const SizedBox(height: 12),
              SelectableText(
                invite.code,
                key: const Key('created-invite-code'),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Expires ${_formatDate(invite.expiresAt)}'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.code));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invitation code copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy code'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      await _loadInvites();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _revoke(BridgeInvite invite) async {
    try {
      await widget.session.revokeInvite(invite.id);
      await _loadInvites();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_message(error))));
  }

  String _message(Object error) => error is BridgeException
      ? error.message
      : 'Could not complete the invitation request.';

  String _formatDate(DateTime date) =>
      date.toLocal().toString().split('.').first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to search',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Invitations'),
        actions: [
          IconButton(
            tooltip: 'Refresh invitations',
            onPressed: _loadInvites,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _createInvite,
        icon: const Icon(Icons.add),
        label: const Text('Create invite'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadInvites,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : _invites.isEmpty
            ? const Center(child: Text('No invitations yet.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: _invites.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final invite = _invites[index];
                  return ListTile(
                    leading: Icon(
                      invite.status == 'active'
                          ? Icons.mark_email_unread_outlined
                          : Icons.mark_email_read_outlined,
                    ),
                    title: Text(
                      '${invite.status[0].toUpperCase()}${invite.status.substring(1)}',
                    ),
                    subtitle: Text('Expires ${_formatDate(invite.expiresAt)}'),
                    trailing: invite.status == 'active'
                        ? IconButton(
                            tooltip: 'Revoke invitation',
                            onPressed: () => _revoke(invite),
                            icon: const Icon(Icons.cancel_outlined),
                          )
                        : null,
                  );
                },
              ),
      ),
    );
  }
}
