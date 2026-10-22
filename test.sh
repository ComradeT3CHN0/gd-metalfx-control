#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$project_dir"
mkdir -p work
xcrun clang -O2 -fobjc-arc -framework Foundation -framework Metal -framework QuartzCore gd-effects-test.m gd_effects.m -o work/effects-test
xcrun clang -O2 -fobjc-arc -framework Foundation -framework Metal gd-framegen-test.m gd_framegen.m -o work/framegen-test
MTL_DEBUG_LAYER=1 work/effects-test
MTL_DEBUG_LAYER=1 work/framegen-test 2
MTL_DEBUG_LAYER=1 work/framegen-test 4
