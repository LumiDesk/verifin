param([Parameter(Mandatory)][string]$Device)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot
$package = 'top.talyra42.verifin.graphicsdiagnostic'

# Run after building/installing the diagnostic APK and its androidTest APK.
# This runner redirects preferences to a test-only file and exports neutral
# provider-rendered samples. It never reads ledger data into published assets.
$result = & adb -s $Device shell am instrument -w "$package.test/top.talyra42.verifin.FixedWidgetRenderingTest"
if ($LASTEXITCODE -ne 0 -or ($result -join "`n") -notmatch 'PASS:') {
    throw "Native widget rendering test failed: $result"
}

function Export-NativePng([string]$RemoteFile, [string]$Destination) {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = (Get-Command adb).Source
    $startInfo.Arguments = "-s $Device exec-out run-as $package cat $RemoteFile"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stream = [System.IO.File]::Create($Destination)
    try { $process.StandardOutput.BaseStream.CopyTo($stream) } finally { $stream.Dispose() }
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw $process.StandardError.ReadToEnd() }
    $process.Dispose()
    if ((Get-Item -LiteralPath $Destination).Length -lt 100) { throw 'Empty native preview export' }
}

foreach ($locale in @('zh', 'en')) {
    foreach ($dark in @('true', 'false')) {
        $localeQualifier = if ($locale -eq 'en') { '-en' } else { '' }
        $themeQualifier = if ($dark -eq 'true') { '-night' } else { '' }
        $directory = Join-Path $repoRoot "android/app/src/main/res/drawable$localeQualifier$themeQualifier-nodpi"
        New-Item -ItemType Directory -Force $directory | Out-Null
        foreach ($template in @('quick_entry', 'budget', 'net_worth', 'trend')) {
            $remoteFile = "files/widget-rendering-test/preview_${locale}_${dark}_${template}.png"
            Export-NativePng $remoteFile (Join-Path $directory "widget_preview_$template.png")
        }
    }
}
Write-Output 'Exported all widget picker assets from the actual providers.'
