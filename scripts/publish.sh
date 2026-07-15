#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/publish.sh patch
  scripts/publish.sh minor
  scripts/publish.sh major
  scripts/publish.sh 1.2.3

The script updates pubspec.yaml and appVersionLabel, commits the version bump,
creates tag vX.Y.Z, then pushes main and the tag.

Pushing the tag triggers CI, which builds the APK and publishes a GitHub
*pre-release* (not marked as Latest). After verifying the APK on a real device,
promote it to the latest release manually on GitHub.
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes first." >&2
  exit 1
fi

current_line="$(grep -E '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' pubspec.yaml)"
current="${current_line#version: }"
current_name="${current%%+*}"
current_build="${current##*+}"
IFS='.' read -r major minor patch <<<"$current_name"

case "$1" in
  patch)
    patch=$((patch + 1))
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  [0-9]*.[0-9]*.[0-9]*)
    IFS='.' read -r major minor patch <<<"$1"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac

next_name="${major}.${minor}.${patch}"
next_build=$((current_build + 1))
next_version="${next_name}+${next_build}"
tag="v${next_name}"

if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Tag $tag already exists locally." >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  echo "Tag $tag already exists on origin." >&2
  exit 1
fi

python3 - "$next_version" "$tag" <<'PY'
import pathlib
import re
import sys

next_version = sys.argv[1]
tag = sys.argv[2]

pubspec = pathlib.Path("pubspec.yaml")
pubspec_text = pubspec.read_text()
pubspec.write_text(
    re.sub(r"^version: .*$", f"version: {next_version}", pubspec_text, flags=re.M)
)

main = pathlib.Path("lib/app/app_version.dart")
main_text = main.read_text()
main.write_text(
    re.sub(
        r"const String appVersionLabel = '.*?';",
        f"const String appVersionLabel = '{tag}+{next_version.split('+', 1)[1]}';",
        main_text,
    )
)
PY

# 格式化整个项目，避免 CI 的 dart format 检查（ci.yml）因遗漏格式化而变红。
# 工作区在脚本开头已强制干净，故此处 add -A 只会纳入版本号改动与格式化修正。
dart format .
flutter pub get
flutter analyze
flutter test

git add -A
git commit -m "chore: release $tag"
git tag "$tag"
git push origin main
git push origin "$tag"

echo "Pushed $tag. GitHub Actions will build the APK and publish a pre-release."
echo "Verify the APK on a real device, then promote it to Latest on GitHub."
