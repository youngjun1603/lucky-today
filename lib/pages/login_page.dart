import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'lottery_page.dart';
import 'admin_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController(text: 'user@demo.com');
  final _passwordController = TextEditingController(text: 'user1234');
  final _dbService = DatabaseService();

  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // 로그인 페이지 로드 시 데이터베이스 초기화
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    setState(() => _isInitializing = true);
    
    try {
      await _dbService.init();
      print('✅ 로그인 페이지: 데이터베이스 초기화 완료');
      
      // 초기화 완료 후 약간의 딜레이 (UI 안정화)
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      print('❌ 로그인 페이지: 데이터베이스 초기화 실패 - $e');
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('이메일과 비밀번호를 입력해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isRegisterMode) {
        // 회원가입
        print('🆕 회원가입 모드 시작');
        final user = await _dbService.register(
          _emailController.text,
          _passwordController.text,
        );

        if (user == null) {
          _showError('이미 존재하는 이메일입니다');
          setState(() => _isLoading = false);
          return;
        }

        print('✅ 회원가입 완료, 사용자 정보: ${user.email} (${user.role})');
        
        // 회원가입 성공 후 로그인 상태로 페이지 이동
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('회원가입이 완료되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // 0.5초 후 페이지 이동 (사용자에게 알림 표시)
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LotteryPage()),
            );
          }
        }
      } else {
        final user = await _dbService.login(
          _emailController.text,
          _passwordController.text,
        );

        if (user == null) {
          _showError('이메일 또는 비밀번호가 올바르지 않습니다');
          setState(() => _isLoading = false);
          return;
        }

        if (mounted) {
          if (user.role == 'ADMIN') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminPage()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LotteryPage()),
            );
          }
        }
      }
    } catch (e) {
      _showError('오류가 발생했습니다: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 데이터베이스 초기화 중이면 로딩 화면 표시
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                '데이터베이스 초기화 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '오늘의 행운',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '바로 지금, 행운을 잡으세요! ✨',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setState(() => _isRegisterMode = false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRegisterMode
                                  ? Colors.grey[200]
                                  : Colors.black,
                              foregroundColor:
                                  _isRegisterMode ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('로그인'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => setState(() => _isRegisterMode = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRegisterMode
                                  ? Colors.black
                                  : Colors.grey[200],
                              foregroundColor:
                                  _isRegisterMode ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('회원가입'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isRegisterMode ? '회원가입' : '로그인',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '데모 계정:\n'
                        'USER: user@demo.com / user1234\n'
                        'ADMIN: admin@demo.com / admin1234',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
