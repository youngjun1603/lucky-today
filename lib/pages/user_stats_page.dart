import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/draw.dart';
import '../config/prize_config.dart';

class UserStatsPage extends StatefulWidget {
  final String userId;

  const UserStatsPage({super.key, required this.userId});

  @override
  State<UserStatsPage> createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> {
  final _dbService = DatabaseService();
  final _numberFormat = NumberFormat('#,###');

  Map<String, dynamic>? _stats;
  List<Draw> _externalPrizes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);

    final stats = await _dbService.getUserStats(widget.userId);
    final externalPrizes = await _dbService.getUserExternalPrizeHistory(widget.userId);

    setState(() {
      _stats = stats;
      _externalPrizes = externalPrizes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 통계'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverallStats(),
                    const SizedBox(height: 24),
                    _buildPrizeRangeStats(),
                    const SizedBox(height: 24),
                    _buildExternalPrizeHistory(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallStats() {
    if (_stats == null) return const SizedBox();

    final totalDraws = _stats!['totalDraws'] as int;
    final totalBet = _stats!['totalBet'] as int;
    final totalWin = _stats!['totalWin'] as int;
    final totalNet = _stats!['totalNet'] as int;
    final profitRate = _stats!['profitRate'] as double;
    final externalPrizeCount = _stats!['externalPrizeCount'] as int;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.purple, size: 28),
                SizedBox(width: 8),
                Text(
                  '전체 통계',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow('총 참여 횟수', '$totalDraws회', Colors.blue),
            const SizedBox(height: 12),
            _buildStatRow(
              '총 배팅 금액',
              '${_numberFormat.format(totalBet)}P',
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              '총 당첨 금액',
              '${_numberFormat.format(totalWin)}P',
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              '순 손익',
              '${totalNet >= 0 ? '+' : ''}${_numberFormat.format(totalNet)}P',
              totalNet >= 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              '수익률',
              '${profitRate.toStringAsFixed(1)}%',
              profitRate >= 100 ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              '외부 경품 당첨',
              '$externalPrizeCount회',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeRangeStats() {
    if (_stats == null) return const SizedBox();

    final prizeRangeCount = _stats!['prizeRangeCount'] as Map<String, int>;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                SizedBox(width: 8),
                Text(
                  '등급별 당첨 현황',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...prizeStructure.map((prize) {
              final count = prizeRangeCount[prize.range] ?? 0;
              final percentage = _stats!['totalDraws'] > 0
                  ? (count / (_stats!['totalDraws'] as int) * 100)
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          prize.range,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$count회 (${percentage.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _stats!['totalDraws'] > 0
                          ? count / (_stats!['totalDraws'] as int)
                          : 0.0,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalPrizeHistory() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                const Text(
                  '외부 경품 당첨 이력',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_externalPrizes.length}회',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_externalPrizes.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.card_giftcard_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '아직 외부 경품을 당첨하지 못했습니다.\n계속 도전해보세요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._externalPrizes.map((draw) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: const Icon(
                          Icons.card_giftcard,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draw.externalName ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '가치: ${_numberFormat.format(draw.externalValue ?? 0)}원',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm')
                                  .format(draw.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
