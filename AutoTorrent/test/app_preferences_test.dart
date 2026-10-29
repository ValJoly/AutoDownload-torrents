import 'dart:async';
import 'dart:convert';

import 'package:auto_torrent/core/app_preferences.dart';
import 'package:auto_torrent/core/auth_session.dart';
import 'package:auto_torrent/data/api/bridge_api.dart';
import 'package:auto_torrent/presentation/screens/appearance_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({
      'bridge_session_token': 'session-token',
    });
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

  test('neubrutalism style defaults on and persists when turned off', () async {
    final preferences = AppPreferences();
    await preferences.initialize();
    expect(preferences.neubrutalism, isTrue);

    await preferences.setNeubrutalism(false);

    final reloaded = AppPreferences();
    await reloaded.initialize();
    expect(reloaded.neubrutalism, isFalse);
  });

  testWidgets('settings toggle switches the neubrutalism style', (
    tester,
  ) async {
    final preferences = AppPreferences();
    await preferences.initialize();
    await tester.pumpWidget(
      MaterialApp(home: AppearanceSettingsScreen(preferences: preferences)),
    );

    await tester.tap(find.byKey(const Key('neubrutalism-toggle')));
    await tester.pumpAndSettle();
    expect(preferences.neubrutalism, isFalse);
  });

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

  testWidgets('shows and saves the bridge server address', (tester) async {
    final api = BridgeApi(
      clientFactory: () => MockClient(
        (_) async =>
            http.Response(jsonEncode({'tr4cker': true, 'c411': false}), 200),
      ),
    );
    final session = AuthSession(api: api)
      ..bridgeUrl = 'http://old-bridge.local'
      ..accessToken = 'session-token'
      ..role = 'owner';

    await tester.pumpWidget(
      MaterialApp(home: AppearanceSettingsScreen(session: session)),
    );

    final addressField = find.byKey(const Key('server-address'));
    expect(
      tester.widget<TextFormField>(addressField).controller!.text,
      'http://old-bridge.local',
    );
    await tester.enterText(addressField, 'https://new-bridge.local/');
    await tester.tap(find.byKey(const Key('save-server-address')));
    await tester.pumpAndSettle();

    expect(session.bridgeUrl, 'https://new-bridge.local');
    expect(session.accessToken, isNull);
    expect(session.isSignedIn, isFalse);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('bridge_url'), 'https://new-bridge.local');
    expect(
      find.text('Server address saved. Sign in again to use this server.'),
      findsOneWidget,
    );
  });

  testWidgets('checks the saved bridge and reports its health', (tester) async {
    final response = Completer<http.Response>();
    final api = BridgeApi(
      clientFactory: () => MockClient((request) {
        if (request.url.path == '/health') return response.future;
        return Future.value(
          http.Response(jsonEncode({'tr4cker': true, 'c411': false}), 200),
        );
      }),
    );
    final session = AuthSession(api: api)..bridgeUrl = 'http://bridge.local';

    await tester.pumpWidget(
      MaterialApp(home: AppearanceSettingsScreen(session: session)),
    );
    await tester.tap(find.text('Check connection'));
    await tester.pump();

    expect(find.text('Checking…'), findsOneWidget);

    response.complete(http.Response(jsonEncode({'status': 'ok'}), 200));
    await tester.pumpAndSettle();
    expect(
      find.text('Server is reachable and providers are updated.'),
      findsOneWidget,
    );
  });

  testWidgets('reports an unhealthy bridge response', (tester) async {
    final api = BridgeApi(
      clientFactory: () => MockClient(
        (_) async => http.Response(jsonEncode({'status': 'starting'}), 200),
      ),
    );
    final session = AuthSession(api: api)..bridgeUrl = 'http://bridge.local';

    await tester.pumpWidget(
      MaterialApp(home: AppearanceSettingsScreen(session: session)),
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

  testWidgets('reports provider discovery failures separately', (tester) async {
    final api = BridgeApi(
      clientFactory: () => MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response(jsonEncode({'status': 'ok'}), 200);
        }
        return http.Response('unavailable', 503);
      }),
    );
    final session = AuthSession(api: api)..bridgeUrl = 'http://bridge.local';

    await tester.pumpWidget(
      MaterialApp(home: AppearanceSettingsScreen(session: session)),
    );
    await tester.tap(find.text('Check connection'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Server is reachable, but provider availability could not be checked: '
        'Bridge error (503). Check the bridge logs.',
      ),
      findsOneWidget,
    );
  });
}
