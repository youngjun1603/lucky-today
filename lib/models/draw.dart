import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class Draw extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  int round;

  @HiveField(3)
  int betAmount;

  @HiveField(4)
  int feeAmount;

  @HiveField(5)
  int winAmount;

  @HiveField(6)
  double multiplier;

  @HiveField(7)
  String prizeRange;

  @HiveField(8)
  String? externalName;

  @HiveField(9)
  int? externalValue;

  @HiveField(10)
  int userNet;

  @HiveField(11)
  DateTime createdAt;

  Draw({
    required this.id,
    required this.userId,
    required this.round,
    required this.betAmount,
    required this.feeAmount,
    required this.winAmount,
    required this.multiplier,
    required this.prizeRange,
    this.externalName,
    this.externalValue,
    required this.userNet,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'round': round,
        'betAmount': betAmount,
        'feeAmount': feeAmount,
        'winAmount': winAmount,
        'multiplier': multiplier,
        'prizeRange': prizeRange,
        'externalName': externalName,
        'externalValue': externalValue,
        'userNet': userNet,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Draw.fromJson(Map<String, dynamic> json) => Draw(
        id: json['id'] as String,
        userId: json['userId'] as String,
        round: json['round'] as int,
        betAmount: json['betAmount'] as int,
        feeAmount: json['feeAmount'] as int,
        winAmount: json['winAmount'] as int,
        multiplier: (json['multiplier'] as num).toDouble(),
        prizeRange: json['prizeRange'] as String,
        externalName: json['externalName'] as String?,
        externalValue: json['externalValue'] as int?,
        userNet: json['userNet'] as int,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}
