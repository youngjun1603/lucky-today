import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/user.dart';
import '../config/app_colors.dart';

class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({super.key});

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  final _dbService = DatabaseService();
  final _numberFormat = NumberFormat('#,###');

  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    final customers = await _dbService.getCustomerStats();

    setState(() {
      _customers = customers;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          '고객 현황',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCustomers,
              child: _customers.isEmpty
                  ? const Center(
                      child: Text(
                        '등록된 고객이 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _customers.length,
                      itemBuilder: (context, index) {
                        final customer = _customers[index];
                        final user = customer['user'] as User;
                        final drawCount = customer['drawCount'] as int;
                        final totalBet = customer['totalBet'] as int;
                        final totalWin = customer['totalWin'] as int;
                        final totalNet = customer['totalNet'] as int;
                        final externalPrizeCount =
                            customer['externalPrizeCount'] as int;
                        final lastDrawDate = customer['lastDrawDate'] as DateTime?;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: user.role == 'ADMIN'
                                  ? AppColors.error
                                  : AppColors.accent,
                              child: Icon(
                                user.role == 'ADMIN'
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              user.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${user.role} · 포인트: ${_numberFormat.format(user.points)}P',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: drawCount > 0
                                    ? AppColors.secondary
                                    : AppColors.textHint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$drawCount회',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow(
                                      '참여 횟수',
                                      '$drawCount회',
                                      AppColors.accent,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      '총 배팅 금액',
                                      '${_numberFormat.format(totalBet)}P',
                                      AppColors.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      '총 당첨 금액',
                                      '${_numberFormat.format(totalWin)}P',
                                      AppColors.secondary,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      '순 손익',
                                      '${totalNet >= 0 ? '+' : ''}${_numberFormat.format(totalNet)}P',
                                      totalNet >= 0
                                          ? AppColors.secondary
                                          : AppColors.error,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      '외부 경품 당첨',
                                      '$externalPrizeCount회',
                                      AppColors.prize100p,
                                    ),
                                    if (lastDrawDate != null) ...[
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        '마지막 참여',
                                        DateFormat('yyyy-MM-dd HH:mm')
                                            .format(lastDrawDate),
                                        Colors.grey,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
