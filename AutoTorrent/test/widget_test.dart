import 'package:flutter_test/flutter_test.dart';

import 'package:auto_torrent/main.dart';

void main() {
  testWidgets('shows the AutoTorrent search screen', (tester) async {
    await tester.pumpWidget(const AutoTorrentApp());

    expect(find.text('AutoTorrent'), findsOneWidget);
    expect(find.text('Find something to download'), findsOneWidget);
    expect(find.text('Audiobooks'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
  });
}
