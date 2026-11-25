import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/game/shop/rewards.dart';
import 'package:toan_lop_5/game/shop/shop_items.dart';

void main() {
  group('xu theo sao Thử thách', () {
    test('tích lũy 30/60/100', () {
      expect(cumulativeStarCoins(0), 0);
      expect(cumulativeStarCoins(1), 30);
      expect(cumulativeStarCoins(2), 60);
      expect(cumulativeStarCoins(3), 100);
    });

    test('chỉ trả phần chênh khi lên mức', () {
      expect(starCoinReward(1, 0), 30);
      expect(starCoinReward(2, 1), 30);
      expect(starCoinReward(3, 2), 40);
      expect(starCoinReward(3, 0), 100);
      expect(starCoinReward(1, 2), 0);
      expect(starCoinReward(0, 0), 0);
    });

    test('khóa nhận theo từng mức, tổng bằng phần chênh', () {
      final claims = bossStarClaims('dao1', 3);
      expect(claims.map((c) => c.$1),
          ['boss:dao1:star1', 'boss:dao1:star2', 'boss:dao1:star3']);
      expect(claims.fold(0, (sum, c) => sum + c.$2), 100);
      expect(bossStarClaims('dao1', 0), isEmpty);
    });
  });

  group('khóa thưởng', () {
    test('đúng định dạng SPEC', () {
      expect(questionRewardKey('q1'), 'q:q1');
      expect(practiceRewardKey('bai1', 2), 'practice:bai1:2');
    });
  });

  group('shop items', () {
    test('parse + nhóm cùng slot', () {
      final items = parseShopItems({
        'items': [
          {
            'id': 'hat_a',
            'name': 'Mũ A',
            'slot': 'hat',
            'price': 40,
            'asset': 'a.webp',
            'anchor': {'x': 0.5, 'y': 0.1, 'scale': 0.5},
          },
          {
            'id': 'hat_b',
            'name': 'Mũ B',
            'slot': 'hat',
            'price': 60,
            'asset': 'b.webp',
            'anchor': {'x': 0.5, 'y': 0.1, 'scale': 0.5},
          },
          {
            'id': 'boat_a',
            'name': 'Thuyền',
            'slot': 'boat',
            'price': 250,
            'asset': 'c.webp',
          },
        ],
      });
      expect(items.length, 3);
      expect(items.first.isMascotItem, isTrue);
      expect(items.last.isMascotItem, isFalse);
      expect(slotItemIds(items, items.first), ['hat_a', 'hat_b']);
    });
  });
}
