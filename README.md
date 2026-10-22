# GD MetalFX Control

An experimental macOS graphics launcher and control panel for the **Steam version of Geometry Dash**. Built with **OpenAI Codex**, directed and tested by **ComradeT3CHN0**.

The game is required and is not included. This repository contains the controller, custom graphics extensions, tests, and a small integration patch. GLMetal is fetched from its original repository during a local build; no game assets or third-party binaries are distributed here.

## Features

- **Renderer:** Metal through GLMetal, or the original Apple OpenGL renderer.
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

## Use

1. Open **GD MetalFX Control**.
2. Choose the renderer and Retina setting in **Display**.
3. Choose upscaling and optional interpolation in **Rendering**.
4. Click **Launch Geometry Dash**. Steam starts automatically if needed.
5. Adjust **Glow**, **CRT**, and **Color** while playing. Effects apply live to a game started through this version of the launcher.

Renderer, Retina, upscaling, and frame-generation changes apply on the next launch. The controller does not close a running game or interrupt an attempt.

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

It changes `NSHighResolutionCapable`, signs the local bundle with an ad-hoc signature, and verifies the signature. If applying that change fails, it attempts to restore the previous files. Steam updates or file verification may restore the display setting; a later launch reapplies the saved choice. Game saves and levels are not edited by the controller.

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

Tests use generated images, not game files. They check disabled-effect pixel identity, bloom spill, CRT curvature, color adjustments, grayscale, combined effects, live disable, and intermediate positions for 2× / 4× motion interpolation with Metal validation enabled. They require a working Metal GPU session.

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
