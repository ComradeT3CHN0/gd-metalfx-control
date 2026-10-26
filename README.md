# GD MetalFX Control- A Geometry Dash Metal renderer for macOS. Boost FPS on Apple Silicon with GLMetal, MetalFX upscaling, frame generation, and graphics controls.

Note from the dev: This can **SIGNIFICANTLY** increase your framerate if you are on mac. I went from stuttering 120 on OpenGL to intermittent 480 with Metal! Even with MetalFX enabled (basically Mac's version of NVIDIA DLSS), it can hold 120 Easy. Tested on Khorne, a high object level.

An experimental macOS graphics launcher and control panel for the **Steam version of Geometry Dash**. Built with **OpenAI Codex**, directed and tested by **ComradeT3CHN0**.

The game is required and is not included. This repository contains the controller, custom graphics extensions, tests, and a small integration patch. GLMetal is fetched from its original repository during a local build; no game assets or third-party binaries are distributed here.

## Features

- **Renderer:** Metal through GLMetal, or the original Apple OpenGL renderer.
- **Timing:** VSync on/off and a max FPS textbox (1–10000). With VSync and frame generation off at launch, press Return or leave the textbox to update the cap live. The helper paces GD's display callback independently of the monitor. On Metal it also avoids waiting for a screen drawable on every engine frame: GD continues rendering offscreen between display updates, while the screen presents at its reported refresh rate. The FPS counter reports engine frames, not extra physical display refreshes. Actual FPS depends on rendering load. VSync-on and frame-generation launches keep their existing clock. Changing VSync requires Restart.
- **Retina:** on/off, applied when the game next launches. A drawing-view helper handles GD's `EAGLView` override.
- **MetalFX Spatial Upscaling:** off, 1.5×, 2×, and experimental 10× / 20× requested output scales. Output is capped at 16,384 pixels on either side, preserving aspect ratio. Extreme modes generate an oversized intermediate image and fit it back to the window.
- **Custom frame generation:** off, 2× motion interpolation, or Extreme 4×. This is custom Metal interpolation, **not Apple's MetalFX frame interpolator**. It estimates motion between rendered frames and generates intermediate images.
- **Live glow:** bloom strength, brightness threshold, and radius.
- **Live CRT:** scanlines, screen curvature, and RGB mask.
- **Live color:** saturation, contrast, sharpening, and grayscale.
- **Separate control app:** the `Geometry Dash GLMetal` launcher opens the panel and launches the game using the saved settings.

Apple OpenGL mode disables MetalFX, custom frame generation, and the added visual effects. Their settings remain saved for switching back to GLMetal.

## Requirements

- A legally owned Steam installation of Geometry Dash at its normal macOS Steam location.
- An Apple Silicon Mac and macOS 13 or later. Tested locally on an M2 Max with macOS 27 and GD 2.209; other systems and versions have not been gameplay-tested.
- Xcode command-line build tools with a recent macOS SDK, Git, Python 3, CMake, and Make.
- Network access for the first GLMetal / shader-compiler dependency build.

The build produces universal arm64/x86_64 apps and libraries. The upstream shader helper is arm64, so this package is intended for Apple Silicon, including Rosetta processes.

## Build and install

Download this repository, open Terminal in its folder, then run:

```sh
chmod +x build.sh install.command test.sh
./install.command
```

Quit GD and any existing controller before installing. The script builds the apps, backs up existing launcher apps, installs to `~/Applications`, and opens the controller. Drag **Geometry Dash GLMetal.app** from that folder to the Dock for a shortcut.

To build without installing:

```sh
./build.sh
```

Apps appear in `dist/`. An initial dependency build can take several minutes. `BUILD_JOBS`, `CMAKE_BUILD_PARALLEL_LEVEL`, `OUTPUT_DIR`, and `GLMETAL_DIR` can override build locations / concurrency. An existing GLMetal checkout must match `GLMETAL_REVISION` and either be clean or already have the exact included integration patch applied.

GLMetal is pinned to [`25291bf50881414a5c339475842849909c853773`](https://github.com/Yash-Singh1/GLMetal/tree/25291bf50881414a5c339475842849909c853773). Its build downloads pinned glslang and SPIRV-Cross releases.

## Installation guide for AI agents

Use this checklist when a user asks you to install GD MetalFX Control or add its launcher to the Dock. These are project setup instructions; follow the user's requested scope and your environment's permission rules.

### 1. Check the Mac and dependencies

- Confirm an Apple Silicon Mac, macOS 13 or later, and the user's own Steam installation of Geometry Dash. The expected game path is `~/Library/Application Support/Steam/steamapps/common/Geometry Dash/Geometry Dash.app`. If it is missing, have the user install GD through Steam before continuing.
- Check for Xcode command-line tools (`xcrun --find clang`) and `git`, `python3`, `cmake`, and `make`. Install only missing prerequisites using the user's normal package manager or Apple's installer. The first build needs network access.
- If GD or the control panel is running, arrange a normal quit before installation. Let the user finish an active attempt or save first. The installer refuses to replace running apps.

### 2. Download, build, and install

This repository currently provides source releases. Download and extract the latest release's **Source code (zip)**, or clone the repository into a new working folder:

```sh
git clone https://github.com/ComradeT3CHN0/gd-metalfx-control.git
cd gd-metalfx-control
chmod +x build.sh install.command test.sh
./install.command
```

For an extracted ZIP, open its folder in Terminal and run the last two commands. If the destination folder already exists, inspect it and preserve local changes before updating; do not overwrite it blindly.

Wait for the command to finish successfully. The installer builds both apps, backs up existing copies, installs them to `~/Applications`, and opens **GD MetalFX Control**. Do not install the source folder or an app still inside `dist/` onto the Dock.

### 3. Verify the installed apps

Confirm both of these exist:

- `~/Applications/GD MetalFX Control.app`
- `~/Applications/Geometry Dash GLMetal.app`

Check the installed signatures:

```sh
codesign --verify --deep --strict "$HOME/Applications/GD MetalFX Control.app"
codesign --verify --deep --strict "$HOME/Applications/Geometry Dash GLMetal.app"
```

The panel should open without a launch error. If a build or verification fails, inspect the error and report the failed step before claiming installation succeeded. Do not disable macOS security protections to work around an error.

### 4. Add the correct launcher to the Dock

1. In Finder, use **Go > Go to Folder** and enter `~/Applications`.
2. Drag **Geometry Dash GLMetal.app** into the Dock's applications section, before the separator. This is the launcher that opens the control panel and starts GD using its saved settings.
3. Alternatively, open that installed launcher, then right-click its Dock icon and choose **Options > Keep in Dock** if it remains visible. The small launcher may exit immediately after handing off to the panel, so dragging it from Finder is the reliable method.
4. Check that the Dock item points to `~/Applications/Geometry Dash GLMetal.app`. If replacing an older shortcut, remove only that obsolete Dock shortcut and add the installed launcher again. Preserve the user's other Dock items and their order.

The original Steam **Geometry Dash.app** shortcut launches the original game directly. **GD MetalFX Control.app** opens just the settings panel. Pin **Geometry Dash GLMetal.app** for the combined launch behavior.

When the user is ready for a launch test, click the new Dock item once. Confirm that the panel opens and GD starts. If GD is already running, the launcher should show the panel without restarting the game. Report which checks you actually completed, and whether the Dock shortcut was verified.

## Use

1. Open **GD MetalFX Control**.
2. Choose the renderer and Retina setting in **Display**.
3. Set VSync and max FPS in **Timing**. Choose upscaling and optional interpolation in **Rendering**.
4. Click **Launch Geometry Dash**. Steam starts automatically if needed.
5. Adjust **Glow**, **CRT**, and **Color** while playing. Effects apply live to a game started through this version of the launcher.

Renderer, Retina, VSync, upscaling, and frame-generation changes require a restart. The button becomes **Restart Geometry Dash** while the game is open and closes it normally before relaunching. Clicking the Dock launcher while GD is already open only shows the panel. Max FPS updates live after Return or leaving the box when GD was launched with VSync and frame generation off. The restart notice stays visible until those settings are applied.

## What the options actually do

Upscaling increases output image dimensions. It does not create new game texture detail, add ray tracing, or multiply FPS. Effects operate on the entire frame, including menus and text.

Frame generation is paced to the main display's reported refresh rate. At 120 Hz, 2× aims for roughly 60 rendered + 60 generated frames per second; 4× aims for 30 rendered + 90 generated frames. These are targets, not measured guarantees. GD's FPS counter shows rendered frames. Interpolation can ghost, warp particles and fast objects, and add input lag. It does not improve physics or input polling, and can feel worse for precision play.

Retina increases the actual drawing-surface resolution. The tested 1280×800 game window used a 2560×1600 surface with Retina on, and 1280×800 with it off. MetalFX may upscale that surface further, so Retina plus 2× upscaling can be expensive.

## Changes to the installed game

The launcher uses the user's installed game. It does not distribute or replace the game's executable with a patched game binary.

Before applying a different Retina setting while GD is closed, it backs up the game's `Info.plist`, executable, and code signature under:

```text
~/Library/Application Support/GD MetalFX Control/Game backups/
```

It changes `NSHighResolutionCapable`, signs the local bundle with an ad-hoc signature, and verifies the signature. If applying that change fails, it attempts to restore the previous files. Steam updates or file verification may restore the display setting; a later launch reapplies the saved choice. VSync and max FPS update only the corresponding settings in `CCGameManager.dat` while GD is closed, enabling its custom FPS option. The encrypted original is backed up under `~/Library/Application Support/GD MetalFX Control/Settings backups/` before each actual change. Level data and unrelated settings are preserved. If a future game version changes the save format, the launcher refuses the update.

The launch environment includes `CURL_SSL_BACKEND=openssl`, which fixed online-feature TLS failures in the local GLMetal tests. Certificate verification is not disabled.

Settings are stored in the `local.geometrydash.metalfx-control` preferences domain. Live effects are written to:

```text
~/Library/Application Support/GD MetalFX Control/effects.json
```

Logs are available through **Show logs** and at:

```text
~/Library/Logs/Geometry Dash MetalFX/
```

## Tests

```sh
./test.sh
```

Frame-pacer tests verify callback timestamps, stop/restart, and live 60/240 FPS target changes. FPS settings tests use a synthetic encrypted fixture to check setting changes, exact preservation of unrelated data, backups, validation, and unchanged launches. Graphics tests use generated images, not game files. They check disabled-effect pixel identity, bloom spill, CRT curvature, color adjustments, grayscale, combined effects, live disable, and intermediate positions for 2× / 4× motion interpolation with Metal validation enabled. They require a working Metal GPU session.

Local integration checks also covered generated-frame presentation, effects combined with interpolation and upscaling, both renderers in GD, and Retina on/off drawing-surface sizes. This remains experimental software, not a general compatibility certification or performance benchmark.

## Restore / remove

Quit the game before removing either app. To return the display setting to stock, use Steam's **Verify integrity of game files**, which also removes the local ad-hoc signing change. This can replace other modified game files too. Launcher backups and preferences are stored separately from game saves.

## Search topics

Geometry Dash, geometrydash, macOS gaming, Apple Silicon, Metal, MetalFX, OpenGL, GLMetal, Retina, frame generation, frame interpolation, upscaling, shaders, bloom, CRT, post-processing, Objective-C, game modding, and graphics.

## Credits

**Built with OpenAI Codex**, which implemented the Cocoa controller, launcher integration, MetalFX spatial-upscaling path, custom motion interpolation, visual effects, Retina helper, and tests, with direction and hands-on feedback from **ComradeT3CHN0**.

- **[GLMetal](https://github.com/Yash-Singh1/GLMetal), by Yash Singh / Yash-Singh1:** the underlying OpenGL-to-Metal implementation. The graphics translation layer is upstream work, not original work of this controller.
- **Apple:** Metal, MetalFX, AppKit, and the macOS SDK.
- **Khronos / SPIRV-Cross contributors:** the shader tools used by GLMetal.
- **RobTop Games:** Geometry Dash. This is an unofficial project and is not affiliated with RobTop Games or Apple.

See [NOTICE.md](NOTICE.md) for dependency and distribution notes.
