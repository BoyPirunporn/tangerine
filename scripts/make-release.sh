#!/bin/zsh
# Builds a Release app and zips it for GitHub Releases.
# The app is signed ad-hoc ("Sign to Run Locally"): it is NOT notarized, so macOS asks users to
# approve it on first launch (see README). Usage: scripts/make-release.sh
set -euo pipefail
cd "${0:A:h}/.."

out=build
rm -rf "$out"

xcodebuild \
  -project Tangerine.xcodeproj -scheme Tangerine -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$out/dd" \
  CODE_SIGN_IDENTITY=- build | tail -n 3

app="$out/dd/Build/Products/Release/Tangerine.app"
[[ -d "$app" ]] || { echo "build did not produce $app" >&2; exit 1 }

version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
zip="$out/Tangerine-$version.zip"

codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

echo
echo "Built $zip"
echo "Architectures: $(lipo -archs "$app/Contents/MacOS/Tangerine")"
shasum -a 256 "$zip"
