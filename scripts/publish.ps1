#!/usr/bin/env pwsh
# Windows/PowerShell 版发布脚本，等价于 scripts/publish.sh。
# 用法：
#   ./scripts/publish.ps1 patch
#   ./scripts/publish.ps1 minor
#   ./scripts/publish.ps1 major
#   ./scripts/publish.ps1 1.2.3
#
# 脚本会更新 pubspec.yaml 与 appVersionLabel、提交版本号改动、创建标签 vX.Y.Z，
# 然后推送 main 与该标签。推送标签会触发 CI 构建 APK 并发布 GitHub *预发布*
# （不标记 Latest）。真机验收通过后，在 GitHub 手动把它提升为正式版（Latest）。

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Bump
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    Write-Host @'
Usage:
  ./scripts/publish.ps1 patch
  ./scripts/publish.ps1 minor
  ./scripts/publish.ps1 major
  ./scripts/publish.ps1 1.2.3

The script updates pubspec.yaml and appVersionLabel, commits the version bump,
creates tag vX.Y.Z, then pushes main and the tag.

Pushing the tag triggers CI, which builds the APK and publishes a GitHub
*pre-release* (not marked as Latest). After verifying the APK on a real device,
promote it to the latest release manually on GitHub.
'@
}

# 运行原生命令并在失败（非零退出码）时中止。原生命令（git/flutter 等）常把进度/
# 提示写到 stderr（如 git push 的「To github.com…」），在 $ErrorActionPreference='Stop'
# 下会被当成终止错误抛出；故在 Continue 语境里执行，只按 $LASTEXITCODE 判定成败。
function Invoke-Native {
    param([Parameter(Mandatory)][scriptblock]$Command)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0) {
        throw "Command failed with exit code ${code}: $Command"
    }
}

# 运行原生命令、丢弃全部输出、只返回退出码（用于存在性探测）。同样在 Continue 语境
# 里执行，避免 stderr 重定向在 Stop 下被包成 ErrorRecord 抛出。
function Get-NativeExitCode {
    param([Parameter(Mandatory)][scriptblock]$Command)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command *> $null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
}

# 以 UTF-8（无 BOM）写文件，保持与仓库现有文件一致的编码。
function Write-TextNoBom {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Text)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

if ([string]::IsNullOrWhiteSpace($Bump) -or $Bump -in @('-h', '--help')) {
    Show-Usage
    if ([string]::IsNullOrWhiteSpace($Bump)) { exit 1 } else { exit 0 }
}

# 仓库根目录（脚本位于 <root>/scripts/）。
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

# 工作区必须干净。
$status = git status --porcelain
if ($LASTEXITCODE -ne 0) { throw 'git status failed.' }
if (-not [string]::IsNullOrWhiteSpace($status)) {
    Write-Error 'Working tree is not clean. Commit or stash changes first.'
    exit 1
}

# 读取当前版本：version: X.Y.Z+B
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$pubspecText = Get-Content -Raw -Encoding UTF8 $pubspecPath
$versionMatch = [regex]::Match($pubspecText, '(?m)^version: (?<name>[0-9]+\.[0-9]+\.[0-9]+)\+(?<build>[0-9]+)\r?$')
if (-not $versionMatch.Success) {
    Write-Error 'Could not find a "version: X.Y.Z+B" line in pubspec.yaml.'
    exit 1
}
$parts = $versionMatch.Groups['name'].Value.Split('.')
[int]$major = $parts[0]
[int]$minor = $parts[1]
[int]$patch = $parts[2]
[int]$currentBuild = [int]$versionMatch.Groups['build'].Value

switch -Regex ($Bump) {
    '^patch$' { $patch += 1; break }
    '^minor$' { $minor += 1; $patch = 0; break }
    '^major$' { $major += 1; $minor = 0; $patch = 0; break }
    '^[0-9]+\.[0-9]+\.[0-9]+$' {
        $explicit = $Bump.Split('.')
        $major = [int]$explicit[0]
        $minor = [int]$explicit[1]
        $patch = [int]$explicit[2]
        break
    }
    default {
        Show-Usage
        exit 1
    }
}

$nextName = "$major.$minor.$patch"
$nextBuild = $currentBuild + 1
$nextVersion = "$nextName+$nextBuild"
$tag = "v$nextName"

# 标签不得已存在（本地或远端）。
if ((Get-NativeExitCode { git rev-parse --verify --quiet "refs/tags/$tag" }) -eq 0) {
    Write-Error "Tag $tag already exists locally."
    exit 1
}
if ((Get-NativeExitCode { git ls-remote --exit-code --tags origin "refs/tags/$tag" }) -eq 0) {
    Write-Error "Tag $tag already exists on origin."
    exit 1
}

# 更新 pubspec.yaml 的 version 行。
$newPubspec = [regex]::Replace($pubspecText, '(?m)^version: [^\r\n]*', "version: $nextVersion")
Write-TextNoBom -Path $pubspecPath -Text $newPubspec

# 更新 app_version.dart 的 appVersionLabel = 'vX.Y.Z+B'。
$appVersionPath = Join-Path $repoRoot 'lib/app/app_version.dart'
$appVersionText = Get-Content -Raw -Encoding UTF8 $appVersionPath
$newLabel = "$tag+$nextBuild"
$newAppVersion = [regex]::Replace(
    $appVersionText,
    "const String appVersionLabel = '.*?';",
    "const String appVersionLabel = '$newLabel';"
)
Write-TextNoBom -Path $appVersionPath -Text $newAppVersion

Write-Host "Bumping version to $nextVersion (tag $tag)..."

# 格式化整个项目、拉依赖、静态检查、测试。
# 格式化整项目避免 CI 的 dart format 检查（ci.yml）因遗漏格式化而变红。
Invoke-Native { dart format . }
Invoke-Native { flutter pub get }
Invoke-Native { flutter analyze }
Invoke-Native { flutter test }

# 提交、打标签、推送。工作区在脚本开头已强制干净，
# 故 add -A 只会纳入版本号改动与格式化修正。
Invoke-Native { git add -A }
Invoke-Native { git commit -m "chore: release $tag" }
Invoke-Native { git tag $tag }
Invoke-Native { git push origin main }
Invoke-Native { git push origin $tag }

Write-Host "Pushed $tag. GitHub Actions will build the APK and publish a pre-release."
Write-Host "Verify the APK on a real device, then promote it to Latest on GitHub."
