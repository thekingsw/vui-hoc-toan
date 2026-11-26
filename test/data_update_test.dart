import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/services/content_store.dart';
import 'package:toan_lop_5/services/data_update_service.dart';

void main() {
  group('parseDataManifest (định dạng app Soạn bài)', () {
    test('manifest đúng thì đọc được', () {
      final m = parseDataManifest({
        'data_version': 3,
        'schema_version': 1,
        'min_app_version': '1.4.0',
        'islands': [
          {
            'island_id': 'on_tap_bo_sung',
            'file': 'on_tap_bo_sung.json',
            'version': 2,
            'sha256': 'abc',
          },
          {
            'island_id': 'so_thap_phan',
            'file': 'so_thap_phan.json',
            'version': 1,
            'sha256': 'def',
          },
        ],
      });
      expect(m, isNotNull);
      expect(m!.version, 3);
      expect(m.schemaVersion, 1);
      expect(m.minAppVersion, '1.4.0');
      expect(m.islands['on_tap_bo_sung']!.version, 2);
      expect(m.islands['on_tap_bo_sung']!.sha256, 'abc');
      expect(m.islands['so_thap_phan']!.file, 'so_thap_phan.json');
    });

    test('thiếu data_version hoặc islands thì trả null', () {
      expect(parseDataManifest({'islands': []}), isNull);
      expect(parseDataManifest({'data_version': 1}), isNull);
      expect(parseDataManifest({'data_version': 'x', 'islands': []}), isNull);
      // Định dạng cũ (islands là map) không còn được chấp nhận.
      expect(
          parseDataManifest({
            'version': 1,
            'islands': {'a': {'file': 'a.json', 'version': 1}},
          }),
          isNull);
    });

    test('đảo thiếu file/version thì bị bỏ qua, đảo khác vẫn đọc', () {
      final m = parseDataManifest({
        'data_version': 2,
        'islands': [
          {'island_id': 'a', 'version': 1},
          {'island_id': 'b', 'file': 'b.json'},
          {'island_id': 'c', 'file': 'c.json', 'version': 5},
        ],
      });
      expect(m!.islands.keys, ['c']);
    });
  });

  group('planDataUpdates', () {
    DataManifest remote(Map<String, int> versions) => DataManifest(
          version: 9,
          schemaVersion: 1,
          minAppVersion: '',
          islands: {
            for (final e in versions.entries)
              e.key: IslandDataEntry(
                  islandId: e.key, file: '${e.key}.json', version: e.value),
          },
        );

    test('kho trống: mọi đảo trên server đều được tải', () {
      final plan = planDataUpdates(
          {}, remote({'on_tap_bo_sung': 1, 'so_thap_phan': 1}));
      expect(plan, ['on_tap_bo_sung', 'so_thap_phan']);
    });

    test('đã có version 2: server version 2 thì không tải lại', () {
      final plan = planDataUpdates({'a': 2}, remote({'a': 2}));
      expect(plan, isEmpty);
    });

    test('server cũ hơn bản đã có thì không hạ cấp', () {
      final plan = planDataUpdates({'a': 5}, remote({'a': 3}));
      expect(plan, isEmpty);
    });

    test('bản dự phòng version 0: server version 1 là tải ngay', () {
      final plan = planDataUpdates({'on_tap_bo_sung': 0},
          remote({'on_tap_bo_sung': 1}));
      expect(plan, ['on_tap_bo_sung']);
    });
  });

  group('filterQuestionsForBuild', () {
    test('câu đòi build mới hơn app bị bỏ qua, câu thường giữ nguyên', () {
      final qs = [
        {'id': 'q1'},
        {'id': 'q2', 'min_app_version': 7},
        {'id': 'q3', 'min_app_version': 99},
      ];
      final kept = filterQuestionsForBuild(qs, 7);
      expect(kept.map((q) => q['id']), ['q1', 'q2']);
    });
  });

  group('compareVersions', () {
    test('so sánh phiên bản dạng x.y.z', () {
      expect(compareVersions('1.4.0', '1.4.0'), 0);
      expect(compareVersions('1.5.0', '1.4.9'), greaterThan(0));
      expect(compareVersions('1.4.0', '1.5.0'), lessThan(0));
      expect(compareVersions('2.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.4', '1.4.0'), 0);
    });
  });
}
