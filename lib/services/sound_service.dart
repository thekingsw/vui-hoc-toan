import 'package:audioplayers/audioplayers.dart';

/// Âm thanh game (file wav offline trong assets/sounds, SPEC mục 13).
/// Có thể bật/tắt; lỗi phát âm thanh không được làm crash app.
class SoundService {
  SoundService()
      : _player = AudioPlayer(),
        _waves = AudioPlayer();

  final AudioPlayer _player;
  final AudioPlayer _waves;
  bool _enabled = true;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (!value) {
      stopWaves();
    }
  }

  Future<void> _play(String file) async {
    if (!_enabled) return;
    try {
      await _player.play(AssetSource('sounds/$file'));
    } catch (_) {
      // Bỏ qua lỗi âm thanh.
    }
  }

  Future<void> playCorrect() => _play('correct.wav');
  Future<void> playWrong() => _play('wrong.wav');
  Future<void> playTap() => _play('tap.wav');
  Future<void> playCombo() => _play('combo.wav');
  Future<void> playChest() => _play('chest.wav');
  Future<void> playStar() => _play('star.wav');
  Future<void> playCoin() => _play('coin.wav');
  Future<void> playBuy() => _play('buy.wav');
  Future<void> playUnlock() => _play('unlock.wav');

  /// Sóng biển nền: vòng lặp nhẹ ở bản đồ (SPEC mục 13).
  Future<void> startWaves() async {
    if (!_enabled) return;
    try {
      await _waves.setReleaseMode(ReleaseMode.loop);
      await _waves.setVolume(0.25);
      await _waves.play(AssetSource('sounds/waves.wav'));
    } catch (_) {
      // Bỏ qua lỗi âm thanh.
    }
  }

  Future<void> stopWaves() async {
    try {
      await _waves.stop();
    } catch (_) {
      // Bỏ qua lỗi âm thanh.
    }
  }

  void dispose() {
    _player.dispose();
    _waves.dispose();
  }
}
