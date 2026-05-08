import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/kiosk_service.dart';
import 'models/user.dart';
import 'pages/login_page.dart';
import 'pages/lottery_page.dart';
import 'pages/admin_page.dart';
import 'pages/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 데이터베이스 초기화
  final dbService = DatabaseService();
  User? currentUser;

  // 키오스크 서비스 초기화 (웹에서 postMessage 브리지 활성화)
  final kioskService = KioskService();
  kioskService.initialize();

  try {
    await dbService.init();
    print('✅ 데이터베이스 초기화 성공');
    currentUser = await dbService.getCurrentUser();

    // 키오스크 URL 파라미터로 자동 로그인 (?kiosk=1&uid=user@demo.com)
    if (currentUser == null) {
      final params = kioskService.getUrlParameters();
      if (params['kiosk'] == '1' && params['uid'] != null) {
        currentUser = await dbService.kioskLogin(params['uid']!);
        print(currentUser != null
            ? '✅ 키오스크 자동 로그인: ${currentUser!.email}'
            : '⚠️ 키오스크 자동 로그인 실패: uid=${params['uid']}');
      }
    }

    print(currentUser != null
        ? '✅ 로그인 상태 복원: ${currentUser!.email}'
        : 'ℹ️ 로그인 상태 없음 → 로그인 페이지');
  } catch (e) {
    print('❌ 데이터베이스 초기화 실패: $e');
  }

  // 알림 초기화 (Android)
  final notificationService = NotificationService();
  try {
    await notificationService.initialize();
    if (currentUser != null && currentUser.role != 'ADMIN') {
      final granted = await notificationService.requestPermissions();
      if (granted) {
        await notificationService.scheduleDailyFreeDrawReminder();
      }
    }
  } catch (_) {}

  // 온보딩 표시 여부 확인
  final prefs = await SharedPreferences.getInstance();
  final onboardingShown = prefs.getBool('onboarding_shown') ?? false;

  runApp(PointLotteryApp(
    initialUser: currentUser,
    showOnboarding: !onboardingShown,
  ));
}

class PointLotteryApp extends StatelessWidget {
  final User? initialUser;
  final bool showOnboarding;

  const PointLotteryApp({
    super.key,
    this.initialUser,
    this.showOnboarding = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (showOnboarding) {
      home = const OnboardingPage();
    } else if (initialUser == null) {
      home = const LoginPage();
    } else if (initialUser!.role == 'ADMIN') {
      home = const AdminPage();
    } else {
      home = const LotteryPage();
    }

    return MaterialApp(
      title: '오늘의 행운',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF5A623),
          primary: const Color(0xFFF5A623),
          secondary: const Color(0xFF34C98E),
          surface: const Color(0xFFFFFDF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFDF7),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFF5A623),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFFF5A623),
          selectionHandleColor: Color(0xFFF5A623),
        ),
      ),
      home: home,
    );
  }
}

