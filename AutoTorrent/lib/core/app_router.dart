import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../data/api/bridge_api.dart';
import '../presentation/bloc/torrent_bloc.dart';
import '../presentation/screens/torrent_home_page.dart';
import 'app_keys.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: AppKeys.navigatorKey,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return BlocProvider(
            create: (_) => TorrentBloc(BridgeApi()),
            child: const TorrentHomePage(),
          );
        },
      ),
    ],
  );
}
