import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Bố cục bản đồ biển (assets/config/map_layout.json).
/// Tọa độ chuẩn hóa: x 0–1 theo bề rộng canvas, y tính theo đơn vị đảo
/// (0 = đảo 1 ở dưới cùng, hành trình đi từ dưới lên).
class MapIslandSpot {
  const MapIslandSpot({
    required this.id,
    required this.x,
    required this.y,
    required this.scale,
  });

  final String id;
  final double x;
  final double y;
  final double scale;
}

class MapLayoutData {
  const MapLayoutData({
    required this.canvasHeightPerIsland,
    required this.islands,
    required this.dashOn,
    required this.dashOff,
    required this.pathWidth,
  });

  final double canvasHeightPerIsland;
  final List<MapIslandSpot> islands;
  final double dashOn;
  final double dashOff;
  final double pathWidth;

  MapIslandSpot? spotFor(String islandId) {
    for (final s in islands) {
      if (s.id == islandId) return s;
    }
    return null;
  }
}

MapLayoutData parseMapLayout(Map<String, dynamic> json) {
  final islands = <MapIslandSpot>[];
  final rawIslands = json['islands'];
  if (rawIslands is List) {
    for (final raw in rawIslands) {
      if (raw is! Map) continue;
      islands.add(MapIslandSpot(
        id: '${raw['id'] ?? ''}',
        x: (raw['x'] as num?)?.toDouble() ?? 0.5,
        y: (raw['y'] as num?)?.toDouble() ?? 0,
        scale: (raw['scale'] as num?)?.toDouble() ?? 1.0,
      ));
    }
  }
  final style = json['path_style'];
  var dashOn = 10.0, dashOff = 8.0, width = 4.0;
  if (style is Map) {
    final dash = style['dash'];
    if (dash is List && dash.length >= 2) {
      dashOn = (dash[0] as num).toDouble();
      dashOff = (dash[1] as num).toDouble();
    }
    width = (style['width'] as num?)?.toDouble() ?? width;
  }
  return MapLayoutData(
    canvasHeightPerIsland:
        (json['canvas_height_per_island'] as num?)?.toDouble() ?? 340,
    islands: islands,
    dashOn: dashOn,
    dashOff: dashOff,
    pathWidth: width,
  );
}

Future<MapLayoutData> loadMapLayout() async {
  final text = await rootBundle.loadString('assets/config/map_layout.json');
  return parseMapLayout(jsonDecode(text) as Map<String, dynamic>);
}
