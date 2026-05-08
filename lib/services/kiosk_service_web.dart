import 'dart:async';
import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:html' as html;

class KioskMessage {
  final String type;
  final Map<String, dynamic> data;

  KioskMessage({required this.type, required this.data});

  factory KioskMessage.fromJson(Map<String, dynamic> json) => KioskMessage(
        type: json['type'] as String? ?? '',
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? {},
      );
}

/// 키오스크 ↔ Flutter Web 양방향 메시지 브리지 (postMessage 기반)
///
/// 메시지 프로토콜:
///   키오스크 → 웹: KIOSK_INIT, KIOSK_START_FREE_DRAW, KIOSK_START_BET, KIOSK_HEARTBEAT
///   웹 → 키오스크: WEB_READY, WEB_DRAW_COMPLETE, WEB_BALANCE_UPDATE, WEB_ERROR, WEB_SESSION_EXPIRED
class KioskService {
  static final KioskService _instance = KioskService._internal();
  factory KioskService() => _instance;
  KioskService._internal();

  final _controller = StreamController<KioskMessage>.broadcast();
  bool _isKioskMode = false;
  String? _allowedOrigin;

  bool get isKioskMode => _isKioskMode;
  Stream<KioskMessage> get messages => _controller.stream;

  void initialize() {
    final uri = Uri.parse(html.window.location.href);
    _isKioskMode = uri.queryParameters['kiosk'] == '1';
    _allowedOrigin = uri.queryParameters['origin'];

    html.window.addEventListener('message', _onMessage);

    if (_isKioskMode) {
      _post({
        'type': 'WEB_READY',
        'data': {'version': '1.0.0', 'kioskMode': true},
      });
    }
  }

  void _onMessage(html.Event evt) {
    if (evt is! html.MessageEvent) return;
    final raw = evt.data;
    if (raw is! String) return;
    if (_allowedOrigin != null && evt.origin != _allowedOrigin) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String? ?? '';
      // 키오스크발 메시지만 처리 (자체 에코 방지)
      if (!type.startsWith('KIOSK_')) return;
      _controller.add(KioskMessage.fromJson(json));
    } catch (_) {}
  }

  Map<String, String> getUrlParameters() =>
      Map.unmodifiable(Uri.parse(html.window.location.href).queryParameters);

  void sendDrawComplete({
    required String drawType,
    required int betAmount,
    required int winAmount,
    required int newGamePoints,
    required String prizeLabel,
    required bool couponWon,
    String? couponCode,
  }) {
    _post({
      'type': 'WEB_DRAW_COMPLETE',
      'data': {
        'drawType': drawType,
        'betAmount': betAmount,
        'winAmount': winAmount,
        'newGamePoints': newGamePoints,
        'prizeLabel': prizeLabel,
        'couponWon': couponWon,
        if (couponCode != null) 'couponCode': couponCode,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    });
  }

  void sendBalanceUpdate({
    required int gamePoints,
    required int remainingFreeDraws,
    required int remainingPaidDraws,
    int? externalPoints,
  }) {
    _post({
      'type': 'WEB_BALANCE_UPDATE',
      'data': {
        'gamePoints': gamePoints,
        'remainingFreeDraws': remainingFreeDraws,
        'remainingPaidDraws': remainingPaidDraws,
        if (externalPoints != null) 'externalPoints': externalPoints,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    });
  }

  void sendError({required String code, required String message}) =>
      _post({'type': 'WEB_ERROR', 'data': {'code': code, 'message': message}});

  void sendSessionExpired() =>
      _post({'type': 'WEB_SESSION_EXPIRED', 'data': {}});

  void _post(Map<String, dynamic> msg) {
    final json = jsonEncode(msg);
    final target = _allowedOrigin ?? '*';
    try {
      html.window.parent?.postMessage(json, target);
    } catch (_) {}
  }
}
