import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/auth_screen.dart';
import '../presentation/screens/downloads_screen.dart';
import '../presentation/screens/invite_management_screen.dart';
import '../presentation/bloc/torrent_bloc.dart';
import '../presentation/screens/torrent_home_page.dart';
import 'app_keys.dart';
import 'auth_session.dart';

class AppRouter {
  static final AuthSession session = AuthSession();
  static final GoRouter router = _createRouter();

  static GoRouter _createRouter() {
    unawaited(session.initialize());
    return GoRouter(
      navigatorKey: AppKeys.navigatorKey,
      refreshListenable: session,
      redirect: (context, state) {
        final path = state.uri.path;
        if (!session.initialized) return path == '/loading' ? null : '/loading';
        if (!session.isSignedIn) {
          return path == '/signup' || path == '/auth' ? null : '/auth';
        }
        if (path == '/loading' || path == '/auth' || path == '/signup') {
          return '/';
        }
        if (path == '/invites' && !session.isOwner) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/loading',
          builder: (context, state) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) =>
              AuthScreen(session: session, registration: false),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) =>
              AuthScreen(session: session, registration: true),
        ),
        ShellRoute(
          builder: (context, state, child) => BlocProvider(
            create: (_) => TorrentBloc(
              session.api,
              onUnauthorized: session.invalidate,
              initialBridgeUrl: session.bridgeUrl,
              initialSessionToken: session.accessToken,
            ),
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => TorrentHomePage(session: session),
            ),
            GoRoute(
              path: '/downloads',
              builder: (context, state) => DownloadsScreen(session: session),
            ),
          ],
        ),
        GoRoute(
          path: '/invites',
          builder: (context, state) => InviteManagementScreen(session: session),
        ),
      ],
    );
  }
}
