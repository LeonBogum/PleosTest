# Pleos Starter

Kotlin 기반 Pleos Connect 기본 앱. 실제 Vehicle SDK로 운전석 도어 위치를 조회합니다.

## 환경

- Android Studio Quail 1 / Windows x64
- Android Gradle Plugin 9.2.1, Gradle Wrapper 9.4.1, Android Studio 내장 JBR 21
- compileSdk / targetSdk 34, minSdk 28
- Vehicle SDK 2.3.2 (공식 Importing Vehicle SDK 문서 기준)
- Pleos Connect v2.1.0 API 34 x86_64, AVD `Pleos_Connect_API_34`
- AVD RAM 4096MB, Cold boot, WHPX 가속

## 실행

Android Studio에서 이 폴더 `C:\_SSAFY\Pleos`를 Open 합니다. Gradle JDK는 Android Studio 내장 `jbr`를 사용합니다. Sync 완료 후 `app`과 `Pleos_Connect_API_34`를 선택하고 Run을 누릅니다.

PowerShell에서 에뮬레이터 부팅 → 빌드 → 설치 → 앱 실행을 한 번에 수행할 수도 있습니다.

```powershell
cd C:\_SSAFY\Pleos
.\scripts\Run-Pleos.ps1
```

기본 포트는 5580입니다. 첫 부팅은 수 분 걸릴 수 있습니다. `local.properties`는 PC의 SDK 위치를 담으며 Git에 포함하지 않습니다.

## 빌드 및 정적 검사

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
.\gradlew.bat assembleDebug lintDebug --console=plain
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

Lint: `app/build/reports/lint-results-debug.html`

부팅된 Pleos AVD에서 실제 UI 버튼과 차량 API 조회를 두 번 검증하려면:

```powershell
.\scripts\Test-Pleos.ps1
```

테스트는 앱을 재시작하며 실제 화면의 버튼을 누릅니다. 실제 API 응답이 없거나 앱 오류가 있으면 실패합니다. 결과·화면 XML·PNG·앱 프로세스 로그는 `.tools/smoke/`에 저장합니다.

## 차량 API 확인

앱에서 **운전석 도어 위치 조회**를 누릅니다. 권한 요청이 나타나면 허용합니다. 조회는 `Vehicle.initialize()` → `getDoor().getCurrentDoorPosition(ROW_1_LEFT)`를 통해 실행되며 실제 반환된 정수 또는 오류를 표시합니다. `onDestroy()`에서 SDK 리소스를 해제합니다. 응답이 없으면 10초 후 재시도할 수 있습니다.

일반 Android 이미지에는 Pleos 차량 서비스가 없으므로 차량 API 테스트는 Pleos 이미지에서 진행합니다. 도어 값이 변경되는 것을 테스트하려면 공식 Virtual Console로 차량 상태를 변경한 뒤 다시 조회합니다.

## Pleos 이미지 재설치

SDK Manager → SDK Update Sites에 다음 URL을 추가합니다.

```
https://nexus-playground.pleos.ai/repository/raw-releases/connect-avd/2.x/crp-sys-img.xml
```

SDK Platforms → Show Package Details → API 34 → Pleos Connect v2.1.0 이미지를 설치합니다. 라이선스에 직접 동의해야 합니다. 이후 Device Manager에서 Automotive AVD를 만들고 RAM 4GB, Cold boot로 지정합니다.

이번 PC에서는 공식 ZIP을 검증한 뒤 `scripts/Install-PleosImage.ps1 -Archive <공식 ZIP 경로> -AcceptPleosLicense`로 설치합니다. 스크립트는 공식 SHA1을 검사하고 기존 이미지 경로를 덮어쓰지 않습니다. 공식 ZIP은 위 저장소 XML의 `archives`에 명시되어 있습니다. 압축 해제 후 약 20GB와 AVD 사용자 데이터 공간이 필요합니다.

공식 XML의 경로 이름은 `pleos_car_emulator`이지만 ZIP 내부 태그는 `android-automotive`입니다. 최신 avdmanager의 경로 불일치를 피하기 위해 로컬 설치는 `system-images/android-34/android-automotive/x86_64`를 사용합니다. OS 이미지 내용은 수정하지 않습니다.

참고:

- [Pleos 공식 빠른 시작](https://document.pleos.ai/docs/pleos-only/getting-started)
- [Pleos 에뮬레이터 설치](https://document.pleos.ai/docs/connect/guide/getting-started/application-development/setup-connect-sdk-emulator)
- [Vehicle SDK 의존성](https://document.pleos.ai/docs/pleos-only/connect-sdk-pleos/Vehicle/project-setup)

첨부 빠른 시작 HTML의 Vehicle 버전은 2.3.1이지만, 현재 SDK 의존성 문서의 2.3.2를 사용합니다.
