import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'models/user.dart';
import 'pages/login_page.dart';
import 'pages/lottery_page.dart';
import 'pages/admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 데이터베이스 초기화
  final dbService = DatabaseService();
  User? currentUser;

  try {
    await dbService.init();
    print('✅ 데이터베이스 초기화 성공');
    // 새로고침(F5) 후에도 로그인 상태 복원
    currentUser = await dbService.getCurrentUser();
    print(currentUser != null
        ? '✅ 로그인 상태 복원: ${currentUser.email}'
        : 'ℹ️ 로그인 상태 없음 → 로그인 페이지');
  } catch (e) {
    print('❌ 데이터베이스 초기화 실패: $e');
  }

  runApp(PointLotteryApp(initialUser: currentUser));
}

class PointLotteryApp extends StatelessWidget {
  final User? initialUser;
  const PointLotteryApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    // 시작 페이지: 로그인 상태이면 해당 화면으로, 아니면 로그인 페이지
    Widget home;
    if (initialUser == null) {
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: home,
    );
  }
}

