import 'package:flutter_test/flutter_test.dart';

import 'package:auto_torrent/app.dart';

void main() {
  testWidgets('shows the AutoTorrent search screen', (tester) async {
    await tester.pumpWidget(const AutoTorrentApp());

    expect(find.text('AutoTorrent'), findsOneWidget);
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
}
