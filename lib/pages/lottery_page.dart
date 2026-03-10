import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/user.dart';
import '../models/draw.dart';
import '../config/prize_config.dart';
import '../widgets/roulette_widget.dart';
import 'login_page.dart';
import 'point_history_page.dart';
import 'user_stats_page.dart';
import 'coupon_box_page.dart';

class LotteryPage extends StatefulWidget {
  const LotteryPage({super.key});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage> {
  final _dbService = DatabaseService();
  final _numberFormat = NumberFormat('#,###');

  User? _currentUser;
  List<Draw> _drawHistory = [];
  int? _externalBalance;
  int _remainingDraws = 5;
  int _maxDailyDraws = 5;
  int _betPoint1 = 5;
  int _betPoint2 = 10;
  List<Map<String, dynamic>> _todayTopWinners = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isLoadingExternal = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isInitializing = true);
    
    final user = await _dbService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    final history = await _dbService.getUserDrawHistory(user.id);
    final drawStatus = await _dbService.getUserDailyDrawStatus(user.id);
    final settings = await _dbService.getSystemSettings();
    final topWinners = await _dbService.getTodayTopWinners(limit: 10);

    setState(() {
      _currentUser = user;
      _drawHistory = history;
      _remainingDraws = drawStatus['remaining'] ?? 5;
      _maxDailyDraws = drawStatus['max'] ?? 5;
      _betPoint1 = settings['betPoint1'] ?? 5;
      _betPoint2 = settings['betPoint2'] ?? 10;
      _todayTopWinners = topWinners;
      _isInitializing = false;
    });

