import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/mascot.dart';
import 'home_screen.dart';

/// Màn hình chờ: khởi tạo DB, nạp dữ liệu, rồi vào Home.
/// Nếu dữ liệu lỗi ở debug mode thì hiện lỗi rõ ràng.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final db = ref.read(databaseProvider);
      await db.db; // Tạo bảng + seed đảo 1.
      final soundOn = await db.isSoundOn();
      ref.read(soundOnProvider.notifier).state = soundOn;
      ref.read(soundServiceProvider).enabled = soundOn;
      ref.read(reduceEffectsProvider.notifier).state =
          await db.isReduceEffects();
      await ref.read(islandsProvider.future);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotWidget(mood: MascotMood.excited, size: 140),
              const SizedBox(height: 24),
              const Text(
                'Hành trình khám phá',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Học Toán lớp 5 mà chơi!',
                style: TextStyle(fontSize: 18, color: Colors.brown),
              ),
              const SizedBox(height: 32),
              if (_error == null)
                const CircularProgressIndicator()
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    'Không mở được app:\n$_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
