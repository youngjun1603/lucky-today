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

## Android 설정 특이사항
- `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` 필수
  (flutter_local_notifications가 Java 8+ API 사용)
- `desugar_jdk_libs:2.1.4` 의존성 추가됨

## 키오스크 연동

### 아키텍처
키오스크 앱이 Flutter 웹을 **iframe**에 임베드하고 **postMessage**로 양방향 통신.

### URL 파라미터 (iframe src)
```
/lucky-today/?kiosk=1&uid=user@demo.com
```
- `kiosk=1`: 키오스크 모드 활성화 (AppBar 메뉴 숨김, 충전/환전 버튼 숨김, 안내 배너 표시)
- `uid`: 사용자 이메일 — `database_service.kioskLogin()`으로 비밀번호 없이 자동 로그인

### 메시지 프로토콜 (JSON 문자열)

**키오스크 → 웹 (iframe.contentWindow.postMessage)**
| type | data | 설명 |
|------|------|------|
| `KIOSK_INIT` | `{ kioskId }` | 세션 갱신 요청 |
| `KIOSK_START_FREE_DRAW` | `{}` | 광고 시청 완료 → 무료 추첨 즉시 실행 |
| `KIOSK_START_BET` | `{ betAmount: 5 }` | 포인트 배팅 실행 |
| `KIOSK_HEARTBEAT` | `{ timestamp }` | 연결 상태 확인 |

**웹 → 키오스크 (window.parent.postMessage)**
| type | data | 설명 |
|------|------|------|
| `WEB_READY` | `{ version }` | Flutter 앱 로드 완료 |
| `WEB_DRAW_COMPLETE` | `{ drawType, betAmount, winAmount, newGamePoints, prizeLabel, couponWon }` | 룰렛 결과 |
| `WEB_BALANCE_UPDATE` | `{ gamePoints, remainingFreeDraws, remainingPaidDraws }` | 잔액/횟수 동기화 |
| `WEB_ERROR` | `{ code, message }` | 오류 발생 |
| `WEB_SESSION_EXPIRED` | `{}` | 세션 만료 |

### 광고 흐름
키오스크에서 광고 재생 → 완료 후 `KIOSK_START_FREE_DRAW` 전송 → Flutter가 15초 다이얼로그 없이 룰렛 즉시 실행

### 테스트
`web/kiosk_demo.html`을 브라우저에서 열면 Flutter 앱을 iframe에 삽입하고 모든 메시지를 시각적으로 테스트 가능.
