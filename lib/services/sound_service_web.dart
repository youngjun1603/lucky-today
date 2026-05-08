import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
// ignore: deprecated_member_use
import 'dart:html' as html;

/// 웹 브라우저용 사운드 서비스
/// AudioContext 대신 AudioElement + 수학적으로 생성한 WAV data URI 사용
/// (Dart 3.x에서 html.AudioContext가 제거됨)
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  late final String _tickSrc = _makeWavUri(
    freq: 660,
    durationMs: 70,
    amplitude: 0.3,
    decay: 25.0,
  );
  late final String _win1Src = _makeWavUri(freq: 440, durationMs: 160, amplitude: 0.35, decay: 8.0);
  late final String _win2Src = _makeWavUri(freq: 554, durationMs: 160, amplitude: 0.35, decay: 8.0);
  late final String _win3Src = _makeWavUri(freq: 659, durationMs: 200, amplitude: 0.4,  decay: 6.0);

  /// 버튼 탭 시 호출 — AudioElement는 별도 초기화 불필요 (no-op)
  void init() {}

  /// 룰렛 섹션 통과 클릭음
  void playTick() {
    _play(_tickSrc, volume: 0.5);
  }

  /// 룰렛 정지 당첨음 — A장조 화음 (A4 → C#5 → E5) 순차 재생
  void playWin() {
    _play(_win1Src, volume: 0.55, delayMs: 0);
    _play(_win2Src, volume: 0.55, delayMs: 160);
    _play(_win3Src, volume: 0.6,  delayMs: 320);
  }

  void _play(String src, {double volume = 0.5, int delayMs = 0}) {
    if (delayMs == 0) {
      _playNow(src, volume);
    } else {
      Future.delayed(Duration(milliseconds: delayMs), () => _playNow(src, volume));
    }
  }

  void _playNow(String src, double volume) {
    try {
      final audio = html.AudioElement(src);
      audio.volume = volume;
      audio.play();
    } catch (_) {}
  }

  /// 사인파 + 지수 감쇠 엔벨로프로 WAV data URI 생성
  /// 8kHz, 8-bit, mono PCM — 파일크기 최소화
  String _makeWavUri({
    required double freq,
    required int durationMs,
    required double amplitude,
    required double decay,
  }) {
    const sampleRate = 8000;
    final numSamples = (sampleRate * durationMs / 1000).round();

    final samples = List<int>.generate(numSamples, (i) {
      final t = i / sampleRate;
      final envelope = math.exp(-t * decay);
      final wave = math.sin(2 * math.pi * freq * t);
      return (wave * envelope * amplitude * 127 + 128).round().clamp(0, 255);
    });

    final bytes = _buildWav(samples, sampleRate);
    return 'data:audio/wav;base64,${base64Encode(bytes)}';
  }

  List<int> _buildWav(List<int> samples, int sampleRate) {
    final out = Uint8List(44 + samples.length);
    final bd = ByteData.sublistView(out);

    // RIFF chunk
    out.setRange(0, 4,  [0x52, 0x49, 0x46, 0x46]); // "RIFF"
    bd.setUint32(4, 36 + samples.length, Endian.little);
    out.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]); // "WAVE"

    // fmt sub-chunk
    out.setRange(12, 16, [0x66, 0x6D, 0x74, 0x20]); // "fmt "
    bd.setUint32(16, 16, Endian.little); // sub-chunk size
    bd.setUint16(20, 1,  Endian.little); // PCM = 1
    bd.setUint16(22, 1,  Endian.little); // channels = 1 (mono)
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate, Endian.little); // byte rate (8-bit mono)
    bd.setUint16(32, 1,  Endian.little); // block align
    bd.setUint16(34, 8,  Endian.little); // bits per sample

    // data sub-chunk
    out.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]); // "data"
    bd.setUint32(40, samples.length, Endian.little);
    out.setRange(44, 44 + samples.length, samples);

    return out;
  }
}
