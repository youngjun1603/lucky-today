import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String email;

  @HiveField(2)
  String password;

  @HiveField(3)
  String role; // 'USER' or 'ADMIN'

  @HiveField(4)
  int points;

  @HiveField(5)
  int drawSeq;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  int dailyDrawCount;

  @HiveField(8)
  DateTime? lastDrawDate;

  User({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
    this.points = 100,
    this.drawSeq = 0,
    this.dailyDrawCount = 0,
    this.lastDrawDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'password': password,
        'role': role,
        'points': points,
        'drawSeq': drawSeq,
        'dailyDrawCount': dailyDrawCount,
        'lastDrawDate': lastDrawDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        password: json['password'] as String? ?? '',
        role: json['role'] as String,
        points: json['points'] as int? ?? 100,
        drawSeq: json['drawSeq'] as int? ?? 0,
        dailyDrawCount: json['dailyDrawCount'] as int? ?? 0,
        lastDrawDate: json['lastDrawDate'] != null
            ? DateTime.parse(json['lastDrawDate'] as String)
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}
