import 'package:flutter_test/flutter_test.dart';

import 'package:auto_torrent/app.dart';

void main() {
  testWidgets('shows the SkyForge search screen', (tester) async {
    await tester.pumpWidget(const AutoTorrentApp());

    expect(find.text('SkyForge'), findsOneWidget);
    expect(find.text('Find something to download'), findsOneWidget);
    expect(find.text('Audiobooks'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
  });

  testWidgets('opens the settings popup from the app bar', (tester) async {
    await tester.pumpWidget(const AutoTorrentApp());

    await tester.tap(find.byTooltip('Bridge settings'));
    await tester.pumpAndSettle();

    expect(find.text('Bridge connection'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('settings dialog closes without leaking a disposed controller', (
    tester,
  ) async {
    await tester.pumpWidget(const AutoTorrentApp());

    await tester.tap(find.byTooltip('Bridge settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
