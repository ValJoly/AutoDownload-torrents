import 'dart:async';
import 'dart:convert';

import 'package:auto_torrent/core/app_preferences.dart';
import 'package:auto_torrent/core/auth_session.dart';
import 'package:auto_torrent/data/api/bridge_api.dart';
import 'package:auto_torrent/presentation/screens/appearance_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'stores theme mode and accent color across preference instances',
    () async {
      final preferences = AppPreferences();
      await preferences.initialize();

      const accent = Color(0xFF2E8B75);
      await preferences.setThemeMode(ThemeMode.dark);
      await preferences.setAccentColor(accent);

      final reloaded = AppPreferences();
      await reloaded.initialize();
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.accentColor, accent);
    },
  );

  testWidgets('offers theme modes, presets, and a custom color selector', (
    tester,
  ) async {
    final preferences = AppPreferences();
    await preferences.initialize();
    await tester.pumpWidget(
      MaterialApp(home: AppearanceSettingsScreen(preferences: preferences)),
    );

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Rose'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(preferences.themeMode, ThemeMode.dark);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Blue'));
    await tester.pumpAndSettle();
    final presetColor = preferences.accentColor;

    await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Custom accent color'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();
    expect(preferences.accentColor, isNot(presetColor));
  });

  testWidgets('checks the saved bridge and reports its health', (tester) async {
    final response = Completer<http.Response>();
    final api = BridgeApi(
      clientFactory: () => MockClient((_) => response.future),
    );
    final session = AuthSession(api: api)..bridgeUrl = 'http://bridge.local';

    await tester.pumpWidget(
      MaterialApp(
        home: AppearanceSettingsScreen(session: session),
      ),
    );
    await tester.tap(find.text('Check connection'));
    await tester.pump();

    expect(find.text('Checking…'), findsOneWidget);

    response.complete(http.Response(jsonEncode({'status': 'ok'}), 200));
    await tester.pumpAndSettle();
    expect(find.text('Server is reachable.'), findsOneWidget);
  });

  testWidgets('reports an unhealthy bridge response', (tester) async {
    final api = BridgeApi(
      clientFactory: () => MockClient(
        (_) async => http.Response(jsonEncode({'status': 'starting'}), 200),
      ),
    );
    final session = AuthSession(api: api)..bridgeUrl = 'http://bridge.local';

    await tester.pumpWidget(
      MaterialApp(
        home: AppearanceSettingsScreen(session: session),
      ),
    );
    await tester.tap(find.text('Check connection'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not connect: The bridge health check returned an unhealthy response.',
      ),
      findsOneWidget,
    );
  });
}
