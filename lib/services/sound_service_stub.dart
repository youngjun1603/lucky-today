import 'package:flutter/services.dart';

/// Android/iOS 네이티브용 사운드 서비스 — SystemSound + HapticFeedback
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  void init() {} // 네이티브는 별도 초기화 불필요

  void playTick() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  void playWin() {
    HapticFeedback.heavyImpact();
  }
}
