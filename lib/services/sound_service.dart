import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Âm thanh game (file ogg thật, nguồn CC0 — xem assets/sounds/CREDITS.md).
/// Có thể bật/tắt; lỗi phát âm thanh không được làm crash app.
///
/// Ba kênh: SFX (độ trễ thấp), sóng biển nền ở bản đồ, nhạc nền nhẹ
/// (chỉ ở bản đồ/màn đảo — vào màn câu hỏi thì tắt). App xuống nền thì
/// dừng cả sóng lẫn nhạc, quay lại thì phát tiếp.
class SoundService with WidgetsBindingObserver {
  SoundService()
      : _player = AudioPlayer(),
        _waves = AudioPlayer(),
        _music = AudioPlayer() {
    _player.setPlayerMode(PlayerMode.lowLatency);
    WidgetsBinding.instance.addObserver(this);
    _preload();
  }

  final AudioPlayer _player;
  final AudioPlayer _waves;
  final AudioPlayer _music;
  bool _enabled = true;
  bool _musicEnabled = true;
  bool _musicWanted = false;
  bool _wavesWanted = false;

  bool get enabled => _enabled;

  set enabled(bool value) {
    _enabled = value;
    if (!value) {
      stopWaves();
      stopMusic();
    }
  }

  bool get musicEnabled => _musicEnabled;

  set musicEnabled(bool value) {
    _musicEnabled = value;
    if (!value) {
      _music.stop();
    } else if (_musicWanted) {
      startMusic();
    }
  }

  static const _sfxFiles = [
    'correct.ogg',
    'wrong.ogg',
    'tap.ogg',
    'combo.ogg',
    'chest.ogg',
    'star.ogg',
    'coin.ogg',
    'buy.ogg',
    'unlock.ogg',
    'quest_done.ogg',
    'bottle.ogg',
    'badge.ogg',
    'boss_hit.ogg',
    'boss_defeat.ogg',
  ];

  Future<void> _preload() async {
    try {
      await AudioCache.instance.loadAll([
        for (final f in _sfxFiles) 'sounds/$f',
        'sounds/waves.ogg',
        'sounds/music_sea.ogg',
      ]);
    } catch (_) {
      // Nạp trước thất bại thì phát trực tiếp lúc cần.
    }
  }

  Future<void> _play(String file, {double rate = 1.0}) async {
    if (!_enabled) return;
    try {
      await _player.setPlaybackRate(rate);
      await _player.play(AssetSource('sounds/$file'));
    } catch (_) {
      // Bỏ qua lỗi âm thanh.
    }
  }

  /// Âm đúng tăng tông theo chuỗi đúng liên tiếp (combo).
  Future<void> playCorrect({int combo = 0}) {
    final rate = 1.0 + 0.05 * (combo > 6 ? 6 : combo);
    return _play('correct.ogg', rate: rate);
  }

  Future<void> playWrong() => _play('wrong.ogg');
  Future<void> playTap() => _play('tap.ogg');
  Future<void> playCombo() => _play('combo.ogg');
  Future<void> playChest() => _play('chest.ogg');
  Future<void> playStar() => _play('star.ogg');
  Future<void> playCoin() => _play('coin.ogg');
  Future<void> playBuy() => _play('buy.ogg');
  Future<void> playUnlock() => _play('unlock.ogg');
  Future<void> playQuestDone() => _play('quest_done.ogg');
  Future<void> playBottle() => _play('bottle.ogg');
  Future<void> playBadge() => _play('badge.ogg');
  Future<void> playBossHit() => _play('boss_hit.ogg');
  Future<void> playBossDefeat() => _play('boss_defeat.ogg');

  /// Sóng biển nền: vòng lặp nhẹ ở bản đồ.
  Future<void> startWaves() async {
    _wavesWanted = true;
    if (!_enabled) return;
    try {
      await _waves.setReleaseMode(ReleaseMode.loop);
      await _waves.setVolume(0.25);
      await _waves.play(AssetSource('sounds/waves.ogg'));
    } catch (_) {
      // Bỏ qua lỗi âm thanh.
    }
  }

  Future<void> stopWaves() async {
    _wavesWanted = false;
    try {
      await _waves.stop();
    } catch (_) {
      // Bỏ qua lỗi âm thanh.
    }
  }

  /// Nhạc nền nhẹ ở bản đồ/màn đảo (âm lượng thấp, lặp vòng).
  Future<void> startMusic() async {
    _musicWanted = true;
    if (!_enabled || !_musicEnabled) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.15);
      await _music.play(AssetSource('sounds/music_sea.ogg'));
    } catch (_) {
      // Bỏ qua lỗi âm thanh.
    }
  }

  Future<void> stopMusic() async {
    _musicWanted = false;
    try {
      await _music.stop();
    } catch (_) {
      // Bỏ qua lỗi âm thanh.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _waves.pause();
      _music.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_wavesWanted) _waves.resume();
      if (_musicWanted) _music.resume();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    _waves.dispose();
    _music.dispose();
  }
}
