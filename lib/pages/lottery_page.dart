import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../services/sound_service.dart';
import '../services/database_service.dart';
import '../services/kiosk_service.dart';
import '../models/user.dart';
import '../models/draw.dart';
import '../config/prize_config.dart';
import '../config/app_colors.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/roulette_widget.dart';
import '../widgets/ad_reward_dialog.dart';
import '../widgets/confetti_overlay.dart';
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
  final _kioskService = KioskService();
  final _numberFormat = NumberFormat('#,###');

  User? _currentUser;
  List<Draw> _drawHistory = [];
  int _remainingDraws = 5;
  int _maxDailyDraws = 5;
  int _betPoint1 = 5;
  int _betPoint2 = 100;
  List<Map<String, dynamic>> _todayTopWinners = [];
  int _remainingFreeDraws = 3;
  int _maxFreeDraws = 3;
  bool _isLoading = false;
  bool _isInitializing = true;

  StreamSubscription<KioskMessage>? _kioskSub;

  @override
  void initState() {
    super.initState();
    _kioskSub = _kioskService.messages.listen(_handleKioskMessage);
    _loadData();
  }

  @override
  void dispose() {
    _kioskSub?.cancel();
    super.dispose();
  }

  void _handleKioskMessage(KioskMessage msg) {
    if (!mounted) return;
    switch (msg.type) {
      case 'KIOSK_START_FREE_DRAW':
        if (_remainingFreeDraws > 0 && !_isLoading) _conductFreeDraw();
        break;
      case 'KIOSK_START_BET':
        final bet = (msg.data['betAmount'] as num?)?.toInt() ?? _betPoint1;
        if (!_isLoading) _conductDraw(bet);
        break;
      case 'KIOSK_INIT':
        _loadData();
        break;
    }
  }

  void _notifyKioskDrawComplete(Draw draw, String drawType) {
    if (!_kioskService.isKioskMode) return;
    final current = _currentUser?.points ?? 0;
    final estimated = drawType == 'free'
        ? current + draw.winAmount
        : current + draw.userNet;
    _kioskService.sendDrawComplete(
      drawType: drawType,
      betAmount: draw.betAmount,
      winAmount: draw.winAmount,
      newGamePoints: estimated,
      prizeLabel: draw.prizeRange,
      couponWon: draw.externalName != null,
    );
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
    final freeDrawStatus = await _dbService.getUserDailyFreeDrawStatus(user.id);

    setState(() {
      _currentUser = user;
      _drawHistory = history;
      _remainingDraws = drawStatus['remaining'] ?? 5;
      _maxDailyDraws = drawStatus['max'] ?? 5;
      _betPoint1 = settings['betPoint1'] ?? 5;
      _betPoint2 = settings['betPoint2'] ?? 100;
      _todayTopWinners = topWinners;
      _remainingFreeDraws = freeDrawStatus['remaining'] ?? 3;
      _maxFreeDraws = freeDrawStatus['max'] ?? 3;
      _isInitializing = false;
    });

    _kioskService.sendBalanceUpdate(
      gamePoints: user.points,
      remainingFreeDraws: (freeDrawStatus['remaining'] as int?) ?? 3,
      remainingPaidDraws: (drawStatus['remaining'] as int?) ?? 5,
    );
  }

  Future<void> _conductDraw(int betAmount) async {
    SoundService().init();
    if (_currentUser == null) return;

    if (_currentUser!.points < betAmount) {
      _showError('포인트가 부족합니다');
      return;
    }

    setState(() => _isLoading = true);

    final drawType = betAmount == _betPoint1 ? 'discount' : 'gift';

    try {
      final result = await _dbService.conductDraw(_currentUser!.id, betAmount);
      final draw = Draw.fromJson(result['draw']);

      setState(() => _isLoading = false);

      int winningIndex = 0;
      for (int i = 0; i < prizeStructure.length; i++) {
        if (prizeStructure[i].range == draw.prizeRange) {
          winningIndex = i;
          break;
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(24),
              ),
              child: RouletteWidget(
                winningIndex: winningIndex,
                drawType: drawType,
                onSpinComplete: () {
                  Navigator.pop(context);
                  _notifyKioskDrawComplete(draw, 'bet');
                  _showDrawResult(draw);
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

  Future<void> _startFreeDrawWithAd() async {
    if (_currentUser == null) return;

    if (_remainingFreeDraws <= 0) {
      _showError('오늘 무료 추첨 횟수를 모두 사용했습니다. 내일 다시 도전하세요!');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('📺', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('무료 도전',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.videocam, color: AppColors.accent, size: 36),
                  SizedBox(height: 8),
                  Text(
                    '15초 광고를 시청하면\n포인트 없이 무료로 도전할 수 있어요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textPrimary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_activity,
                    size: 16, color: AppColors.secondary),
                const SizedBox(width: 6),
                Text(
                  '오늘 남은 무료 도전: $_remainingFreeDraws/$_maxFreeDraws회',
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('광고 보기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdRewardDialog(
        onComplete: () => _conductFreeDraw(),
      ),
    );
  }

  Future<void> _conductFreeDraw() async {
    SoundService().init();
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await _dbService.conductFreeDraw(_currentUser!.id);
      final draw = Draw.fromJson(result['draw']);

      setState(() => _isLoading = false);

      int winningIndex = 0;
      for (int i = 0; i < prizeStructure.length; i++) {
        if (prizeStructure[i].range == draw.prizeRange) {
          winningIndex = i;
          break;
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(24),
              ),
              child: RouletteWidget(
                winningIndex: winningIndex,
                onSpinComplete: () {
                  Navigator.pop(context);
                  _notifyKioskDrawComplete(draw, 'free');
                  _showFreeDrawResult(draw, result['freeDrawsUsed'] as int,
                      result['maxFreeDraws'] as int);
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

  void _showFreeDrawResult(Draw draw, int freeDrawsUsed, int maxFreeDraws) {
    _showConfetti();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: AppColors.accent, size: 28),
            SizedBox(width: 8),
            Text('무료 도전 결과!',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentSurface, Color(0xFFE0EAFF)],
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
                      const Text('도전 방식',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('무료 (광고 시청)',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _prizeEmoji(draw),
                          style: const TextStyle(fontSize: 42),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: _prizeSectionColor(draw),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            _prizeLabel(draw),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_activity,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '오늘 무료 도전: $freeDrawsUsed/$maxFreeDraws회 사용',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (draw.externalName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondarySurface, Color(0xFFD5F5E9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard,
                        color: AppColors.secondary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '특별 경품 당첨!',
                            style: TextStyle(
                                color: AppColors.secondaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${draw.externalName}',
                            style: const TextStyle(
                                color: AppColors.secondaryDark, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '쿠폰함에서 코드를 확인하세요',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildBarcodeSection(draw),
          ],
        ),
        actions: _kioskService.isKioskMode
            ? [
                if (draw.winAmount > 0)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _kioskService.sendRedeemDiscount(
                        drawId: draw.id,
                        round: draw.round,
                        discountAmount: draw.winAmount,
                      );
                    },
                    icon: const Icon(Icons.discount_outlined,
                        color: AppColors.secondary),
                    label: Text(
                      '할인 적용 (${_numberFormat.format(draw.winAmount)}P)',
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _kioskService.sendRedeemCoupon(
                      drawId: draw.id,
                      round: draw.round,
                      winAmount: draw.winAmount,
                      barcodeData: draw.id,
                    );
                    Future.microtask(() {
                      if (mounted) _showKioskCouponDialog(draw);
                    });
                  },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('바코드 쿠폰'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.share_outlined,
                      color: AppColors.textSecondary),
                  tooltip: '결과 공유',
                  onPressed: () => _shareDrawResult(draw, isFree: true),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CouponBoxPage(userId: _currentUser!.id),
                      ),
                    ).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.card_giftcard_outlined,
                      color: AppColors.secondary),
                  label: const Text('쿠폰함',
                      style: TextStyle(color: AppColors.secondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold)),
                ),
              ],
      ),
    );
  }

  void _showDrawResult(Draw draw) {
    _showConfetti();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: AppColors.primary, size: 28),
            SizedBox(width: 8),
            Text('행운의 결과',
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primarySurface, Color(0xFFFFF8E1)],
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
                      const Text('도전 포인트',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                      Text(
                        '${_numberFormat.format(draw.betAmount)}P',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _prizeEmoji(draw),
                          style: const TextStyle(fontSize: 42),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            color: _prizeSectionColor(draw),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            _prizeLabel(draw),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (draw.externalName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondarySurface, Color(0xFFD5F5E9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard,
                        color: AppColors.secondary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '특별 경품 당첨!',
                            style: TextStyle(
                                color: AppColors.secondaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${draw.externalName}',
                            style: const TextStyle(
                                color: AppColors.secondaryDark, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '쿠폰함에서 코드를 확인하세요',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildBarcodeSection(draw),
          ],
        ),
        actions: _kioskService.isKioskMode
            ? [
                if (draw.winAmount > 0)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _kioskService.sendRedeemDiscount(
                        drawId: draw.id,
                        round: draw.round,
                        discountAmount: draw.winAmount,
                      );
                    },
                    icon: const Icon(Icons.discount_outlined,
                        color: AppColors.secondary),
                    label: Text(
                      '할인 적용 (${_numberFormat.format(draw.winAmount)}P)',
                      style: const TextStyle(color: AppColors.secondary),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _kioskService.sendRedeemCoupon(
                      drawId: draw.id,
                      round: draw.round,
                      winAmount: draw.winAmount,
                      barcodeData: draw.id,
                    );
                    Future.microtask(() {
                      if (mounted) _showKioskCouponDialog(draw);
                    });
                  },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('바코드 쿠폰'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.share_outlined,
                      color: AppColors.textSecondary),
                  tooltip: '결과 공유',
                  onPressed: () => _shareDrawResult(draw, isFree: false),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CouponBoxPage(userId: _currentUser!.id),
                      ),
                    ).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.card_giftcard_outlined,
                      color: AppColors.secondary),
                  label: const Text('쿠폰함',
                      style: TextStyle(color: AppColors.secondary)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
      ),
    );
  }

  void _shareDrawResult(Draw draw, {required bool isFree}) {
    final prizeEmoji = draw.winAmount == 0
        ? '😅'
        : draw.winAmount >= 100
            ? '🎉'
            : '🍀';
    final freeTag = isFree ? '(광고 무료 도전)' : '';
    final externalLine = draw.externalName != null
        ? '\n🎁 특별 경품: ${draw.externalName}'
        : '';

    Share.share(
      '$prizeEmoji 오늘의 행운 #${draw.round}회 $freeTag\n'
      '${draw.prizeRange} 당첨! ${_numberFormat.format(draw.winAmount)}P 획득!\n'
      '$externalLine\n'
      '나도 오늘의 행운에 도전해보세요 🍀 #오늘의행운 #LuckyToday',
    );
  }

  void _showKioskCouponDialog(Draw draw) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, color: AppColors.accent, size: 26),
            SizedBox(width: 8),
            Text('바코드 쿠폰',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '스캐너로 바코드를 인식해 주세요',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                children: [
                  BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: draw.id,
                    width: double.infinity,
                    height: 80,
                    drawText: false,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '#${draw.round.toString().padLeft(6, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_numberFormat.format(draw.winAmount)}P 쿠폰',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeSection(Draw draw) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          BarcodeWidget(
            barcode: Barcode.code128(),
            data: draw.id,
            width: double.infinity,
            height: 56,
            drawText: false,
            color: AppColors.textPrimary,
          ),
          const SizedBox(height: 6),
          Text(
            '#${draw.round.toString().padLeft(6, '0')}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _prizeIndex(Draw draw) {
    for (int i = 0; i < prizeStructure.length; i++) {
      if (prizeStructure[i].range == draw.prizeRange) return i;
    }
    return 0;
  }

  String _prizeLabel(Draw draw) {
    final idx = _prizeIndex(draw);
    if (draw.betAmount == _betPoint1) return discountPrizeStructure[idx].displayName;
    if (draw.betAmount == _betPoint2) return giftPrizeStructure[idx].displayName;
    return prizeStructure[idx].displayName;
  }

  Color _prizeSectionColor(Draw draw) {
    final hex = prizeStructure[_prizeIndex(draw)].color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  String _prizeEmoji(Draw draw) {
    final label = _prizeLabel(draw);
    if (label == '꽝') return '😅';
    if (label == 'JACKPOT') return '🎉';
    if (draw.betAmount == _betPoint1) return '🏷️';
    if (draw.betAmount == _betPoint2) return '🎁';
    return '🍀';
  }

  void _showConfetti() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => const Positioned.fill(child: ConfettiOverlay()),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: AppColors.error),
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
        backgroundColor: AppColors.bgPage,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Center(child: Text('사용자 정보를 불러올 수 없습니다')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          '오늘의 행운',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.appBarGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _kioskService.isKioskMode
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.card_giftcard_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CouponBoxPage(userId: _currentUser!.id),
                      ),
                    ).then((_) => _loadData());
                  },
                  tooltip: '쿠폰함',
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart_outlined),
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
                  icon: const Icon(Icons.history_outlined),
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
          color: AppColors.primary,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 게임 포인트 (전체 폭)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            '게임 포인트',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_numberFormat.format(_currentUser!.points)}P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // 키오스크 모드 안내 배너
                if (_kioskService.isKioskMode) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.tablet_android,
                            color: AppColors.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '키오스크 연동 모드',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 행운 도전 카드
                Card(
                  elevation: 0,
                  color: AppColors.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(
                        color: Color(0xFFEEEEEE), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('🍀',
                                  style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '도전하기',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary),
                                ),
                                Text(
                                  _remainingDraws > 0
                                      ? '오늘 $_remainingDraws번 더 도전할 수 있어요!'
                                      : '내일 자정에 다시 도전하세요',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 1. 할인권 (5P)
                        _buildBetButton(
                          betAmount: _betPoint1,
                          label: '할인권',
                          sublabel: '${_betPoint1}P 도전',
                          color: AppColors.primary,
                          surfaceColor: AppColors.primarySurface,
                          icon: Icons.local_offer_outlined,
                        ),
                        const SizedBox(height: 10),

                        // 2. 경품당첨 (100P)
                        _buildBetButton(
                          betAmount: _betPoint2,
                          label: '경품당첨',
                          sublabel: '${_betPoint2}P 도전',
                          color: AppColors.secondary,
                          surfaceColor: AppColors.secondarySurface,
                          icon: Icons.card_giftcard_outlined,
                        ),
                        const SizedBox(height: 10),

                        // 3. 광고보기 (무료 도전)
                        _buildFreeDrawButton(),

                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.loop,
                              size: 13,
                              color: _remainingDraws > 0
                                  ? AppColors.secondary
                                  : AppColors.textHint,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '포인트 도전 남은 횟수: $_remainingDraws/$_maxDailyDraws회',
                              style: TextStyle(
                                fontSize: 12,
                                color: _remainingDraws > 0
                                    ? AppColors.secondary
                                    : AppColors.textHint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 오늘의 행운의 주인공
                Card(
                  elevation: 0,
                  color: AppColors.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(
                        color: Color(0xFFEEEEEE), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.emoji_events,
                                color: AppColors.primary),
                            SizedBox(width: 8),
                            Text(
                              '오늘의 행운의 주인공들',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_todayTopWinners.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '아직 첫 행운의 주인공을 기다리고 있어요!',
                                style: TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ..._todayTopWinners.asMap().entries.map((entry) {
                            final index = entry.key;
                            final winner = entry.value;
                            final isTopThree = index < 3;

                            final rankColors = [
                              const Color(0xFFF5A623),
                              const Color(0xFF9EA5AE),
                              const Color(0xFFCD7F32),
                            ];
                            final rankColor = isTopThree
                                ? rankColors[index]
                                : AppColors.textHint;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isTopThree
                                    ? rankColor.withOpacity(0.07)
                                    : AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isTopThree
                                      ? rankColor.withOpacity(0.25)
                                      : const Color(0xFFEEEEEE),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: rankColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isTopThree
                                            ? ['🥇', '🥈', '🥉'][index]
                                            : '${index + 1}',
                                        style: TextStyle(
                                            fontSize:
                                                isTopThree ? 16 : 12,
                                            fontWeight: FontWeight.bold,
                                            color: rankColor),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          winner['name'] as String,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isTopThree
                                                ? rankColor
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          winner['prizeRange'] as String,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${_numberFormat.format(winner['winAmount'])}P',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isTopThree
                                              ? rankColor
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('HH:mm').format(
                                            winner['createdAt'] as DateTime),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textHint),
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

                // 최근 당첨 내역
                Card(
                  elevation: 0,
                  color: AppColors.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(
                        color: Color(0xFFEEEEEE), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '최근 당첨 내역',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                            if (_drawHistory.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => UserStatsPage(
                                          userId: _currentUser!.id),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('전체보기'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_drawHistory.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '아직 당첨 내역이 없습니다',
                                style: TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ..._drawHistory.take(5).map((draw) {
                            final isFree = draw.betAmount == 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isFree
                                    ? AppColors.accentSurface
                                    : AppColors.bgSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: isFree
                                    ? Border.all(
                                        color: AppColors.accent.withOpacity(0.4),
                                        width: 1)
                                    : null,
                              ),
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
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textHint),
                                      ),
                                      Row(
                                        children: [
                                          if (isFree) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.accent,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                '무료',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            isFree
                                                ? '광고 시청 도전'
                                                : '${draw.betAmount}P 도전',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: isFree
                                                    ? AppColors.accent
                                                    : AppColors.textPrimary),
                                          ),
                                        ],
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
                                          fontSize: 15,
                                          color: isFree
                                              ? AppColors.accent
                                              : AppColors.primary,
                                        ),
                                      ),
                                      if (draw.externalName != null)
                                        Text(
                                          '🎁 ${draw.externalName}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.secondary),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreeDrawButton() {
    final bool noFreeDraws = _remainingFreeDraws <= 0;
    final bool disabled = _isLoading || noFreeDraws;

    return GestureDetector(
      onTap: disabled ? null : _startFreeDrawWithAd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF0F0F0) : AppColors.accentSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled ? AppColors.textHint : AppColors.accent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noFreeDraws ? Icons.videocam_off : Icons.videocam,
              color: disabled ? AppColors.textHint : AppColors.accent,
              size: 22,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '광고보기',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: disabled ? AppColors.textHint : AppColors.accent,
                  ),
                ),
                Text(
                  noFreeDraws
                      ? '오늘 무료 도전 횟수를 모두 사용했습니다'
                      : '무료 도전  ($_remainingFreeDraws/$_maxFreeDraws)',
                  style: TextStyle(
                    fontSize: 11,
                    color: disabled
                        ? AppColors.textHint
                        : AppColors.accent.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBetButton({
    required int betAmount,
    required String label,
    required String sublabel,
    required Color color,
    required Color surfaceColor,
    required IconData icon,
  }) {
    final bool disabled = _isLoading || _remainingDraws <= 0;
    return GestureDetector(
      onTap: disabled ? null : () => _conductDraw(betAmount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF0F0F0) : surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: disabled ? AppColors.textHint : color,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: disabled ? AppColors.textHint : color,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: disabled ? AppColors.textHint : color,
                    ),
                  ),
                  Text(
                    _isLoading
                        ? '처리중...'
                        : _remainingDraws <= 0
                            ? '오늘 횟수 초과'
                            : sublabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: disabled
                            ? AppColors.textHint
                            : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              '${_numberFormat.format(betAmount)}P',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: disabled ? AppColors.textHint : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
