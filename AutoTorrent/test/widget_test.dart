import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auto_torrent/app.dart';
import 'package:auto_torrent/core/app_router.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
  });

  tearDown(() {
    AppRouter.router.go('/auth');
  });

  testWidgets('shows sign-in before the protected search screen', (
    tester,
  ) async {
    await tester.pumpWidget(const AutoTorrentApp());
    await tester.pumpAndSettle();

    expect(find.text('SkyForge'), findsOneWidget);
    expect(find.text('Sign in to your bridge'), findsOneWidget);
    expect(find.text('Invite code'), findsNothing);
  });

  testWidgets('sign-up route requires an invite code', (tester) async {
    await tester.pumpWidget(const AutoTorrentApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('open-sign-up')));
    await tester.tap(find.byKey(const Key('open-sign-up')));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Invite code'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
  });

  testWidgets('can switch back from sign-up to sign-in', (tester) async {
    await tester.pumpWidget(const AutoTorrentApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('open-sign-up')));
    await tester.tap(find.byKey(const Key('open-sign-up')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('open-sign-in')));
    await tester.tap(find.byKey(const Key('open-sign-in')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your bridge'), findsOneWidget);
    expect(find.text('Invite code'), findsNothing);
  });
}
