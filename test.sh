#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$project_dir"
mkdir -p work
xcrun clang -O2 -fobjc-arc -framework Foundation -framework Metal -framework QuartzCore gd-effects-test.m gd_effects.m -o work/effects-test
xcrun clang -O2 -fobjc-arc -framework Foundation -framework Metal gd-framegen-test.m gd_framegen.m -o work/framegen-test
xcrun clang -O2 -fobjc-arc -framework Foundation gd-fps-settings-test.m -o work/fps-settings-test
work/fps-settings-test
xcrun clang -O2 -dynamiclib -framework Cocoa -framework QuartzCore -framework CoreVideo -Wno-deprecated-declarations gd-frame-pacer.m -o work/libGDFramePacer.dylib
xcrun clang -O2 -framework CoreVideo -Wno-deprecated-declarations gd-frame-pacer-test.c -o work/pacer-test
timing_dir="$(mktemp -d "$project_dir/work/timing.XXXXXX")"
trap 'rm -rf "$timing_dir"' EXIT
GD_TARGET_FPS=480 GD_TIMING_PATH="$timing_dir/timing.json" DYLD_INSERT_LIBRARIES="$project_dir/work/libGDFramePacer.dylib" work/pacer-test
MTL_DEBUG_LAYER=1 work/effects-test
MTL_DEBUG_LAYER=1 work/framegen-test 2
MTL_DEBUG_LAYER=1 work/framegen-test 4
