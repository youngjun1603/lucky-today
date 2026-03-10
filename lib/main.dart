import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 데이터베이스 초기화
  final dbService = DatabaseService();
  
  try {
    await dbService.init();
    print('✅ 데이터베이스 초기화 성공');
  } catch (e) {
    print('❌ 데이터베이스 초기화 실패: $e');
  }

  runApp(const PointLotteryApp());
}

class PointLotteryApp extends StatelessWidget {
  const PointLotteryApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: const LoginPage(),
    );
  }
}
