#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
for process in 'Geometry Dash' 'GD MetalFX Control'; do
    if pgrep -x "$process" >/dev/null; then
        echo "Quit $process normally before installing." >&2; exit 1
    fi
done
"$project_dir/build.sh"
built_dir="${OUTPUT_DIR:-$project_dir/dist}"
for app in 'GD MetalFX Control.app' 'Geometry Dash GLMetal.app'; do
    [[ -d "$built_dir/$app" ]] || { echo "Missing built app: $built_dir/$app" >&2; exit 1; }
done
apps_dir="$HOME/Applications"
backup_dir="$HOME/Library/Application Support/GD MetalFX Control/Launcher backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$apps_dir" "$backup_dir"
for app in 'GD MetalFX Control.app' 'Geometry Dash GLMetal.app'; do
    if [[ -e "$apps_dir/$app" ]]; then
        mv "$apps_dir/$app" "$backup_dir/$app"
    fi
    ditto "$built_dir/$app" "$apps_dir/$app"
done
open "$apps_dir/GD MetalFX Control.app"
printf 'Installed to %s\nDrag Geometry Dash GLMetal.app to the Dock if you want a shortcut.\n' "$apps_dir"
