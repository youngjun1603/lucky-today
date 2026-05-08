import 'dart:async';

class KioskMessage {
  final String type;
  final Map<String, dynamic> data;
  KioskMessage({required this.type, required this.data});
}

class KioskService {
  static final KioskService _instance = KioskService._internal();
  factory KioskService() => _instance;
  KioskService._internal();

  bool get isKioskMode => false;
  Stream<KioskMessage> get messages => const Stream.empty();

  void initialize() {}
  Map<String, String> getUrlParameters() => {};

  void sendDrawComplete({
    required String drawType,
    required int betAmount,
    required int winAmount,
    required int newGamePoints,
    required String prizeLabel,
    required bool couponWon,
    String? couponCode,
  }) {}

  void sendBalanceUpdate({
    required int gamePoints,
    required int remainingFreeDraws,
    required int remainingPaidDraws,
    int? externalPoints,
  }) {}

  void sendRedeemDiscount({
    required String drawId,
    required int round,
    required int discountAmount,
  }) {}

  void sendRedeemCoupon({
    required String drawId,
    required int round,
    required int winAmount,
    required String barcodeData,
  }) {}

  void sendError({required String code, required String message}) {}
  void sendSessionExpired() {}
}
