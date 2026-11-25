import 'package:flutter_test/flutter_test.dart';
import 'package:toan_lop_5/game/map/island_state.dart';
import 'package:toan_lop_5/game/map/map_layout.dart';
import 'package:toan_lop_5/game/scene/node_state.dart';
import 'package:toan_lop_5/game/scene/scene_config.dart';

void main() {
  group('islandDisplayState', () {
    test('chưa có dữ liệu là đảo bí ẩn', () {
      expect(
        islandDisplayState(hasData: false, unlocked: true, bestStars: 3),
        IslandDisplayState.mystery,
      );
    });

    test('có dữ liệu nhưng chưa mở là khóa', () {
      expect(
        islandDisplayState(hasData: true, unlocked: false, bestStars: 0),
        IslandDisplayState.locked,
      );
    });

    test('đã mở chưa có sao là đang chơi, có sao là hoàn thành', () {
      expect(
        islandDisplayState(hasData: true, unlocked: true, bestStars: 0),
        IslandDisplayState.current,
      );
      expect(
        islandDisplayState(hasData: true, unlocked: true, bestStars: 1),
        IslandDisplayState.completed,
      );
    });
  });

  group('currentIslandId', () {
    const order = ['a', 'b', 'c'];
    test('ưu tiên đảo đang chơi đầu tiên', () {
      expect(
        currentIslandId(order, {
          'a': IslandDisplayState.completed,
          'b': IslandDisplayState.current,
          'c': IslandDisplayState.locked,
        }),
        'b',
      );
    });

    test('xong hết thì ở đảo hoàn thành cuối cùng', () {
      expect(
        currentIslandId(order, {
          'a': IslandDisplayState.completed,
          'b': IslandDisplayState.completed,
          'c': IslandDisplayState.mystery,
        }),
        'b',
      );
    });
  });

  group('node state', () {
    const lessons = ['l1', 'l2', 'l3'];
    test('gợi ý bài đầu tiên chưa xong', () {
      expect(suggestedLessonIndex(lessons, {'l1'}), 1);
      expect(suggestedLessonIndex(lessons, {'l1', 'l2', 'l3'}), -1);
      expect(suggestedLessonIndex(lessons, <String>{}), 0);
    });

    test('trạng thái điểm dừng', () {
      final done = {'l1'};
      final viewed = {'l3'};
      const suggested = 1;
      expect(
        nodeDisplayState(
            lessonId: 'l1',
            index: 0,
            doneIds: done,
            viewedIds: viewed,
            suggestedIndex: suggested),
        NodeDisplayState.done,
      );
      expect(
        nodeDisplayState(
            lessonId: 'l2',
            index: 1,
            doneIds: done,
            viewedIds: viewed,
            suggestedIndex: suggested),
        NodeDisplayState.suggested,
      );
      expect(
        nodeDisplayState(
            lessonId: 'l3',
            index: 2,
            doneIds: done,
            viewedIds: viewed,
            suggestedIndex: suggested),
        NodeDisplayState.viewed,
      );
    });
  });

  group('parse config', () {
    test('map_layout', () {
      final layout = parseMapLayout({
        'canvas_height_per_island': 300,
        'islands': [
          {'id': 'a', 'x': 0.3, 'y': 0, 'scale': 1.0},
          {'id': 'b', 'x': 0.7, 'y': 1, 'scale': 1.2},
        ],
        'path_style': {
          'dash': [12, 6],
          'width': 5,
        },
      });
      expect(layout.canvasHeightPerIsland, 300);
      expect(layout.islands.length, 2);
      expect(layout.spotFor('b')!.scale, 1.2);
      expect(layout.dashOn, 12);
      expect(layout.pathWidth, 5);
    });

    test('scene config', () {
      final cfg = parseSceneConfig({
        'background': 'bg.webp',
        'height_ratio': 1.9,
        'nodes': [
          {'lesson_id': 'l1', 'x': 0.3, 'y': 0.9, 'icon': 'node_palm'},
        ],
        'boss': {'x': 0.5, 'y': 0.05},
      });
      expect(cfg.heightRatio, 1.9);
      expect(cfg.nodeFor('l1')!.icon, 'node_palm');
      expect(cfg.bossY, 0.05);
    });
  });
}
