#!/bin/zsh
# Builds a local, ad-hoc-signed Finder-openable app. No global installation.
# Compiles asset catalogs using actool to produce proper Assets.car for runtime color resolution.
set -euo pipefail

# Resolve project root: script is at scripts/package-app.sh, root is two levels up
_script_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$_script_dir/.." && pwd)"
swift build -c release
bin_path=$(swift build -c release --show-bin-path)
app_path="$project_dir/dist/Orquestrador Local.app"
contents="$app_path/Contents"

# Clean any previous build artifacts in dist
rm -rf "$app_path"

mkdir -p "$contents/MacOS" "$contents/Resources"
cp "$bin_path/OrquestradorLocal" "$contents/MacOS/OrquestradorLocal"
cp -R "$bin_path/OrquestradorLocal_OrquestradorLocal.bundle" "$contents/Resources/"
cp "Sources/OrquestradorLocal/Resources/AppIcon.icns" "$contents/Resources/AppIcon.icns"
cp "Sources/OrquestradorLocal/Resources/Info.plist" "$contents/Info.plist"

# --- FIX r6: Compile asset catalog with actool ---
# The SwiftPM bundle contains raw Assets.xcassets (uncompiled .colorset directories).
# NSColor(named:) at runtime requires a compiled Assets.car, not raw .colorset.
# Compile the asset catalog and place Assets.car inside the nested SwiftPM bundle
# alongside (or replacing) the raw xcassets directory.
actool_path="/Applications/Xcode.app/Contents/Developer/usr/bin/actool"
compiled_dir="$project_dir/.build/compiled-assets"
nested_bundle="$contents/Resources/OrquestradorLocal_OrquestradorLocal.bundle"
if [[ -d "$nested_bundle/Contents/Resources" ]]; then
    nested_resources="$nested_bundle/Contents/Resources"
else
    nested_resources="$nested_bundle/Resources"
fi
mkdir -p "$nested_resources"

mkdir -p "$compiled_dir"
rm -f "$compiled_dir/Assets.car"

echo "Compiling asset catalog with actool..."
"$actool_path" --compile "$compiled_dir" \
    "Sources/OrquestradorLocal/Resources/Assets.xcassets" \
    --platform macosx \
    --minimum-deployment-target 10.15 \
    2>/dev/null || true

if [[ -f "$compiled_dir/Assets.car" ]]; then
    car_size=$(stat -f%z "$compiled_dir/Assets.car" 2>/dev/null || stat -c%s "$compiled_dir/Assets.car" 2>/dev/null)
    echo "Compiled Assets.car: $car_size bytes"
    cp "$compiled_dir/Assets.car" "$nested_resources/Assets.car"
    # Remove the raw xcassets to avoid confusion — compiled Assets.car is authoritative
    rm -rf "$nested_resources/Assets.xcassets"
    echo "Replaced raw Assets.xcassets with compiled Assets.car in bundle"
else
    echo "WARNING: actool did not produce Assets.car — colors may not resolve at runtime"
fi

# --- End FIX r6 ---

/usr/bin/codesign --force --sign - --timestamp=none "$app_path"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"
echo "Package complete: $app_path"
