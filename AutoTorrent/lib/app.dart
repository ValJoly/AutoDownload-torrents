import 'package:flutter/material.dart';

import 'core/app_keys.dart';
import 'core/app_router.dart';

const appThemeColor = Color(0xFF5B4BDE);

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
          seedColor: appThemeColor,
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
            borderSide: const BorderSide(color: appThemeColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
