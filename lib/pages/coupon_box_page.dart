import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../services/database_service.dart';
import '../models/coupon.dart';
import '../config/app_colors.dart';

class CouponBoxPage extends StatefulWidget {
  final String userId;

  const CouponBoxPage({super.key, required this.userId});

  @override
  State<CouponBoxPage> createState() => _CouponBoxPageState();
}

class _CouponBoxPageState extends State<CouponBoxPage> with SingleTickerProviderStateMixin {
  final _dbService = DatabaseService();
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  
  late TabController _tabController;
  List<Coupon> _activeCoupons = [];
  List<Coupon> _usedCoupons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCoupons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    setState(() => _isLoading = true);

    final activeCoupons = await _dbService.getUserCoupons(widget.userId, status: 'ACTIVE');
    final usedCoupons = await _dbService.getUserCoupons(widget.userId, status: 'USED');

    setState(() {
      _activeCoupons = activeCoupons;
      _usedCoupons = usedCoupons;
      _isLoading = false;
    });
  }

  Future<void> _copyCouponCode(String couponCode) async {
    await Clipboard.setData(ClipboardData(text: couponCode));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('쿠폰 코드가 복사되었습니다: $couponCode'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _useCoupon(String couponId) async {
    try {
      await _dbService.useCoupon(couponId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('쿠폰이 사용 처리되었습니다'),
            backgroundColor: Colors.blue,
          ),
        );
        
        // 목록 새로고침
        await _loadCoupons();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCouponCard(Coupon coupon, bool isActive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isActive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.primary : const Color(0xFFEEEEEE),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isActive
                ? [AppColors.primarySurface, const Color(0xFFFFF8E1)]
                : [AppColors.bgSecondary, const Color(0xFFF0F0F0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 경품명과 상태
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.card_giftcard : Icons.check_circle_outline,
                        color: isActive ? AppColors.primary : AppColors.textHint,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          coupon.prizeName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.textHint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? '사용가능' : '사용완료',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 쿠폰 코드
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? AppColors.primaryLight : const Color(0xFFDDDDDD),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '쿠폰 코드',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coupon.couponCode,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier',
                            color: isActive ? Colors.black87 : Colors.grey[600],
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    ElevatedButton.icon(
                      onPressed: () => _copyCouponCode(coupon.couponCode),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('복사'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 바코드
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? AppColors.primaryLight : const Color(0xFFDDDDDD),
                ),
              ),
              child: Column(
                children: [
                  BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: coupon.couponCode,
                    width: double.infinity,
                    height: 56,
                    drawText: false,
                    color: isActive ? AppColors.textPrimary : Colors.grey,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    coupon.couponCode,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontFamily: 'Courier',
                      color: isActive ? AppColors.textSecondary : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 발급일/사용일
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '발급: ${_dateFormat.format(coupon.issuedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (!isActive && coupon.usedAt != null)
                  Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '사용: ${_dateFormat.format(coupon.usedAt!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            
            // 사용 처리 버튼 (활성 쿠폰만)
            if (isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('쿠폰 사용'),
                        content: Text('${coupon.prizeName} 쿠폰을 사용 처리하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _useCoupon(coupon.id);
                            },
                            child: const Text('사용 처리'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text('사용 처리'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCouponList(List<Coupon> coupons, bool isActive) {
    if (coupons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? Icons.card_giftcard : Icons.history,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                isActive 
                    ? '사용 가능한 쿠폰이 없습니다'
                    : '사용한 쿠폰이 없습니다',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isActive
                    ? '행운 도전에서 외부 경품에 당첨되면\n쿠폰이 자동으로 발급됩니다!'
                    : '사용한 쿠폰 내역이 여기에 표시됩니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCoupons,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coupons.length,
        itemBuilder: (context, index) {
          return _buildCouponCard(coupons[index], isActive);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          '쿠폰함',
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('사용가능'),
                  if (_activeCoupons.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_activeCoupons.length}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: '사용완료'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCouponList(_activeCoupons, true),
                _buildCouponList(_usedCoupons, false),
              ],
            ),
    );
  }
}
