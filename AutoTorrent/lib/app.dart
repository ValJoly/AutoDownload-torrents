import 'package:flutter/material.dart';

import 'core/app_keys.dart';
import 'core/app_router.dart';

class AutoTorrentApp extends StatelessWidget {
  const AutoTorrentApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF6F7F9);
    return MaterialApp.router(
      title: 'AutoTorrent',
      routerConfig: AppRouter.router,
      scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
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
    );
  }
}
