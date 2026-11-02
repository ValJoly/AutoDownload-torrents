import 'package:flutter/material.dart';

import 'core/app_keys.dart';
import 'core/app_preferences.dart';
import 'core/app_router.dart';
import 'presentation/widgets/brutal.dart';

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
          theme: buildAppTheme(
            appPreferences.accentColor,
            Brightness.light,
            neubrutalism: appPreferences.neubrutalism,
          ),
          darkTheme: buildAppTheme(
            appPreferences.accentColor,
            Brightness.dark,
            neubrutalism: appPreferences.neubrutalism,
          ),
          themeMode: appPreferences.themeMode,
          themeAnimationDuration: Duration.zero,
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

ThemeData buildAppTheme(
  Color accentColor,
  Brightness brightness, {
  required bool neubrutalism,
}) => neubrutalism
    ? _buildBrutalTheme(accentColor, brightness)
    : _buildClassicTheme(accentColor, brightness);

ThemeData _buildClassicTheme(Color accentColor, Brightness brightness) {
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

ThemeData _buildBrutalTheme(Color accentColor, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? const Color(0xFFF5F0E6) : const Color(0xFF111111);
  final background = dark ? const Color(0xFF121212) : const Color(0xFFFFF1D6);
  final surface = dark ? const Color(0xFF1F1F23) : Colors.white;
  final onAccent =
      ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
      ? Colors.white
      : const Color(0xFF111111);
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
      ).copyWith(
        primary: accentColor,
        onPrimary: onAccent,
        primaryContainer: accentColor,
        onPrimaryContainer: onAccent,
        secondaryContainer: accentColor,
        onSecondaryContainer: onAccent,
        onSurface: ink,
        outline: ink,
        outlineVariant: ink,
        surfaceContainerHighest: surface,
      );
  final border = BorderSide(color: ink, width: brutalBorderWidth);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(brutalRadius),
    side: border,
  );
  final buttonStyle = ButtonStyle(
    shape: WidgetStatePropertyAll(shape),
    elevation: const WidgetStatePropertyAll(0),
    minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    // inherit: false matches the default M3 button text style, so Material's
    // animated button text can interpolate between the two themes.
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        inherit: false,
        fontSize: 14,
        height: 1.43,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.3,
      ),
    ),
  );
  OutlineInputBorder inputBorder(double width, [Color? color]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(brutalRadius),
        borderSide: BorderSide(color: color ?? ink, width: width),
      );

  final base = ThemeData(
    extensions: const [BrutalStyle()],
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: accentColor,
      foregroundColor: onAccent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: border),
      titleTextStyle: TextStyle(
        color: onAccent,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    ),
    cardTheme: CardThemeData(color: surface, elevation: 0, shape: shape),
    filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: TextButtonThemeData(style: buttonStyle),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(shape),
        side: WidgetStatePropertyAll(border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(brutalRadius),
        side: BorderSide(color: ink, width: 3),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surface,
      contentTextStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
      shape: shape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
      floatingLabelStyle: TextStyle(color: ink, fontWeight: FontWeight.w900),
      hintStyle: TextStyle(color: ink.withAlpha(130)),
      prefixIconColor: ink,
      suffixIconColor: ink,
      border: inputBorder(brutalBorderWidth),
      enabledBorder: inputBorder(brutalBorderWidth),
      focusedBorder: inputBorder(3.5),
      errorBorder: inputBorder(brutalBorderWidth, colorScheme.error),
      focusedErrorBorder: inputBorder(3.5, colorScheme.error),
    ),
    chipTheme: ChipThemeData(
      selectedColor: accentColor,
      backgroundColor: surface,
      showCheckmark: false,
      labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
      secondaryLabelStyle: TextStyle(
        color: onAccent,
        fontWeight: FontWeight.w700,
      ),
      shape: shape,
      side: border,
    ),
  );
  final text = base.textTheme;
  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}
