import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Cấu hình cảnh một đảo (assets/config/island_scenes/{island_id}.json).
/// Tọa độ chuẩn hóa 0–1 theo canvas của cảnh; y tính từ trên xuống
/// (điểm dừng đầu ở dưới cùng, rương ở trên cùng).
class SceneNodeSpot {
  const SceneNodeSpot({
    required this.lessonId,
    required this.x,
    required this.y,
    required this.icon,
  });

  final String lessonId;
  final double x;
  final double y;

  /// Tên ảnh điểm dừng (assets/images/nodes/{icon}.webp) — đợt 3 mới có ảnh.
  final String icon;
}

class IslandSceneConfig {
  const IslandSceneConfig({
    required this.background,
    required this.heightRatio,
    required this.nodes,
    required this.bossX,
    required this.bossY,
  });

  /// Đường dẫn ảnh nền (có thể chưa tồn tại — vẽ bằng code thay thế).
  final String background;

  /// Chiều cao cảnh = bề rộng × tỉ lệ này.
  final double heightRatio;
  final List<SceneNodeSpot> nodes;
  final double bossX;
  final double bossY;

  SceneNodeSpot? nodeFor(String lessonId) {
    for (final n in nodes) {
      if (n.lessonId == lessonId) return n;
    }
    return null;
  }
}

IslandSceneConfig parseSceneConfig(Map<String, dynamic> json) {
  final nodes = <SceneNodeSpot>[];
  final rawNodes = json['nodes'];
  if (rawNodes is List) {
    for (final raw in rawNodes) {
      if (raw is! Map) continue;
      nodes.add(SceneNodeSpot(
        lessonId: '${raw['lesson_id'] ?? ''}',
        x: (raw['x'] as num?)?.toDouble() ?? 0.5,
        y: (raw['y'] as num?)?.toDouble() ?? 0.5,
        icon: '${raw['icon'] ?? ''}',
      ));
    }
  }
  final boss = json['boss'];
  return IslandSceneConfig(
    background: '${json['background'] ?? ''}',
    heightRatio: (json['height_ratio'] as num?)?.toDouble() ?? 1.6,
    nodes: nodes,
    bossX: boss is Map ? (boss['x'] as num?)?.toDouble() ?? 0.5 : 0.5,
    bossY: boss is Map ? (boss['y'] as num?)?.toDouble() ?? 0.08 : 0.08,
  );
}

/// Nạp cấu hình cảnh; đảo chưa có file cấu hình thì trả về null
/// (màn đảo tự xếp điểm dừng theo đường cong mặc định).
Future<IslandSceneConfig?> loadSceneConfig(String islandId) async {
  try {
    final text = await rootBundle
        .loadString('assets/config/island_scenes/$islandId.json');
    return parseSceneConfig(jsonDecode(text) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}
