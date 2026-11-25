import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'widgets/update_checker.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait là chính (theo SPEC mục 10).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: ToanLop5App()));
}

class ToanLop5App extends StatelessWidget {
  const ToanLop5App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Hành trình khám phá — Toán lớp 5',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          secondary: const Color(0xFFF57C00),
        ),
        useMaterial3: true,
        // Nunito đã kèm trong assets/fonts; nếu font lỗi thì Flutter
        // tự rơi về font hệ thống, app vẫn chạy.
        fontFamily: 'Nunito',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: UpdateChecker(
        navigatorKey: navigatorKey,
        child: const SplashScreen(),
      ),
    );
  }
}
