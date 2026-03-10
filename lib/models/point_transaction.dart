import 'package:hive/hive.dart';

@HiveType(typeId: 3)
class PointTransaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String type; // 'CHARGE' (충전) or 'WITHDRAW' (환전)

  @HiveField(3)
  int amount;

  @HiveField(4)
  String status; // 'PENDING', 'COMPLETED', 'FAILED'

  @HiveField(5)
  String? externalTransactionId; // 외부 포인트사 거래 ID

  @HiveField(6)
  String? memo;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  DateTime? completedAt;

  PointTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.status = 'PENDING',
    this.externalTransactionId,
    this.memo,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type,
        'amount': amount,
        'status': status,
        'externalTransactionId': externalTransactionId,
        'memo': memo,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory PointTransaction.fromJson(Map<String, dynamic> json) =>
      PointTransaction(
        id: json['id'] as String,
        userId: json['userId'] as String,
        type: json['type'] as String,
        amount: json['amount'] as int,
        status: json['status'] as String? ?? 'PENDING',
        externalTransactionId: json['externalTransactionId'] as String?,
        memo: json['memo'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );
}
