import 'package:flutter/services.dart';

/// Sự kiện có phản hồi rung.
enum HapticEvent {
  tap,
  correct,
  wrong,
  combo,
  star,
  chest,
}

/// Mức rung cho từng sự kiện (null = không rung).
/// Sai dùng medium, không bao giờ heavy — không làm bé giật mình.
enum HapticLevel { selection, light, medium, heavy }

/// Hàm thuần quyết định rung: chỉ rung khi phụ huynh bật rung và
/// không bật giảm hiệu ứng.
HapticLevel? hapticFor(
  HapticEvent event, {
  required bool hapticsEnabled,
  required bool reduceEffects,
}) {
  if (!hapticsEnabled || reduceEffects) return null;
  return switch (event) {
    HapticEvent.tap => HapticLevel.selection,
    HapticEvent.correct => HapticLevel.light,
    HapticEvent.wrong => HapticLevel.medium,
    HapticEvent.combo => HapticLevel.medium,
    HapticEvent.star => HapticLevel.light,
    HapticEvent.chest => HapticLevel.heavy,
  };
}

/// Bọc HapticFeedback, kiểm tra điều kiện bật trước khi rung.
class HapticService {
  bool enabled = true;
  bool reduceEffects = false;

  void fire(HapticEvent event) {
    final level = hapticFor(
      event,
      hapticsEnabled: enabled,
      reduceEffects: reduceEffects,
    );
    switch (level) {
      case HapticLevel.selection:
        HapticFeedback.selectionClick();
      case HapticLevel.light:
        HapticFeedback.lightImpact();
      case HapticLevel.medium:
        HapticFeedback.mediumImpact();
      case HapticLevel.heavy:
        HapticFeedback.heavyImpact();
      case null:
        break;
    }
  }
}
