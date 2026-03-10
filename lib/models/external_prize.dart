import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class ExternalPrize extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int value;

  @HiveField(3)
  int stock;

  @HiveField(4)
  DateTime createdAt;

  ExternalPrize({
    required this.id,
    required this.name,
    required this.value,
    required this.stock,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'value': value,
        'stock': stock,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExternalPrize.fromJson(Map<String, dynamic> json) => ExternalPrize(
        id: json['id'] as String,
        name: json['name'] as String,
        value: json['value'] as int,
        stock: json['stock'] as int,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}
