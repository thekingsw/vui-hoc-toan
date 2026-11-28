import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/services/haptic_service.dart';

void main() {
  group('hapticFor', () {
    test('tắt rung thì không rung sự kiện nào', () {
      for (final e in HapticEvent.values) {
        expect(
          hapticFor(e, hapticsEnabled: false, reduceEffects: false),
          isNull,
        );
      }
    });

    test('giảm hiệu ứng thì không rung', () {
      for (final e in HapticEvent.values) {
        expect(
          hapticFor(e, hapticsEnabled: true, reduceEffects: true),
          isNull,
        );
      }
    });

    test('mức rung theo sự kiện khi bật', () {
      HapticLevel? f(HapticEvent e) =>
          hapticFor(e, hapticsEnabled: true, reduceEffects: false);
      expect(f(HapticEvent.tap), HapticLevel.selection);
      expect(f(HapticEvent.correct), HapticLevel.light);
      expect(f(HapticEvent.wrong), HapticLevel.medium);
      expect(f(HapticEvent.combo), HapticLevel.medium);
      expect(f(HapticEvent.star), HapticLevel.light);
      expect(f(HapticEvent.chest), HapticLevel.heavy);
    });

    test('sai không bao giờ rung heavy', () {
      expect(
        hapticFor(HapticEvent.wrong,
            hapticsEnabled: true, reduceEffects: false),
        isNot(HapticLevel.heavy),
      );
    });
  });
}
