import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/external_prize.dart';
import '../models/draw.dart';
import '../config/app_colors.dart';
import 'login_page.dart';
import 'admin_customers_page.dart';
import 'external_prize_management_page.dart';
import 'system_settings_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  final _dbService = DatabaseService();
  final _numberFormat = NumberFormat('#,###');

  late TabController _tabController;
  Map<String, dynamic>? _stats;
  List<ExternalPrize> _prizes = [];
  List<Draw> _draws = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final stats = await _dbService.getStats();
    final prizes = await _dbService.getExternalPrizes();
    final draws = await _dbService.getAllDrawHistory();

    setState(() {
      _stats = stats;
      _prizes = prizes;
      _draws = draws;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _dbService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  Future<void> _resetDatabase() async {
    // 확인 다이얼로그 표시
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ 데이터베이스 초기화'),
        content: const Text(
          '모든 회원가입 정보를 삭제하고\n테스트 계정만 유지합니다.\n\n'
          '유지되는 계정:\n'
          '• admin@demo.com (관리자)\n'
          '• user@demo.com (일반 사용자)\n\n'
          '정말 초기화하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 데이터베이스 초기화
      await _dbService.resetDatabase();
      
      // 데이터 다시 로드
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 데이터베이스가 초기화되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 초기화 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          '관리자 대시보드',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '시스템 설정',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SystemSettingsPage(),
                ),
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'DB 초기화',
            onPressed: _resetDatabase,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '통계'),
            Tab(text: '고객 현황'),
            Tab(text: '경품 관리'),
            Tab(text: '추첨 이력'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(),
                const AdminCustomersPage(),
                _buildPrizesTab(),
                _buildDrawsTab(),
              ],
            ),
    );
  }

  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(child: Text('통계 데이터를 불러올 수 없습니다'));
    }

    final totalRevenue = _stats!['totalRevenue'] as int;
    final totalPayout = _stats!['totalPayout'] as int;
    final totalParticipants = _stats!['totalParticipants'] as int;
    final totalFreeDraws = _stats!['totalFreeDraws'] as int? ?? 0;
    final paidDraws = _draws.where((d) => d.betAmount > 0).length;
    final profit = totalRevenue - (totalPayout - totalRevenue);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatCard(
            '총 수익',
            '${_numberFormat.format(totalRevenue)}P',
            Icons.trending_up,
            AppColors.secondary,
          ),
          _buildStatCard(
            '총 지급액',
            '${_numberFormat.format(totalPayout)}P',
            Icons.payment,
            AppColors.accent,
          ),
          _buildStatCard(
            '순이익',
            '${_numberFormat.format(profit)}P',
            Icons.account_balance,
            AppColors.primary,
          ),
          _buildStatCard(
            '참여자 수',
            '$totalParticipants명',
            Icons.people,
            AppColors.prize100p,
          ),
          _buildFreeDrawStatCard(totalFreeDraws, paidDraws),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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

  Widget _buildPrizesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 외부 경품 관리 페이지 이동 버튼
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ExternalPrizeManagementPage(),
                  ),
                ).then((_) => _loadData()); // 돌아올 때 데이터 새로고침
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '외부 경품 관리',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '경품 추가, 수정, 삭제 및 재고 관리',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // 현재 등록된 경품 목록
          Row(
            children: [
              const Icon(Icons.list, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '등록된 외부 경품 (${_prizes.length}개)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_prizes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.card_giftcard_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '등록된 외부 경품이 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '위 버튼을 눌러 첫 경품을 등록하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._prizes.map((prize) {
              final isLowStock = prize.stock <= 5;
              final isOutOfStock = prize.stock == 0;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isOutOfStock
                      ? const BorderSide(color: Colors.red, width: 2)
                      : isLowStock
                          ? const BorderSide(color: Colors.orange, width: 1.5)
                          : BorderSide.none,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOutOfStock
                        ? const Color(0xFFF0F0F0)
                        : AppColors.primarySurface,
                    child: Icon(
                      Icons.card_giftcard,
                      color: isOutOfStock
                          ? AppColors.textHint
                          : AppColors.primaryDark,
                    ),
                  ),
                  title: Text(
                    prize.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOutOfStock ? Colors.grey : Colors.black,
                      decoration: isOutOfStock
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        '가치: ${_numberFormat.format(prize.value)}원',
                      ),
                      const Text(' · '),
                      Text(
                        '재고: ${prize.stock}개',
                        style: TextStyle(
                          color: isOutOfStock
                              ? Colors.red
                              : isLowStock
                                  ? Colors.orange
                                  : null,
                          fontWeight: isOutOfStock || isLowStock
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                      if (isOutOfStock) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '품절',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (isLowStock) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '재고부족',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDrawsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _draws.length,
        itemBuilder: (context, index) {
          final draw = _draws[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${draw.round}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (draw.betAmount == 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.accent, width: 1),
                              ),
                              child: const Text(
                                '무료',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(draw.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDrawStat(
                        '배팅',
                        draw.betAmount == 0 ? '무료' : '${draw.betAmount}P',
                        color: draw.betAmount == 0 ? AppColors.accent : null,
                      ),
                      _buildDrawStat('당첨', '${draw.winAmount}P'),
                      _buildDrawStat(
                        '손익',
                        '${draw.userNet >= 0 ? '+' : ''}${draw.userNet}P',
                        color: draw.userNet >= 0 ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  if (draw.externalName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.yellow[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🎁 ${draw.externalName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.yellow[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFreeDrawStatCard(int totalFreeDraws, int paidDraws) {
    final totalDraws = totalFreeDraws + paidDraws;
    final freeRatio = totalDraws > 0 ? totalFreeDraws / totalDraws : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam,
                      color: AppColors.accent, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '광고 무료 도전',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$totalFreeDraws',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent),
                            ),
                            TextSpan(
                              text: '  /  전체 $totalDraws회',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: freeRatio,
                minHeight: 8,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: AppColors.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('무료 도전  $totalFreeDraws회',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: Colors.grey[300], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('유료 도전  $paidDraws회',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                Text(
                  '무료 비율 ${(freeRatio * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
