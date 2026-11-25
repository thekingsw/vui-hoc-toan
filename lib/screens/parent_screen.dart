import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/island_catalog.dart';
import '../providers/app_providers.dart';

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
              const Text(
                'Giai đoạn 3 sẽ có thêm: thời gian học theo ngày, tỉ lệ đúng theo chủ đề, chủ đề yếu, giới hạn giờ/ngày.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          );
        },
      ),
    );
  }
}
