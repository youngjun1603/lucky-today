# 🍀 오늘의 행운 (Lucky Today)

포인트 배팅 복권 서비스 — 매일 새로운 행운이 당신을 기다립니다!

![Flutter](https://img.shields.io/badge/Flutter-3.35.4-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9.2-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ 주요 기능

### 사용자 기능
- 🎰 **포인트 배팅 룰렛** — 6가지 당첨 구간, 유려한 애니메이션
- 📺 **무료 도전** — 하루 3회 광고 시청 후 무료 참여
- 🎫 **쿠폰함** — 외부 경품 당첨 시 16자리 코드 자동 발급
- 📊 **당첨 내역 & 통계** — 최근 기록, 누적 수익 조회
- 🔔 **일일 알림** — 매일 오전 9시 무료 도전 리마인더
- 📤 **결과 공유** — 당첨 결과를 카카오톡·SNS로 공유
- 🎬 **온보딩** — 첫 실행 시 4단계 기능 소개

### 관리자 기능
- 👥 **고객 현황** — 참여 고객 통계 및 관리
- 🎁 **외부 경품 관리** — 등록/수정/삭제
- 📈 **대시보드** — 유료 vs 무료 도전 비율, 수익 통계
- ⚙️ **시스템 설정** — 배팅 포인트, 일일 제한 횟수 조절
- 🗄️ **데이터 관리** — 데이터베이스 초기화

## 🚀 빠른 시작

### 요구사항
- Flutter SDK 3.35.4+
- Dart SDK 3.9.2+
- Android Studio / VS Code
- Java 17 (Android 빌드)

### 설치 및 실행

```bash
# 의존성 설치
flutter pub get

# Android 디버그 실행
flutter run

# Android APK 빌드 (릴리스)
flutter build apk --release

# Android App Bundle 빌드 (Play Store용)
flutter build appbundle --release
```

### 앱 아이콘 생성 (선택)

```bash
# assets/icon/app_icon.png (512×512+) 추가 후
dart run flutter_launcher_icons
```

## 🔑 테스트 계정

| 역할 | 이메일 | 비밀번호 |
|---|---|---|
| 일반 사용자 | user@demo.com | user1234 |
| 관리자 | admin@demo.com | admin1234 |

> 데모 계정은 자동 복구 시스템이 적용되어 항상 정상 작동합니다.

## 🛠️ 기술 스택

### 프레임워크
- **Flutter** 3.35.4 / **Dart** 3.9.2

### 주요 패키지
```yaml
dependencies:
  provider: ^6.1.5             # 상태 관리
  hive / hive_flutter           # 로컬 DB
  shared_preferences            # 키-값 저장
  crypto                        # SHA-256 암호화
  intl                          # 숫자/날짜 포맷
  share_plus                    # 네이티브 공유
  flutter_local_notifications   # 로컬 알림
  timezone                      # 시간대 처리
```

### 아키텍처
- **상태 관리**: StatefulWidget + 싱글톤 패턴
- **데이터 저장**: SharedPreferences (로컬 영구 저장)
- **보안**: SHA-256 비밀번호 단방향 해싱
- **애니메이션**: AnimationController + CustomPaint (룰렛)

## 📁 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점 & 라우팅
├── config/
│   ├── app_colors.dart                # 브랜드 컬러 팔레트
│   └── prize_config.dart              # 경품 확률 설정
├── models/
│   ├── user.dart
│   ├── draw.dart
│   ├── external_prize.dart
│   ├── point_transaction.dart
│   └── coupon.dart
├── pages/
│   ├── onboarding_page.dart           # 첫 실행 온보딩
│   ├── login_page.dart                # 로그인/회원가입
│   ├── lottery_page.dart              # 사용자 메인 (룰렛)
│   ├── admin_page.dart                # 관리자 대시보드
│   ├── coupon_box_page.dart           # 쿠폰함
│   ├── point_history_page.dart        # 포인트 내역
│   ├── user_stats_page.dart           # 사용자 통계
│   └── system_settings_page.dart      # 시스템 설정
├── services/
│   ├── database_service.dart          # 데이터베이스
│   ├── notification_service.dart      # 로컬 알림
│   ├── prize_service.dart             # 경품 추첨 로직
│   └── external_point_api_service.dart
└── widgets/
    ├── roulette_widget.dart           # 룰렛 위젯
    └── ad_reward_dialog.dart          # 광고 보상 다이얼로그
```

## 🎨 브랜드 컬러

| 용도 | HEX |
|---|---|
| Primary (골든 앰버) | `#F5A623` |
| Secondary (에메랄드) | `#34C98E` |
| Accent (블루) | `#5B9CF6` |
| 배경 | `#FFFDF7` |

## 🎯 경품 확률

| 등급 | 확률 | 배율 |
|---|---|---|
| 꽝 | 40% | 0배 |
| 3-5P | 30% | 0.5배 |
| 5-10P | 15% | 1배 |
| 20-50P | 10% | 4배 |
| 100P | 4% | 10배 |
| JACKPOT | 1% | 50배 |

## 🔐 보안

- **SHA-256 해싱** — 비밀번호 단방향 암호화
- **로컬 저장소** — SharedPreferences
- **싱글톤 패턴** — 데이터 일관성 보장

## 📱 지원 플랫폼

- ✅ **Android** (API 21+)
- ⚠️ iOS — 추가 설정 필요

## 📄 라이선스

MIT License

---

**버전**: 1.0.0 · **마지막 업데이트**: 2026-05-04