    // 외부 포인트 잔액 조회
    _loadExternalBalance();
  }

  Future<void> _loadExternalBalance() async {
    if (_currentUser == null) return;

    setState(() => _isLoadingExternal = true);

    try {
      final balance = await _dbService.getExternalPointBalance(_currentUser!.id);
      setState(() {
        _externalBalance = balance;
        _isLoadingExternal = false;
      });
    } catch (e) {
      setState(() => _isLoadingExternal = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('외부 포인트 조회 실패: $e')),
        );
      }
    }
  }

  Future<void> _conductDraw(int betAmount) async {
    if (_currentUser == null) return;

    if (_currentUser!.points < betAmount) {
      _showError('포인트가 부족합니다');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _dbService.conductDraw(_currentUser!.id, betAmount);
      final draw = Draw.fromJson(result['draw']);

      setState(() => _isLoading = false);

      // 당첨 결과의 인덱스 찾기
      int winningIndex = 0;
      for (int i = 0; i < prizeStructure.length; i++) {
        if (prizeStructure[i].range == draw.prizeRange) {
          winningIndex = i;
          break;
        }
      }

      // 룰렛 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: RouletteWidget(
                winningIndex: winningIndex,
                onSpinComplete: () {
                  Navigator.pop(context);
                  // 결과 다이얼로그 표시
                  _showDrawResult(draw);
                  // 데이터 새로고침
                  _loadData();
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('$e');
    }
  }

  void _showDrawResult(Draw draw) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('🎉 행운의 결과'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[50]!, Colors.purple[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '도전 포인트',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${_numberFormat.format(draw.betAmount)}P',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '획득 포인트',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${_numberFormat.format(draw.winAmount)}P',
                        style: TextStyle(
                          color: Colors.purple[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (draw.externalName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber[50]!, Colors.orange[50]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[700]!, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard, color: Colors.orange[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '특별 경품 당첨!',
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${draw.externalName}',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '쿠폰함에서 코드를 확인하세요',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (draw.externalName != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CouponBoxPage(userId: _currentUser!.id),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.card_giftcard),
              label: const Text('쿠폰함 보기'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber[700],
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showChargeDialog() {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('포인트 충전'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '외부 포인트: ${_externalBalance != null ? _numberFormat.format(_externalBalance!) : '---'}P',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '충전할 금액',
                suffixText: 'P',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                helperText: '외부 포인트 → 게임 포인트로 전환',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1:1 비율로 전환됩니다',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('올바른 금액을 입력하세요')),
                );
                return;
              }

              Navigator.pop(context);
              await _chargePoints(amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('충전하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _chargePoints(int amount) async {
    if (_currentUser == null) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('외부 포인트사와 통신 중...'),
          ],
        ),
      ),
    );

    try {
      await _dbService.chargePoints(_currentUser!.id, amount);
      
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        // 데이터 새로고침
        await _loadData();

        // 성공 다이얼로그
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('충전 완료'),
              ],
            ),
            content: Text(
              '${_numberFormat.format(amount)}P가 충전되었습니다!',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        _showError('충전 실패: $e');
      }
    }
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.remove_circle, color: Colors.orange),
            SizedBox(width: 8),
            Text('포인트 환전'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 포인트: ${_numberFormat.format(_currentUser?.points ?? 0)}P',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple[700],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '환전할 금액',
                suffixText: 'P',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                helperText: '게임 포인트 → 외부 포인트로 전환',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '1:1 비율로 전환됩니다',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('올바른 금액을 입력하세요')),
                );
                return;
              }

              if (amount > (_currentUser?.points ?? 0)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('포인트가 부족합니다')),
                );
                return;
              }

              Navigator.pop(context);
              await _withdrawPoints(amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('환전하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawPoints(int amount) async {
    if (_currentUser == null) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('외부 포인트사와 통신 중...'),
          ],
        ),
      ),
    );

    try {
      await _dbService.withdrawPoints(_currentUser!.id, amount);
      
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기

        // 데이터 새로고침
        await _loadData();

        // 성공 다이얼로그
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('환전 완료'),
              ],
            ),
            content: Text(
              '${_numberFormat.format(amount)}P가 외부 포인트로 전환되었습니다!',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        _showError('환전 실패: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    await _dbService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('사용자 정보를 불러올 수 없습니다')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('오늘의 행운'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CouponBoxPage(userId: _currentUser!.id),
                ),
              ).then((_) => _loadData()); // 쿠폰함에서 돌아올 때 데이터 새로고침
            },
            tooltip: '쿠폰함',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserStatsPage(userId: _currentUser!.id),
                ),
              );
            },
            tooltip: '내 통계',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PointHistoryPage(userId: _currentUser!.id),
                ),
              );
            },
            tooltip: '거래 내역',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 외부 포인트 잔액 카드
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.cyan[500]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '외부 포인트',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_isLoadingExternal)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _externalBalance != null
                                ? '${_numberFormat.format(_externalBalance!)}P'
                                : '---P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadExternalBalance,
                        tooltip: '새로고침',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 게임 포인트 카드
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple[500]!, Colors.pink[500]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '게임 포인트',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_numberFormat.format(_currentUser!.points)}P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.account_balance_wallet,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 일일 추첨 횟수 카드
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.cyan[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘의 남은 횟수',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '$_remainingDraws',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' / $_maxDailyDraws 회',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _remainingDraws > 0 
                                ? '매일 자정에 초기화됩니다'
                                : '내일 다시 도전하세요!',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _remainingDraws > 0 
                            ? Icons.check_circle 
                            : Icons.block,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 충전/환전 버튼
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showChargeDialog,
                        icon: const Icon(Icons.add_circle),
                        label: const Text('포인트 충전'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showWithdrawDialog,
                        icon: const Icon(Icons.remove_circle),
                        label: const Text('포인트 환전'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 배팅 카드
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.card_giftcard, color: Colors.purple[600]),
                            const SizedBox(width: 8),
                            const Text(
                              '행운 도전하기',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '지금 바로 당신의 행운을 확인하세요! 🍀',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (_isLoading || _remainingDraws <= 0)
                                    ? null
                                    : () => _conductDraw(_betPoint1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[500],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${_betPoint1}P',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _isLoading 
                                          ? '처리중...' 
                                          : _remainingDraws <= 0 
                                              ? '횟수초과' 
                                              : '도전하기',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (_isLoading || _remainingDraws <= 0)
                                    ? null
                                    : () => _conductDraw(_betPoint2),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple[500],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${_betPoint2}P',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _isLoading 
                                          ? '처리중...' 
                                          : _remainingDraws <= 0 
                                              ? '횟수초과' 
                                              : '도전하기',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 당일 높은 경품 당첨자 목록
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.emoji_events, color: Colors.amber[700]),
                            const SizedBox(width: 8),
                            const Text(
                              '오늘의 행운의 주인공들',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_todayTopWinners.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                '아직 첫 행운의 주인공을 기다리고 있어요!',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ..._todayTopWinners.asMap().entries.map((entry) {
                            final index = entry.key;
                            final winner = entry.value;
                            final isTopThree = index < 3;
                            
                            Color rankColor;
                            IconData rankIcon;
                            if (index == 0) {
                              rankColor = Colors.amber[700]!;
                              rankIcon = Icons.looks_one;
                            } else if (index == 1) {
                              rankColor = Colors.grey[600]!;
                              rankIcon = Icons.looks_two;
                            } else if (index == 2) {
                              rankColor = Colors.orange[700]!;
                              rankIcon = Icons.looks_3;
                            } else {
                              rankColor = Colors.blue[700]!;
                              rankIcon = Icons.star_border;
                            }
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isTopThree 
                                    ? rankColor.withOpacity(0.1)
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isTopThree 
                                      ? rankColor.withOpacity(0.3)
                                      : Colors.grey[300]!,
                                  width: isTopThree ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // 순위 아이콘
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: rankColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      rankIcon,
                                      color: rankColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 당첨자 정보
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              winner['name'] as String,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: isTopThree 
                                                    ? rankColor 
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.purple[100],
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                winner['prizeRange'] as String,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '획득: ${_numberFormat.format(winner['winAmount'])}P (${winner['multiplier']}배)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 당첨 금액 강조
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${_numberFormat.format(winner['winAmount'])}P',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isTopThree 
                                              ? rankColor 
                                              : Colors.purple[700],
                                        ),
                                      ),
                                      Text(
                                        DateFormat('HH:mm').format(
                                          winner['createdAt'] as DateTime,
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 추첨 기록 (간략 버전)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '최근 당첨 내역',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_drawHistory.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  // 전체 이력 보기 (간단히 구현)
                                },
                                child: const Text('전체보기'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_drawHistory.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                '아직 당첨 내역이 없습니다',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ..._drawHistory.take(5).map((draw) => Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                color: Colors.grey[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '#${draw.round}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            '${draw.betAmount}P 도전',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '당첨 ${_numberFormat.format(draw.winAmount)}P',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.purple[700],
                                            ),
                                          ),
                                          if (draw.externalName != null)
                                            Text(
                                              '🎁 ${draw.externalName}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
