// ignore: deprecated_member_use
import 'dart:html' as html;

/// 웹 브라우저용 사운드 서비스 — Web Audio API 오실레이터로 사운드 생성
/// (외부 음원 파일 없이 수학적으로 생성)
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  html.AudioContext? _ctx;

  /// 사용자 제스처(버튼 탭) 콜백에서 호출 — 브라우저 자동재생 정책 우회
  void init() {
    try {
      if (_ctx == null) {
        _ctx = html.AudioContext();
      } else {
        _ctx!.resume(); // suspended 상태일 때 재개
      }
    } catch (_) {}
  }

  /// 룰렛 회전 중 섹션 통과 시 재생 — 짧은 클릭음
  void playTick() {
    if (_ctx == null) return;
    try {
      final ctx = _ctx!;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();

      osc.connectNode(gain);
      gain.connectNode(ctx.destination!);

      osc.type = 'triangle';
      osc.frequency?.value = 660;
      gain.gain?.value = 0.12;

      final t = ctx.currentTime ?? 0;
      osc.start(t);
      osc.stop(t + 0.07);
    } catch (_) {}
  }

  /// 룰렛 정지 시 재생 — 3단계 상승 음으로 결과 도착 효과
  void playWin() {
    if (_ctx == null) return;
    try {
      final ctx = _ctx!;
      ctx.resume();

      final freqs = [440.0, 554.0, 659.0]; // A4 → C#5 → E5 (A장조 화음)
      for (var i = 0; i < freqs.length; i++) {
        final osc = ctx.createOscillator();
        final gain = ctx.createGain();

        osc.connectNode(gain);
        gain.connectNode(ctx.destination!);

        final t = (ctx.currentTime ?? 0) + i * 0.15;
        osc.type = 'sine';
        osc.frequency?.value = freqs[i];
        gain.gain?.value = 0.18;

        osc.start(t);
        osc.stop(t + 0.18);
      }
    } catch (_) {}
  }
}
