import 'package:flutter/material.dart';

import 'core/app_keys.dart';
import 'core/app_router.dart';

const appThemeColor = Color(0xFFEAA4BD);
const appSoftColor = Color(0xFFFFDCEB);

class AutoTorrentApp extends StatelessWidget {
  const AutoTorrentApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFFFF7FA);
    return MaterialApp.router(
      title: 'SkyForge',
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
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Color(0xFF523157),
        ),
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
        chipTheme: ChipThemeData(
          selectedColor: appThemeColor,
          secondarySelectedColor: appSoftColor,
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: const BorderSide(color: appThemeColor, width: 1),
        ),
      ),
    );
  }
}
