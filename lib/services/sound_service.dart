import 'package:audioplayers/audioplayers.dart';

/// Âm thanh đúng/sai (file wav offline trong assets/sounds).
/// Có thể bật/tắt; lỗi phát âm thanh không được làm crash app.
class SoundService {
  SoundService() : _player = AudioPlayer();

  final AudioPlayer _player;
  bool enabled = true;

  Future<void> playCorrect() async {
    if (!enabled) return;
    try {
      await _player.play(AssetSource('sounds/correct.wav'));
    } catch (_) {
      // Bỏ qua lỗi âm thanh ở MVP.
    }
  }

  Future<void> playWrong() async {
    if (!enabled) return;
    try {
      await _player.play(AssetSource('sounds/wrong.wav'));
    } catch (_) {
      // Bỏ qua lỗi âm thanh ở MVP.
    }
  }

  void dispose() {
    _player.dispose();
  }
}
