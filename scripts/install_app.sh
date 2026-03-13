#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_name="Performance Pulse.app"
bundle_root="$repo_root/.build/App/$app_name"
target_root="/Applications/$app_name"

cd "$repo_root"

swift scripts/generate_app_icon.swift
swift build -c release --product PerformancePulse

bin_path="$(swift build -c release --show-bin-path)/PerformancePulse"

rm -rf "$bundle_root"
mkdir -p "$bundle_root/Contents/MacOS" "$bundle_root/Contents/Resources"

cp "$repo_root/packaging/Info.plist" "$bundle_root/Contents/Info.plist"
cp "$bin_path" "$bundle_root/Contents/MacOS/PerformancePulse"
chmod +x "$bundle_root/Contents/MacOS/PerformancePulse"
cp "$repo_root/assets/AppIcon.icns" "$bundle_root/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$bundle_root"

pkill -x "PerformancePulse" || true
rm -rf "$target_root"
ditto "$bundle_root" "$target_root"

echo "Installed to $target_root"
