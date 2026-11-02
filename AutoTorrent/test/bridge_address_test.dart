import 'package:auto_torrent/data/api/bridge_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bridge address gets a scheme and loses trailing slashes', () {
    expect(
      normalizeBridgeAddress('skyforge.example.dev/'),
      'https://skyforge.example.dev',
    );
    expect(
      normalizeBridgeAddress(' 192.168.1.5:8384 '),
      'http://192.168.1.5:8384',
    );
    expect(normalizeBridgeAddress('localhost'), 'http://localhost');
    expect(normalizeBridgeAddress('http://a.b/'), 'http://a.b');
    expect(normalizeBridgeAddress(''), '');
  });
}
