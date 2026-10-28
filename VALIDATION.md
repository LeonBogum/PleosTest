# 구현 및 실행 검증 기록

검증 날짜: 2026-10-29 (Asia/Seoul). 에뮬레이터 내부 시계는 호스트 시계와 다를 수 있습니다.

## 시작 상태와 확인한 차이

- `C:\_SSAFY\Pleos`는 비어 있었으며 기존 소스나 테스트가 없었습니다.
- Android Studio, JBR 21, SDK 36.1 및 Emulator는 설치되어 있었지만 API 34, 시스템 이미지, AVD는 없었습니다. PATH의 기본 Java는 8이므로 빌드에는 Studio JBR을 명시합니다.
- 공유 채팅과 첨부 HTML을 확인했습니다. 첨부 문서에 없었던 실제 Pleos 이미지 URL은 공식 상세 설치 문서에서 확인했습니다.
- Vehicle SDK 의존성은 첨부 HTML의 2.3.1 대신 현재 공식 SDK 가져오기 문서의 2.3.2를 사용했습니다.

## 추가한 코드 및 연결

- `settings.gradle.kts`, 루트/앱 `build.gradle.kts`, `gradle.properties`, Gradle Wrapper: Kotlin Android 앱, API 34 / minSdk 28, 공식 Pleos Maven 저장소와 Vehicle SDK.
- `app/src/main/java/com/ssafy/pleos/MainActivity.kt`: 실제 `Vehicle.initialize()` 및 `getCurrentDoorPosition(ROW_1_LEFT)` 호출. 결과, null, 예외, 권한 거부, 10초 시간 초과 처리. 중복/늦은 콜백 배제 및 Activity 종료 시 SDK 해제.
- `AndroidManifest.xml` 및 리소스: Automotive 기능, 차량 도어 권한, 실행 Activity, 문자열, 아이콘, 백업 설정.
- `scripts/Install-PleosImage.ps1`: 명시적인 라이선스 동의 스위치, 공식 SHA1 검증, 안전한 압축 해제. 기존 이미지 덮어쓰기 거부.
- `scripts/Run-Pleos.ps1`: AVD 부팅 확인 → 실제 빌드 → APK 설치 → Activity 실행 결과 확인. 실행 중 AVD 재사용 검증.
- `scripts/Test-Pleos.ps1`: 실제 UI 버튼을 눌러 도어 값을 두 번 조회하고 앱 프로세스 로그·화면을 수집. API 오류나 응답 누락 시 실패.
- `README.md`, `.gitignore`: 실행·재설치·테스트 방법과 로컬 산출물 제외 규칙.

## 해결한 문제

1. 첫 Lint 실패: Windows SDK 경로의 콜론 이스케이프가 빠졌습니다. `local.properties`를 `C\:/...`로 수정하고 검사를 새로 실행했습니다.
2. 새 Android CLI의 sdkmanager 호환 래퍼가 기존 인자를 다르게 해석했습니다. 실제 API 34 설치는 Gradle SDK 설치 경로로 완료했습니다. avdmanager는 SDK 안의 `cmdline-tools/latest`에 설치해 사용합니다.
3. 공식 저장소의 패키지 경로(`pleos_car_emulator`)와 ZIP 내부 태그(`android-automotive`)가 달랐습니다. 최신 avdmanager가 내부 태그로 패키지 ID를 계산하므로 로컬 이미지 폴더와 AVD 경로를 `system-images/android-34/android-automotive/x86_64`로 일치시켰습니다. OS 이미지 바이트는 수정하지 않았습니다.

## 실제 실행 및 산출물

- `gradle ... wrapper --gradle-version 9.4.1`: 종료 0.
- `gradlew.bat assembleDebug lintDebug --rerun-tasks --console=plain`: 최종 소스에서 새로 검사. Lint 오류 0, 버전 안내 경고 3건(API 34 유지 및 Gradle 최신 버전 안내).
- `scripts/Install-PleosImage.ps1 -Archive .tools/pleos-image.zip -AcceptPleosLicense`: 종료 0. 공식 ZIP 4,087,751,964 bytes, SHA1 `b4f858d5bcc6c71506d7edfc872bcb9e5a11acaa`와 일치.
- `scripts/Run-Pleos.ps1`: 종료 0. 신규 부팅 및 실행 중 AVD 재사용 경로 모두 검증. 설치 `Success`, Activity `Status: ok`.
- `scripts/Test-Pleos.ps1`: 종료 0. 재설치 후 회귀 검사에서도 실제 도어 조회 1회차 `0`, 2회차 `0`. 앱 프로세스의 SDK 오류/치명적 예외 없음.
- `sys.boot_completed=1`, `init.svc.bootanim=stopped`. 최초 부팅 로그 약 45초.
- AVD: `Pleos_Connect_API_34`, 공식 `Pleos_Connect_v2_0` 프로필, RAM 4096MB, Cold boot, WHPX 가속.
- APK: `app/build/outputs/apk/debug/app-debug.apk`, 패키지 `com.ssafy.pleos`, versionName `1.0`, minSdk 28, target/compileSdk 34. aapt로 확인했습니다.
- 최종 APK 크기는 9,472,522 bytes입니다. 에뮬레이터에서 설치된 `base.apk`를 다시 가져와 빌드 APK와 SHA256 `5E55D05DCF7DC2E7A2395B96213F76DC7E90D3A3A6CD1DE94D4DABFA68809C51`가 일치함을 확인했습니다.
- 화면: `.tools/smoke/screen.png`, UI XML: `.tools/smoke/window.xml`, 실제 조회 결과: `.tools/smoke/results.txt`, 앱 로그: `.tools/smoke/logcat.txt`.
- 재현 명령과 프로젝트 공개 설정은 `README.md`에 있습니다. 최종 빌드 원문은 `.tools/final-build.log`에 저장합니다.

## 검증 범위

최종 소스의 SDK 호출이 Activity 버튼의 실제 실행 경로에 연결되어 있으며 화면에 나타난 값은 SDK 콜백으로 전달됩니다. 고정 성공값, 테스트 전용 SDK 대체물은 없습니다. 테스트 스크립트는 화면의 실제 값을 읽어 검사합니다.

앱 재시작, 반복 조회, 재설치, AVD 재사용, 빌드와 정적 검사를 수행했습니다. 도어 상태 변경에 대한 mutation 검사는 수행하지 않았습니다. 해당 이미지의 `cmd car_service help`는 production/user 빌드 제한으로 거부되었습니다. 차량 상태 변화 실험은 공식 Virtual Console을 사용하는 다음 개발 단계에 해당합니다. null·권한 거부·SDK 실패·시간 초과 처리는 소스에 구현했지만 해당 조건을 에뮬레이터에서 강제로 발생시키는 검사는 수행하지 않았습니다.
