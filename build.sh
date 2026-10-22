#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
output_dir="${OUTPUT_DIR:-$project_dir/dist}"
glmetal_dir="${GLMETAL_DIR:-$project_dir/.build/GLMetal}"
revision="$(tr -d '\n' < "$project_dir/GLMETAL_REVISION")"
for program in git python3 cmake make xcrun; do
    command -v "$program" >/dev/null || { echo "Missing build tool: $program" >&2; exit 1; }
done
if [[ ! -d "$glmetal_dir/.git" ]]; then
    mkdir -p "$(dirname "$glmetal_dir")"
    git clone https://github.com/Yash-Singh1/GLMetal.git "$glmetal_dir"
    git -C "$glmetal_dir" checkout --detach "$revision"
fi
if [[ "$(git -C "$glmetal_dir" rev-parse HEAD)" != "$revision" ]]; then
    echo "GLMetal checkout must be pinned to $revision" >&2; exit 1
fi
if git -C "$glmetal_dir" apply --check "$project_dir/glmetal-integration.patch" 2>/dev/null; then
    git -C "$glmetal_dir" apply "$project_dir/glmetal-integration.patch"
elif ! git -C "$glmetal_dir" apply --reverse --check "$project_dir/glmetal-integration.patch" 2>/dev/null; then
    echo "GLMetal checkout has incompatible changes; use a clean pinned checkout." >&2; exit 1
fi
for module in gd_effects.h gd_effects.m gd_framegen.h gd_framegen.m; do
    cp "$project_dir/$module" "$glmetal_dir/src/$module"
done
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-6}"
make -C "$glmetal_dir" -j"${BUILD_JOBS:-6}" lib inject
controller="$output_dir/GD MetalFX Control.app"
relay="$output_dir/Geometry Dash GLMetal.app"
mkdir -p "$controller/Contents/MacOS" "$controller/Contents/Resources" "$relay/Contents/MacOS"
xcrun clang -arch arm64 -arch x86_64 -O2 -fobjc-arc -framework Cocoa "$project_dir/gd-metalfx-control.m" -o "$controller/Contents/MacOS/GD MetalFX Control"
xcrun clang -arch arm64 -arch x86_64 -O2 -framework Cocoa "$project_dir/gd-metalfx-launch.m" -o "$controller/Contents/Resources/launch-game"
xcrun clang -arch arm64 -arch x86_64 -O2 -fobjc-arc -dynamiclib -framework Cocoa -Wno-deprecated-declarations "$project_dir/gd-retina-control.m" -o "$controller/Contents/Resources/libGDRetinaControl.dylib"
xcrun clang -arch arm64 -arch x86_64 -O2 -framework Cocoa "$project_dir/gd-metalfx-relay.m" -o "$relay/Contents/MacOS/launch"
for binary in libGLMetal.dylib libGLMetalInject.dylib glmetal-compiler; do
    cp "$glmetal_dir/build/$binary" "$controller/Contents/Resources/$binary"
done
python3 - "$controller" "$relay" <<'PY'
import pathlib, plistlib, sys
controller, relay = map(pathlib.Path, sys.argv[1:])
common = {'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '1.4', 'CFBundleVersion': '5', 'LSMinimumSystemVersion': '13.0'}
info = dict(common, CFBundleExecutable='GD MetalFX Control', CFBundleName='GD MetalFX Control', CFBundleIdentifier='local.geometrydash.metalfx-control', NSHighResolutionCapable=True, CFBundleURLTypes=[{'CFBundleURLName':'Launch Geometry Dash with MetalFX','CFBundleURLSchemes':['gdmetalfx']}])
(controller/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
info = dict(common, CFBundleExecutable='launch', CFBundleName='Geometry Dash GLMetal', CFBundleIdentifier='local.geometrydash.glmetal-launcher', LSUIElement=True, NSHighResolutionCapable=False)
(relay/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
PY
for app in "$controller" "$relay"; do
    codesign --force --deep --sign - "$app"
    codesign --verify --deep --strict "$app"
done
printf 'Built apps in: %s\n' "$output_dir"
printf 'To install after quitting GD and its controller: ./install.command\n'
