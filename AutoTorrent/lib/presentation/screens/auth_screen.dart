import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_session.dart';
import '../widgets/brutal.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.session,
    required this.registration,
    super.key,
  });

  final AuthSession session;
  final bool registration;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bridgeController;
  final _inviteController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bridgeController = TextEditingController(text: widget.session.bridgeUrl);
    _usernameController.text = widget.session.username;
  }

  @override
  void dispose() {
    _bridgeController.dispose();
    _inviteController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.registration) {
        await widget.session.register(
          bridgeUrl: _bridgeController.text,
          code: _inviteController.text,
          username: _usernameController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.session.signIn(
          bridgeUrl: _bridgeController.text,
          username: _usernameController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _busy = false;
        });
      }
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registration = widget.registration;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(brutalRadius),
                          border: Border.all(
                            color: brutalInk(context),
                            width: brutalBorderWidth,
                          ),
                        ),
                        child: const Icon(Icons.bolt, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SkyForge',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    registration
                        ? 'Create your account'
                        : 'Sign in to your bridge',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    registration
                        ? 'Use the invitation code shared by your bridge owner.'
                        : 'Connect to your self-hosted SkyForge bridge.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BrutalField(
                          child: TextFormField(
                            key: const Key('bridge-url'),
                            controller: _bridgeController,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                _required(value, 'Bridge address'),
                            decoration: const InputDecoration(
                              labelText: 'Bridge address',
                              hintText: 'https://bridge.example.com',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                        ),
                        if (registration) ...[
                          const SizedBox(height: 14),
                          BrutalField(
                            child: TextFormField(
                              key: const Key('invite-code'),
                              controller: _inviteController,
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  _required(value, 'Invite code'),
                              decoration: const InputDecoration(
                                labelText: 'Invite code',
                                prefixIcon: Icon(
                                  Icons.confirmation_number_outlined,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        BrutalField(
                          child: TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            validator: (value) => _required(value, 'Username'),
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        BrutalField(
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: registration
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!registration) _submit();
                            },
                            validator: (value) {
                              final required = _required(value, 'Password');
                              if (required != null) return required;
                              if (registration && value!.length < 12) {
                                return 'Use at least 12 characters.';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                        ),
                        if (registration) ...[
                          const SizedBox(height: 14),
                          BrutalField(
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match.';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          key: Key(
                            registration ? 'signup-submit' : 'signin-submit',
                          ),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  registration ? 'Create account' : 'Sign in',
                                ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          key: Key(
                            registration ? 'open-sign-in' : 'open-sign-up',
                          ),
                          onPressed: _busy
                              ? null
                              : () => context.go(
                                  registration ? '/auth' : '/signup',
                                ),
                          child: Text(
                            registration
                                ? 'Already have an account? Sign in'
                                : 'Create account',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
