import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../providers/app_providers.dart';
import '../services/data_update_service.dart';
import '../services/review_logic.dart';
import '../theme/game_theme.dart';

/// Góc phụ huynh tối giản (MVP):
/// - Khóa PIN 4 số (mặc định 1234, đổi được ngay trong màn này).
/// - Mở khóa tay từng đảo (không cần đạt sao).
/// - Reset tiến độ (không đổi PIN).
/// - Bật/tắt âm thanh.
/// Thống kê, chủ đề yếu, giới hạn giờ/ngày là giai đoạn 3.
class ParentScreen extends ConsumerStatefulWidget {
  const ParentScreen({super.key});

  @override
  ConsumerState<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends ConsumerState<ParentScreen> {
  final _pinController = TextEditingController();
  bool _unlocked = false;
  String? _error;
  int? _dataVersion;
  bool _checkingData = false;

  @override
  void initState() {
    super.initState();
    currentDataVersion().then((v) {
      if (mounted) setState(() => _dataVersion = v);
    });
  }

  Future<void> _checkDataUpdate() async {
    setState(() => _checkingData = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await checkAndUpdateData();
    if (!mounted) return;
    setState(() {
      _checkingData = false;
      _dataVersion = result.currentVersion;
    });
    if (result.hasUpdates) {
      ref.invalidate(islandsProvider);
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                'Đã cập nhật bài học mới (phiên bản dữ liệu ${result.currentVersion}).')),
      );
    } else if (result.errors.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errors.first)),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Dữ liệu bài học đã là bản mới nhất.')),
      );
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkPin() async {
    final db = ref.read(databaseProvider);
    final ok = await db.verifyPin(_pinController.text.trim());
    setState(() {
      if (ok) {
        _unlocked = true;
        _error = null;
      } else {
        _error = 'PIN chưa đúng, thử lại nhé.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Góc phụ huynh')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nhập PIN 4 số để vào Góc phụ huynh.',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '••••',
                  counterText: '',
                ),
                onSubmitted: (_) => _checkPin(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _checkPin,
                  child: const Text('Mở khóa', style: TextStyle(fontSize: 19)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progressAsync = ref.watch(islandProgressProvider);
    final soundOn = ref.watch(soundOnProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Góc phụ huynh')),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (progress) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _LearningOverview(),
              const Divider(),
              SwitchListTile(
                title: const Text('Âm thanh',
                    style: TextStyle(fontSize: 18)),
                value: soundOn,
                onChanged: (value) async {
                  final db = ref.read(databaseProvider);
                  ref.read(soundOnProvider.notifier).state = value;
                  ref.read(soundServiceProvider).enabled = value;
                  await db.setSoundOn(value);
                },
              ),
              SwitchListTile(
                title: const Text('Giảm hiệu ứng',
                    style: TextStyle(fontSize: 18)),
                subtitle: const Text(
                    'Tắt pháo giấy, giảm chuyển động cho máy yếu'),
                value: ref.watch(reduceEffectsProvider),
                onChanged: (value) async {
                  final db = ref.read(databaseProvider);
                  ref.read(reduceEffectsProvider.notifier).state = value;
                  await db.setReduceEffects(value);
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Dữ liệu bài học',
                    style: TextStyle(fontSize: 18)),
                subtitle: Text(
                    'Phiên bản dữ liệu: ${_dataVersion ?? '...'}. Bài học mới được tải về qua mạng, không cần cài lại app.'),
                trailing: _checkingData
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(Icons.cloud_download_outlined),
                onTap: _checkingData ? null : _checkDataUpdate,
              ),
              const Divider(),
              ListTile(
                title: const Text('Đổi PIN phụ huynh',
                    style: TextStyle(fontSize: 18)),
                subtitle: const Text('Đặt PIN 4 số mới thay cho PIN mặc định'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final newPin = await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      final c1 = TextEditingController();
                      final c2 = TextEditingController();
                      String? err;
                      return StatefulBuilder(
                        builder: (ctx, setLocal) => AlertDialog(
                          title: const Text('Đổi PIN'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: c1,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                maxLength: 4,
                                decoration: const InputDecoration(
                                  labelText: 'PIN mới (4 số)',
                                  counterText: '',
                                ),
                              ),
                              TextField(
                                controller: c2,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                maxLength: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Nhập lại PIN mới',
                                  counterText: '',
                                ),
                              ),
                              if (err != null) ...[
                                const SizedBox(height: 8),
                                Text(err!,
                                    style:
                                        const TextStyle(color: Colors.red)),
                              ],
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () {
                                final a = c1.text.trim();
                                final b = c2.text.trim();
                                if (!RegExp(r'^\d{4}$').hasMatch(a)) {
                                  setLocal(
                                      () => err = 'PIN phải gồm đúng 4 số.');
                                } else if (a != b) {
                                  setLocal(() =>
                                      err = 'Hai lần nhập chưa khớp nhau.');
                                } else {
                                  Navigator.of(ctx).pop(a);
                                }
                              },
                              child: const Text('Lưu PIN mới'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  if (newPin != null) {
                    final db = ref.read(databaseProvider);
                    await db.setPin(newPin);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Đã đổi PIN.')),
                    );
                  }
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Mở khóa tay từng đảo',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              ...islandCatalog.map((meta) {
                final p = progress[meta.id];
                final unlocked = p?.unlocked ?? meta.order == 1;
                return SwitchListTile(
                  title: Text(meta.title),
                  subtitle: Text(
                      'Sao tốt nhất: ${p?.bestStars ?? 0} / 3'),
                  value: unlocked,
                  onChanged: (value) async {
                    final db = ref.read(databaseProvider);
                    await db.setParentUnlock(meta.id, value);
                    ref.read(progressRefreshProvider.notifier).state++;
                  },
                );
              }),
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reset tiến độ?'),
                        content: const Text(
                            'Toàn bộ tiến độ, sao và nhật ký trả lời sẽ bị xóa. Đảo đầu tiên sẽ mở lại từ đầu.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Hủy'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Xóa hết'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final db = ref.read(databaseProvider);
                      await db.resetProgress();
                      ref.read(progressRefreshProvider.notifier).state++;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Đã reset tiến độ.')),
                      );
                    }
                  },
                  child: const Text('Reset tiến độ',
                      style: TextStyle(fontSize: 19)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

/// Bảng theo dõi học tập (Đợt B): hoạt động 7 ngày, hộp ôn,
/// kỹ năng yếu → mạnh, sao từng đảo.
class _LearningOverview extends ConsumerWidget {
  const _LearningOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(recentActivityProvider).maybeWhen(
          data: (a) => a,
          orElse: () => (total: 0, correct: 0),
        );
    final due = ref.watch(dueReviewCountProvider).maybeWhen(
          data: (c) => c,
          orElse: () => 0,
        );
    final skills = List<SkillStat>.of(ref.watch(skillStatsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const <SkillStat>[],
        ))
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final progress = ref.watch(islandProgressProvider).maybeWhen(
          data: (p) => p,
          orElse: () => const {},
        );
    final accuracyText = activity.total == 0
        ? 'chưa có dữ liệu'
        : '${(activity.correct * 100 / activity.total).round()}% đúng';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.seaLight, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: GameColors.seaDeep.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: GameColors.seaDeep, size: 24),
              SizedBox(width: 8),
              Text('Theo dõi học tập',
                  style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: GameColors.ink)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  icon: Icons.calendar_month_outlined,
                  value: '${activity.total} câu',
                  label: '7 ngày qua · $accuracyText',
                  color: GameColors.seaDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  icon: Icons.replay_outlined,
                  value: '$due câu',
                  label: 'đến hạn ôn lại',
                  color: GameColors.accent,
                ),
              ),
            ],
          ),
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Kỹ năng (yếu → mạnh)',
                style: TextStyle(
                    fontFamily: 'Baloo2',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GameColors.ink)),
            const SizedBox(height: 8),
            for (final s in skills)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(s.skill)),
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: s.accuracy,
                          minHeight: 10,
                          backgroundColor:
                              GameColors.seaLight.withOpacity(0.25),
                          valueColor: AlwaysStoppedAnimation(
                            s.accuracy < 0.5
                                ? GameColors.wrongSoft
                                : s.accuracy < 0.8
                                    ? GameColors.accent
                                    : GameColors.correct,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${s.correct}/${s.total}'),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          const Text('Sao từng đảo',
              style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: GameColors.ink)),
          const SizedBox(height: 8),
          for (final meta in islandCatalog)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(meta.title)),
                  for (var i = 0; i < 3; i++)
                    Icon(
                      Icons.star,
                      size: 18,
                      color: i < (progress[meta.id]?.bestStars ?? 0)
                          ? const Color(0xFFFFCA28)
                          : GameColors.mystery.withOpacity(0.35),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.45), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Baloo2',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: GameColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: GameColors.ink.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
