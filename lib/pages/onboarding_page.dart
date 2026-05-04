import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingData(
      emoji: '🍀',
      title: '오늘의 행운',
      subtitle: '매일 새벽, 당신의 행운이\n기다리고 있습니다',
      description: '포인트를 배팅하고 룰렛을 돌려 행운을\n잡아보세요. 100% 당첨 보장!',
      gradientColors: [Color(0xFFF5A623), Color(0xFFFFCF6B)],
    ),
    _OnboardingData(
      emoji: '💰',
      title: '포인트 충전',
      subtitle: '외부 포인트를 게임 포인트로\n간편하게 전환',
      description: '1:1 비율로 즉시 충전되며\n사용한 포인트는 언제든지 환전 가능합니다.',
      gradientColors: [Color(0xFF34C98E), Color(0xFF22A875)],
    ),
    _OnboardingData(
      emoji: '🎰',
      title: '룰렛 도전',
      subtitle: '하루 최대 5회,\n6가지 등급으로 도전',
      description: '꽝부터 잭팟까지! 배팅 금액의\n최대 20배 당첨 기회를 놓치지 마세요.',
      gradientColors: [Color(0xFF5B9CF6), Color(0xFF3D84F7)],
    ),
    _OnboardingData(
      emoji: '📺',
      title: '무료 도전',
      subtitle: '광고 시청으로 하루 3회\n포인트 없이 도전',
      description: '15초 광고만 보면 무료로 룰렛을 돌릴 수 있어요.\n포인트가 없어도 행운의 기회는 열려 있습니다!',
      gradientColors: [Color(0xFFA55EEA), Color(0xFF8B4FD8)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_shown', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            // 건너뛰기
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _complete,
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
              ),
            ),

            // 페이지 콘텐츠
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _buildPage(_pages[index]),
              ),
            ),

            // 인디케이터 + 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // 점 인디케이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? _pages[_currentPage].gradientColors[0]
                              : const Color(0xFFDDDDDD),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 다음 / 시작 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _pages[_currentPage].gradientColors[0],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? '다음'
                            : '시작하기',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이모지 원형 컨테이너
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: data.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: data.gradientColors[0].withOpacity(0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: Text(data.emoji,
                  style: const TextStyle(fontSize: 64)),
            ),
          ),
          const SizedBox(height: 48),

          // 제목
          Text(
            data.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: data.gradientColors[0],
            ),
          ),
          const SizedBox(height: 16),

          // 부제목
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // 설명
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradientColors;

  const _OnboardingData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradientColors,
  });
}
