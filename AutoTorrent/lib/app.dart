import 'package:flutter/material.dart';

import 'core/app_keys.dart';
import 'core/app_preferences.dart';
import 'core/app_router.dart';

class AutoTorrentApp extends StatefulWidget {
  const AutoTorrentApp({super.key});

  @override
  State<AutoTorrentApp> createState() => _AutoTorrentAppState();
}

class _AutoTorrentAppState extends State<AutoTorrentApp> {
  late final Future<void> _preferencesReady = appPreferences.initialize();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _preferencesReady,
    builder: (context, snapshot) {
      return AnimatedBuilder(
        animation: appPreferences,
        builder: (context, _) => MaterialApp.router(
          title: 'SkyForge',
          routerConfig: AppRouter.router,
          scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(appPreferences.accentColor, Brightness.light),
          darkTheme: _buildTheme(appPreferences.accentColor, Brightness.dark),
          themeMode: appPreferences.themeMode,
          builder: (context, child) => snapshot.hasError
              ? Column(
                  children: [
                    MaterialBanner(
                      content: Text(
                        'Unable to load appearance settings: ${snapshot.error}',
                      ),
                      actions: const [SizedBox.shrink()],
                    ),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                )
              : child ?? const SizedBox.shrink(),
        ),
      );
    },
  );
}

ThemeData _buildTheme(Color accentColor, Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accentColor,
    brightness: brightness,
  );
  final background = brightness == Brightness.light
      ? const Color(0xFFFFF7FA)
      : const Color(0xFF121116);

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: colorScheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
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
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: colorScheme.primary,
      secondarySelectedColor: colorScheme.secondaryContainer,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: colorScheme.outline),
    ),
  );
}
