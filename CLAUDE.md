# 오늘의 행운 (Lucky Today) — 프로젝트 가이드

## 프로젝트 개요
포인트 배팅 복권 Flutter 앱. 사용자가 포인트를 배팅해 룰렛을 돌리고, 광고 시청으로 하루 3회 무료 도전 가능.

- **GitHub**: https://github.com/youngjun1603/lucky-today
- **웹 배포**: https://youngjun1603.github.io/lucky-today/
- **플랫폼**: Android (주), Web (GitHub Pages)

## 기술 스택
- Flutter 3.41.9 / Dart 3.9.2
- 상태관리: StatefulWidget + 싱글톤 패턴
- 로컬 저장소: SharedPreferences (hive 의존성 있으나 실제로는 SharedPreferences 사용)
- 암호화: SHA-256 (crypto 패키지)

## 브랜드 컬러 (`lib/config/app_colors.dart`)
- Primary: `#F5A623` (골든 앰버)
- Secondary: `#34C98E` (에메랄드)
- Accent: `#5B9CF6` (블루)
- Background: `#FFFDF7`

## 주요 파일 구조
```
lib/
├── main.dart                          # 앱 진입점, 온보딩/로그인/자동로그인 라우팅
├── config/
│   ├── app_colors.dart                # 브랜드 컬러 상수
│   └── prize_config.dart              # 경품 확률 설정
├── pages/
│   ├── onboarding_page.dart           # 첫 실행 4슬라이드 온보딩
│   ├── login_page.dart                # 로그인/회원가입
│   ├── lottery_page.dart              # 사용자 메인 (룰렛, 무료도전, 공유)
│   ├── admin_page.dart                # 관리자 대시보드
│   ├── user_stats_page.dart           # 사용자 통계
│   ├── coupon_box_page.dart           # 쿠폰함
│   ├── point_history_page.dart        # 포인트 내역
│   └── system_settings_page.dart      # 시스템 설정
├── services/
│   ├── database_service.dart          # 싱글톤 DB (SharedPreferences)
│   ├── notification_service.dart      # 조건부 export (웹/모바일 분기)
│   ├── notification_service_mobile.dart  # Android 알림 구현
│   ├── notification_service_stub.dart    # 웹용 빈 구현체
│   └── prize_service.dart             # 경품 추첨 로직
└── widgets/
    ├── roulette_widget.dart           # 룰렛 애니메이션 위젯
    └── ad_reward_dialog.dart          # 광고 보상 다이얼로그 (현재 시뮬레이션)
```

## 테스트 계정
| 역할 | 이메일 | 비밀번호 |
|---|---|---|
| 일반 사용자 | user@demo.com | user1234 |
| 관리자 | admin@demo.com | admin1234 |

## 주요 비즈니스 로직

### 무료 도전
- 하루 최대 3회 (`_maxDailyFreeDraws = 3`)
- 키: `userId_YYYY-MM-DD` 형태로 `_freeDrawCounts` Map에 저장
- `database_service.dart` → `conductFreeDraw()`, `getUserDailyFreeDrawStatus()`

### 광고 (현재 시뮬레이션)
- `lib/widgets/ad_reward_dialog.dart` — 15초 카운트다운으로 실제 광고 흉내
- 실제 광고 연결 시: **Google AdMob** (`google_mobile_ads` 패키지) 보상형 광고로 교체 예정
- AdMob 연결에 필요한 것: App ID, Rewarded Ad Unit ID

### 로그아웃
- `database_service.logout()`: `_currentUserId = null` + `_saveToStorage()` 호출
- `_saveToStorage()`에서 `_currentUserId == null`이면 반드시 `prefs.remove('currentUserId')` 실행

### 알림
- 매일 오전 9시 무료 도전 리마인더
- 웹에서는 stub으로 무시 (`dart.library.io` 조건부 import)

## CI/CD (GitHub Actions)
| 워크플로우 | 트리거 | 결과 |
|---|---|---|
| `build.yml` | main push / v* 태그 | Android APK 빌드, Artifacts 저장 |
| `web.yml` | main push | Flutter Web 빌드 → GitHub Pages 배포 |

### 릴리스 APK 배포
```bash
git tag v1.0.1
git push origin v1.0.1
# → GitHub Releases에 APK 자동 첨부
```

## Android 설정 특이사항
- `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` 필수
  (flutter_local_notifications가 Java 8+ API 사용)
- `desugar_jdk_libs:2.1.4` 의존성 추가됨

## 웹 배포 특이사항
- `--base-href /lucky-today/` 필수
- OG 이미지: CI에서 Python PIL로 `build/web/images/og-image.png` 생성
- 카카오톡 캐시 초기화: https://developers.kakao.com/tool/clear/og

## 향후 개발 예정
- [ ] Google AdMob 보상형 광고 실제 연결
- [ ] Firebase 백엔드 연동
- [ ] Google Play Store 등록
