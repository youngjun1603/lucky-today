class Coupon {
  final String id;
  final String userId;
  final String prizeId;
  final String prizeName;
  final int prizeValue;
  final String couponCode; // 외부에서 제공한 난수 코드
  final DateTime issuedAt;
  final DateTime? usedAt;
  final bool isUsed;
  final String status; // 'ACTIVE', 'USED', 'EXPIRED'

  Coupon({
    required this.id,
    required this.userId,
    required this.prizeId,
    required this.prizeName,
    required this.prizeValue,
    required this.couponCode,
    DateTime? issuedAt,
    this.usedAt,
    this.isUsed = false,
    this.status = 'ACTIVE',
  }) : issuedAt = issuedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'prizeId': prizeId,
      'prizeName': prizeName,
      'prizeValue': prizeValue,
      'couponCode': couponCode,
      'issuedAt': issuedAt.toIso8601String(),
      'usedAt': usedAt?.toIso8601String(),
      'isUsed': isUsed,
      'status': status,
    };
  }

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as String,
      userId: json['userId'] as String,
      prizeId: json['prizeId'] as String,
      prizeName: json['prizeName'] as String,
      prizeValue: json['prizeValue'] as int,
      couponCode: json['couponCode'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      usedAt: json['usedAt'] != null 
          ? DateTime.parse(json['usedAt'] as String) 
          : null,
      isUsed: json['isUsed'] as bool? ?? false,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}
