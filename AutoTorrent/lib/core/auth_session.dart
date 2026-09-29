import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/bridge_api.dart';

class AuthSession extends ChangeNotifier {
  AuthSession({BridgeApi? api, FlutterSecureStorage? secureStorage})
    : api = api ?? BridgeApi(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _bridgeUrlKey = 'bridge_url';
  static const _usernameKey = 'bridge_username';
  static const _roleKey = 'bridge_role';
  static const _sessionTokenKey = 'bridge_session_token';

  final BridgeApi api;
  final FlutterSecureStorage _secureStorage;

  String bridgeUrl = '';
  String username = '';
  String role = '';
  String? accessToken;
  bool initialized = false;

  bool get isSignedIn => accessToken != null && accessToken!.isNotEmpty;
  bool get isOwner => isSignedIn && role == 'owner';

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      bridgeUrl = _normalizeBridgeUrl(
        preferences.getString(_bridgeUrlKey) ?? '',
      );
      username = preferences.getString(_usernameKey) ?? '';
      role = preferences.getString(_roleKey) ?? '';
      await preferences.remove('bridge_password');
      accessToken = await _secureStorage.read(key: _sessionTokenKey);

      if (isSignedIn && bridgeUrl.isNotEmpty) {
        try {
          final user = await api.currentUser(bridgeUrl, accessToken!);
          username = user.username;
          role = user.role;
          await preferences.setString(_usernameKey, username);
          await preferences.setString(_roleKey, role);
        } on BridgeException catch (error) {
          if (error.statusCode == 401) {
            await _clearSession();
          }
        }
      } else if (isSignedIn) {
        await _clearSession();
      }
    } catch (_) {
      // Keep the app usable when platform storage or the bridge is unavailable.
    } finally {
      initialized = true;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String bridgeUrl,
    required String username,
    required String password,
  }) async {
    await _setBridgeUrl(bridgeUrl);
    final session = await api.login(this.bridgeUrl, username, password);
    await _saveSession(session);
  }

  Future<void> register({
    required String bridgeUrl,
    required String code,
    required String username,
    required String password,
  }) async {
    await _setBridgeUrl(bridgeUrl);
    final session = await api.register(
      this.bridgeUrl,
      code,
      username,
      password,
    );
    await _saveSession(session);
  }

  Future<CreatedBridgeInvite> createInvite() {
    return api.createInvite(bridgeUrl, _requireToken());
  }

  Future<List<BridgeInvite>> listInvites() {
    return api.listInvites(bridgeUrl, _requireToken());
  }

  Future<void> revokeInvite(String inviteId) {
    return api.revokeInvite(bridgeUrl, _requireToken(), inviteId);
  }

  Future<void> signOut() async {
    final token = accessToken;
    try {
      if (token != null && bridgeUrl.isNotEmpty) {
        await api.logout(bridgeUrl, token);
      }
    } finally {
      await _clearSession();
    }
  }

  Future<void> invalidate() => _clearSession();

  Future<void> _setBridgeUrl(String value) async {
    final normalized = _normalizeBridgeUrl(value);
    if (normalized.isEmpty) {
      throw BridgeException('Enter the bridge address.');
    }
    if (bridgeUrl != normalized) {
      await _clearSession(notify: false);
      bridgeUrl = normalized;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_bridgeUrlKey, bridgeUrl);
    }
  }

  Future<void> _saveSession(BridgeSession session) async {
    await _secureStorage.write(
      key: _sessionTokenKey,
      value: session.accessToken,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_usernameKey, session.username);
    await preferences.setString(_roleKey, session.role);
    username = session.username;
    role = session.role;
    accessToken = session.accessToken;
    initialized = true;
    notifyListeners();
  }

  Future<void> _clearSession({bool notify = true}) async {
    await _secureStorage.delete(key: _sessionTokenKey);
    accessToken = null;
    role = '';
    if (notify) {
      notifyListeners();
    }
  }

  String _requireToken() {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw BridgeException('Sign in to your bridge first.');
    }
    return token;
  }

  String _normalizeBridgeUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');
}
