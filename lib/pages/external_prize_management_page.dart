import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/external_prize.dart';
import '../config/app_colors.dart';

class ExternalPrizeManagementPage extends StatefulWidget {
  const ExternalPrizeManagementPage({super.key});

  @override
  State<ExternalPrizeManagementPage> createState() => _ExternalPrizeManagementPageState();
}

class _ExternalPrizeManagementPageState extends State<ExternalPrizeManagementPage> {
  final _dbService = DatabaseService();
  final _numberFormat = NumberFormat('#,###');
  
  List<ExternalPrize> _prizes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrizes();
  }

  Future<void> _loadPrizes() async {
    setState(() => _isLoading = true);
    
    final prizes = await _dbService.getExternalPrizes();
    
    setState(() {
      _prizes = prizes;
      _isLoading = false;
    });
  }

  Future<void> _addPrize() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final stockController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎁 외부 경품 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '경품명',
                  hintText: '예: 스타벅스 아메리카노',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(
                  labelText: '경품 가치 (원)',
                  hintText: '예: 5000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(
                  labelText: '재고 수량',
                  hintText: '예: 10',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final valueStr = valueController.text.trim();
              final stockStr = stockController.text.trim();

              if (name.isEmpty || valueStr.isEmpty || stockStr.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 항목을 입력해주세요')),
                );
                return;
              }

              final value = int.tryParse(valueStr);
              final stock = int.tryParse(stockStr);

              if (value == null || value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('경품 가치를 올바르게 입력해주세요')),
                );
                return;
              }

              if (stock == null || stock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('재고 수량을 올바르게 입력해주세요')),
                );
                return;
              }

              Navigator.of(context).pop({
                'name': name,
                'value': value,
                'stock': stock,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _dbService.addExternalPrize(
          result['name'] as String,
          result['value'] as int,
          result['stock'] as int,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result['name']} 경품이 추가되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _loadPrizes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 경품 추가 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _editPrize(ExternalPrize prize) async {
    final nameController = TextEditingController(text: prize.name);
    final valueController = TextEditingController(text: prize.value.toString());
    final stockController = TextEditingController(text: prize.stock.toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✏️ 경품 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '경품명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(
                  labelText: '경품 가치 (원)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(
                  labelText: '재고 수량',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final valueStr = valueController.text.trim();
              final stockStr = stockController.text.trim();

              if (name.isEmpty || valueStr.isEmpty || stockStr.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 항목을 입력해주세요')),
                );
                return;
              }

              final value = int.tryParse(valueStr);
              final stock = int.tryParse(stockStr);

              if (value == null || value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('경품 가치를 올바르게 입력해주세요')),
                );
                return;
              }

              if (stock == null || stock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('재고 수량을 올바르게 입력해주세요')),
                );
                return;
              }

              Navigator.of(context).pop({
                'name': name,
                'value': value,
                'stock': stock,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('수정'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _dbService.updateExternalPrize(
          prize.id,
          result['name'] as String,
          result['value'] as int,
          result['stock'] as int,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result['name']} 경품이 수정되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _loadPrizes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 경품 수정 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePrize(ExternalPrize prize) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ 경품 삭제'),
        content: Text('${prize.name}을(를) 삭제하시겠습니까?'),
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
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteExternalPrize(prize.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${prize.name} 경품이 삭제되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }

        await _loadPrizes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 경품 삭제 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('외부 경품 관리'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrizes,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPrizes,
              child: _prizes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _addPrize,
                            icon: const Icon(Icons.add),
                            label: const Text('첫 경품 등록하기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _prizes.length,
                      itemBuilder: (context, index) {
                        final prize = _prizes[index];
                        final isLowStock = prize.stock <= 5;
                        final isOutOfStock = prize.stock == 0;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isOutOfStock
                                ? const BorderSide(color: Colors.red, width: 2)
                                : isLowStock
                                    ? const BorderSide(color: Colors.orange, width: 2)
                                    : BorderSide.none,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isOutOfStock
                                      ? [AppColors.textHint, AppColors.textSecondary]
                                      : [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.card_giftcard,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            title: Text(
                              prize.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock ? Colors.grey : Colors.black,
                                decoration: isOutOfStock
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.attach_money,
                                      size: 16,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_numberFormat.format(prize.value)}원',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.inventory_2,
                                      size: 16,
                                      color: isOutOfStock
                                          ? Colors.red
                                          : isLowStock
                                              ? Colors.orange
                                              : Colors.blue[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '재고: ${prize.stock}개',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isOutOfStock
                                            ? Colors.red
                                            : isLowStock
                                                ? Colors.orange
                                                : Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isOutOfStock) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
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
                                          horizontal: 8,
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
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _editPrize(prize),
                                  tooltip: '수정',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deletePrize(prize),
                                  tooltip: '삭제',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPrize,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('경품 추가'),
      ),
    );
  }
}
