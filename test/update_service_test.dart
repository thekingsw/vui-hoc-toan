import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/services/update_service.dart';

void main() {
  group('compareVersions', () {
    test('bản mới hơn', () {
      expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersions('1.1.0', '1.0.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('bản cũ hơn hoặc bằng', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0', '1.0.0'), 0);
    });

    test('chấp nhận tiền tố v và hậu tố build', () {
      expect(compareVersions('v1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersions('1.0.1+5', '1.0.0'), greaterThan(0));
    });
  });

  group('parseRelease', () {
    Map<String, dynamic> release(String tag, List<Map<String, String>> assets) {
      return {
        'tag_name': tag,
        'body': 'Ghi chú phát hành',
        'assets': [
          for (final a in assets)
            {'name': a['name'], 'browser_download_url': a['url']},
        ],
      };
    }

    test('có bản mới: ưu tiên file arm64-v8a', () {
      final info = parseRelease(
        release('v1.0.1', [
          {'name': 'app-armeabi-v7a-release.apk', 'url': 'https://x/v7a.apk'},
          {'name': 'app-arm64-v8a-release.apk', 'url': 'https://x/arm64.apk'},
        ]),
        '1.0.0',
      );
      expect(info, isNotNull);
      expect(info!.version, '1.0.1');
      expect(info.apkUrl, 'https://x/arm64.apk');
      expect(info.notes, 'Ghi chú phát hành');
    });

    test('không có bản mới thì trả null', () {
      final info = parseRelease(
        release('v1.0.0', [
          {'name': 'app-arm64-v8a-release.apk', 'url': 'https://x/a.apk'},
        ]),
        '1.0.0',
      );
      expect(info, isNull);
    });

    test('không có file APK thì trả null', () {
      final info = parseRelease(
        release('v1.0.1', [
          {'name': 'notes.txt', 'url': 'https://x/notes.txt'},
        ]),
        '1.0.0',
      );
      expect(info, isNull);
    });
  });
}
