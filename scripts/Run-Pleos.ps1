param(
    [string]$AvdName = 'Pleos_Connect_API_34',
    [ValidateRange(5554,5682)][int]$Port = 5580,
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk",
    [int]$BootTimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if ($Port % 2 -ne 0) { throw 'Emulator port must be even.' }
if (-not $env:JAVA_HOME -or -not (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
    $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
}
# Prefer Studio JBR over an older JAVA_HOME (AGP requires Java 17+).
if (Test-Path 'C:\Program Files\Android\Android Studio\jbr\bin\java.exe') {
    $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
}
$adb = Join-Path $SdkRoot 'platform-tools\adb.exe'
$emulator = Join-Path $SdkRoot 'emulator\emulator.exe'
foreach ($tool in @($adb, $emulator, "$env:JAVA_HOME\bin\java.exe")) {
    if (-not (Test-Path $tool)) { throw "Required tool missing: $tool" }
}
$serial = "emulator-$Port"
$devices = & $adb devices
if ($LASTEXITCODE -ne 0) { throw 'Cannot connect to adb.' }
if (-not ($devices -match "^$serial\s+device")) {
    $avds = & $emulator -list-avds
    if ($AvdName -notin $avds) { throw "AVD '$AvdName' missing. See README.md for setup." }
    $logs = Join-Path $projectRoot '.tools'
    New-Item -ItemType Directory -Force $logs | Out-Null
    Start-Process -FilePath $emulator -ArgumentList @('-avd', $AvdName, '-port', $Port,
        '-memory', '4096', '-no-snapshot', '-no-boot-anim', '-gpu', 'auto') `
        -WindowStyle Hidden -RedirectStandardOutput "$logs\emulator.stdout.log" `
        -RedirectStandardError "$logs\emulator.stderr.log" | Out-Null
} else {
    $runningName = & $adb -s $serial emu avd name
    if ($AvdName -notin $runningName) { throw "Port $Port is occupied by another AVD." }
}
$deadline = (Get-Date).AddSeconds($BootTimeoutSeconds)
do {
    $booted = & $adb -s $serial shell getprop sys.boot_completed 2>$null
    if ($booted -match '^1$') { break }
    if ((Get-Date) -gt $deadline) { throw 'Emulator boot timed out. Inspect .tools/emulator.*.log.' }
    Start-Sleep -Seconds 2
} while ($true)
Push-Location $projectRoot
try {
    & .\gradlew.bat assembleDebug --console=plain
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
    & $adb -s $serial install -r app/build/outputs/apk/debug/app-debug.apk
    if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
    $launch = & $adb -s $serial shell am start -W -n com.ssafy.pleos/.MainActivity
    $launch | Write-Output
    if ($LASTEXITCODE -ne 0 -or -not ($launch -match '^Status: ok')) {
        throw 'Activity launch failed.'
    }
} finally { Pop-Location }
