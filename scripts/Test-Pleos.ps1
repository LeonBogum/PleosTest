param(
    [string]$Serial = 'emulator-5580',
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$evidence = Join-Path $projectRoot '.tools\smoke'
New-Item -ItemType Directory -Force $evidence | Out-Null
$adb = Join-Path $SdkRoot 'platform-tools\adb.exe'
function Invoke-Adb {
    param([string[]]$CommandArgs)
    $output = & $adb -s $Serial @CommandArgs
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $CommandArgs" }
    return $output
}
function Get-Screen {
    $remote = '/sdcard/pleos-smoke-' + [Guid]::NewGuid().ToString('N') + '.xml'
    Invoke-Adb @('shell', 'uiautomator', 'dump', $remote) | Out-Null
    Invoke-Adb @('pull', $remote, "$evidence\window.xml") | Out-Null
    Invoke-Adb @('shell', 'rm', $remote) | Out-Null
    return [xml](Get-Content "$evidence\window.xml" -Raw -Encoding UTF8)
}
function Click-Node($node) {
    if (-not $node -or $node.bounds -notmatch '^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$') {
        throw 'Clickable node missing or invalid bounds.'
    }
    $x = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
    $y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
    Invoke-Adb @('shell', 'input', 'tap', "$x", "$y") | Out-Null
}
Invoke-Adb @('shell', 'am', 'force-stop', 'com.ssafy.pleos') | Out-Null
$launch = Invoke-Adb @('shell', 'am', 'start', '-W', '-n', 'com.ssafy.pleos/.MainActivity')
$launch | Set-Content "$evidence\launch.txt"
if (-not ($launch -match '^Status: ok')) { throw 'Activity did not launch successfully.' }
$screen = Get-Screen
if (-not ($screen.SelectNodes('//node').text -match '앱 실행 준비 완료')) { throw 'Starter screen not visible.' }
$results = @()
foreach ($iteration in 1..2) {
    $button = $screen.SelectSingleNode('//node[@text="운전석 도어 위치 조회"]')
    if ($button.enabled -ne 'true') { throw 'Door button is disabled.' }
    Click-Node $button
    $deadline = (Get-Date).AddSeconds(30)
    do {
        $screen = Get-Screen
        $allow = $screen.SelectNodes('//node') | Where-Object {
            $_.'resource-id' -match ':id/permission_allow(_foreground_only)?_button$'
        } | Select-Object -First 1
        if ($allow) { Click-Node $allow; continue }
        $texts = @($screen.SelectNodes('//node').text)
        $result = $texts | Where-Object { $_ -match '^운전석 도어 위치: -?\d+$' } | Select-Object -First 1
        if ($result) { break }
        $failure = $texts | Where-Object { $_ -match '^Vehicle SDK 오류:|^응답 시간 초과|^차량 도어 권한이' }
        if ($failure) { throw "Real vehicle API read failed: $failure" }
        if ((Get-Date) -gt $deadline) { throw 'No vehicle API result appeared.' }
    } while ($true)
    $results += "Read ${iteration}: $result"
}
Invoke-Adb @('shell', 'screencap', '-p', '/sdcard/pleos-starter-smoke.png') | Out-Null
Invoke-Adb @('pull', '/sdcard/pleos-starter-smoke.png', "$evidence\screen.png") | Out-Null
Invoke-Adb @('shell', 'rm', '/sdcard/pleos-starter-smoke.png') | Out-Null
$appPid = (Invoke-Adb @('shell', 'pidof', 'com.ssafy.pleos')).Trim()
if (-not $appPid) { throw 'App process is no longer running.' }
$appLogs = Invoke-Adb @('logcat', '-d', "--pid=$appPid", '-s', 'PleosStarter', 'AndroidRuntime')
Set-Content "$evidence\logcat.txt" -Value ($appLogs -join "`n")
if ($appLogs -match 'FATAL EXCEPTION|Vehicle door read failed|Vehicle SDK initialization/read failed|Vehicle SDK release failed') {
    throw 'App errors were recorded; inspect smoke/logcat.txt.'
}
$results | Set-Content "$evidence\results.txt" -Encoding UTF8
$results
Write-Output "Evidence: $evidence"
