# Research: App Icon Update

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-23

Phase 0 output. Every claim below was checked in this checkout, in the installed
Flutter SDK / pub cache, or on the attached emulator before being written down.

## Verified environment facts (grounding)

| Fact | Evidence |
|---|---|
| Flutter 3.47.5 stable, Dart SDK `^3.13.3` | `flutter --version`; `pubspec.yaml` `environment:` |
| Icon source: 1024×1024, RGB (no alpha), JPEG, **uniform near-white background** | PIL on `images/kalahoo.jpeg`: edge rows/columns mean 253–255, max channel deviation from the edge mean 2.9–4.8 |
| The art's subject occupies x 204..904, y 148..968 (68% × 80% of the canvas), slightly right/below centre | PIL: pixels >40 away from the corner colour, sampled every 4 px |
| **92.2% of the subject falls inside the adaptive safe zone** (centre 66%: 170..853) — a full-bleed adaptive foreground loses ~8% of it | same sample, restricted to the safe-zone box |
| `flutter_launcher_icons 0.14.4` resolves in this project | `flutter pub add dev:flutter_launcher_icons --dry-run` → `+ flutter_launcher_icons 0.14.4`, `+ image 4.10.1`, `+ archive 4.3.0`, `+ checked_yaml 2.0.4`, `+ cli_util 0.4.2`, `+ json_annotation 4.12.0`, `+ posix 6.5.2`; `git diff --stat pubspec.yaml pubspec.lock` empty (dry run wrote nothing) |
| Android legacy icon sizes the tool writes: mdpi 48, hdpi 72, xhdpi 96, xxhdpi 144, xxxhdpi 192 | `~/.pub-cache/hosted/pub.dev/flutter_launcher_icons-0.14.4/lib/android.dart:30-34` |
| Adaptive layers are 108 px in `drawable-*dpi`, plus `mipmap-anydpi-v26/ic_launcher.xml` | same file `:22`, `:494-497` |
| Adaptive icons need **both** keys or the run aborts: `InvalidConfigException(errorMissingImagePath)` | `lib/android.dart:101-107` |
| `adaptive_icon_foreground_inset` (default **16**) is emitted as `android:inset="N%"` on an `<inset>` drawable — an XML inset of the 108 dp foreground, not a smaller PNG | `lib/android.dart:199-201`; `README.md:107` |
| A **colour** background writes `android/app/src/main/res/values/colors.xml`, creating it if absent | `lib/android.dart:242-256`, `:288-293` |
| `min_sdk_android` is parsed but never gates generation in 0.14.4 | `lib/config/config.dart:34,150`, `lib/config/config.g.dart:33`; no other reference (`grep -rn minSdkAndroid lib/`) |
| A missing/undecodable source fails **loudly** (`FileSystemException` from `readAsBytes`, or `NoDecoderForImageFormatException`) | `lib/utils.dart:40-46` |
| `remove_alpha_ios` and `background_color_ios` exist (default background `#ffffff`) | `README.md:118,122` |
| The committed iOS icons are **RGBA** today | PIL on `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` → `RGBA` |
| The manifest names the icon by resource, not by file: `android:icon="@mipmap/ic_launcher"`, no `roundIcon` | `android/app/src/main/AndroidManifest.xml:5` |
| No icon configuration exists in Gradle | `android/app/build.gradle.kts` (only `compileSdk`/`minSdk`/`targetSdk` from `flutter.*`, no icon/asset entry) |
| The shipped Android floor is **minSdk 24**, target 36 — not API 29 | emulator-5554: `adb shell dumpsys package com.example.klhu` → `minSdk=24 targetSdk=36` |
| iOS deployment target 15.0 (constitution says iOS 16+) | `ios/Runner.xcodeproj/project.pbxproj` (recorded for spec 008, unchanged) |
| The icon source is **not** a Flutter asset (only `images/kalahu.jpeg` and `assets/content/` are declared) | `pubspec.yaml` `flutter: assets:` |
| The icon source **is** tracked in git | `git ls-files images/` → includes `images/kalahoo.jpeg` |
| The iOS icon set uses the classic multi-size layout (15 PNGs + `Contents.json`), not the single 1024 "universal" one | `ls ios/Runner/Assets.xcassets/AppIcon.appiconset/`; `Contents.json` head |
| Other platform icon sets exist and are Flutter defaults: macos (7 PNGs), web (4 PNGs), windows (`app_icon.ico`); Linux has none | `find` over `macos/ web/ windows/ linux/` |
| The generator also REWRITES the Xcode project (wrongly) and its iOS catalogue carries the legacy sizes | measured after a real run: `project.pbxproj` gets `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon` (was `YES`), and `Contents.json` has 25 entries including 50x50/57x57/72x72 iPhone+ iPad legacy sizes — see the run notes in `breakpoint.md` |
| There is no CI in this repo, so nothing regenerates icons automatically | `.github/workflows/` absent |
| `aapt2` for APK inspection is present | `~/Android/Sdk/build-tools/36.0.0/aapt2` (`android/local.properties` → `sdk.dir=/home/weihongzhang/Android/Sdk`) |

## Decisions

### D1 — Generator: `flutter_launcher_icons` as a dev dependency

**Decision**: add `flutter_launcher_icons: ^0.14.4` under `dev_dependencies` and
run it by hand (`dart run flutter_launcher_icons`); the generated files are
committed.

**Rationale**: it is the only maintained generator that covers both platforms
from one source and knows this project's density table (48/72/96/144/192,
verified above), it also emits the adaptive layers and can strip the iOS alpha
channel — all three of FR-004/FR-005 and the iOS constraint in one command. It
is dev-only, so nothing reaches the shipped app; the 7 transitive packages it
pulls (`image`, `archive`, `checked_yaml`, `cli_util`, `json_annotation`,
`posix`, …) are dev-time too.

**Alternatives considered**: (a) a hand-written PIL script — no dependency, but
it would have to reproduce the density table, the adaptive XML, the iOS asset
catalogue and its `Contents.json` by hand, i.e. re-implement a maintained tool
for ~40 files; (b) GIMP/ImageMagick manual export — no `convert`/`magick` is
installed on this host and it is not reproducible in a script; (c) committing
only a 1024 PNG and letting the platform scale it — Android/iOS do not accept a
single-size icon, and the launcher would show a blurred or letterboxed badge.

### D2 — One source for both platforms, with the iOS alpha channel removed

**Decision**: `image_path: images/kalahoo.jpeg` for Android and iOS, with
`remove_alpha_ios: true` and `background_color_ios: "#ffffff"`.

**Rationale**: the spec's FR-001/FR-003 want the same art on both platforms. The
committed iOS icons are RGBA today (fact table) and the App Store rejects an
alpha channel, so the flag is on; the JPEG has no alpha to begin with, so the
"removal" only flattens the generated canvas onto the measured white background.

**Alternatives considered**: a separate iOS-only source (unnecessary — the white
background measures uniform, so the same file reads correctly through a rounded
iOS mask); leaving the alpha channel (fails App Store validation later, at a
point where it is much more expensive to find).

### D3 — Adaptive icon from the same image, inset by the tool's default

**Decision**: configure `adaptive_icon_background: "#ffffff"` and
`adaptive_icon_foreground: images/kalahoo.jpeg`, leaving
`adaptive_icon_foreground_inset` at its default 16 %, and **do not** pre-crop or
pre-pad the source.

**Rationale**: with the 16 % XML inset the foreground is drawn at 108 × (1 − 2 ×
0.16) = 73.4 dp, which is just inside the 72 dp guaranteed-safe disc, so the
whole art — including the subject's bottom edge at y = 968 — stays visible inside
any launcher mask, and the white margin of the art merges with the `#ffffff`
background layer, so no alpha keying is needed. The measurement above says a
*non*-inset full-bleed foreground would clip ~8 % of the subject on API 26+.

**Alternatives considered**: (a) no adaptive icon at all — Android 8+ launchers
then draw the legacy bitmap shrunk inside their own mask on a white shim, which
is the visibly worse look this decision avoids; (b) an alpha-keyed foreground
(transparent background) — possible given the uniform white background, but it
buys nothing here because the background layer is the same white and the inset
already protects the safe zone; (c) cropping to the subject bbox first so the
subject fills more of the visible area — deferred, not rejected: it is a
one-image change later, and it costs a bespoke build step now.

### D4 — The source image stays out of the app bundle

**Decision**: leave `images/kalahoo.jpeg` out of `pubspec.yaml`'s
`flutter: assets:` list; it is a build-time input only.

**Rationale**: the launcher icon is a native resource; the app never displays
the source at runtime, and shipping a 1024² JPEG in the bundled assets would add
weight for nothing. The fact table already shows it is not declared — this
decision is to keep it that way, and to say so, because the neighbouring
`images/kalahu.jpeg` *is* declared and invites the copy-paste.

**Alternatives considered**: declaring it as an asset "just in case" (dead
weight in every build); moving the source under `assets/` (would put a
non-runtime file in the runtime directory and invite the same mistake later).

### D5 — Generation is a developer step, never part of the build (FR-006)

**Decision**: generated icons are committed; `flutter build apk` / `flutter
build ios` never read `images/kalahoo.jpeg`.

**Rationale**: Flutter has no build hook for asset post-processing, and the
build must work offline and on a machine without the tool installed. FR-006
("handle icon generation gracefully if the source file is missing") is therefore
satisfied structurally — a missing source cannot break a build, because no build
step reads it — while the generator itself fails loudly (fact table:
`FileSystemException` / `NoDecoderForImageFormatException`), which is the
correct behaviour for a developer who asked for regeneration.

**Alternatives considered**: a Gradle task or a `flutter build` wrapper that
regenerates on every build (unavailable/fragile, and it would make the build
depend on a dev dependency); a pre-commit hook (no hooks directory in this repo,
and it would rewrite binary assets during commits).

### D6 — The configuration lives in `pubspec.yaml`

**Decision**: a `flutter_launcher_icons:` block in `pubspec.yaml`, with a
comment naming the source file, plus the dev dependency from D1.

**Rationale**: that is the tool's contract (it reads the block from `pubspec.yaml`
or `flutter_launcher_config.yaml`); keeping it beside the dependency that runs it
means one file answers "where does the icon come from". The commented block also
makes the per-platform keys (D2/D3/D7) reviewable in a diff.

**Alternatives considered**: a separate `flutter_launcher_config.yaml` (the tool
supports it, but splits one concern across two manifests).

### D7 — Scope: Android and iOS only

**Decision**: configure `android: true` and `ios: true`; leave the macOS, web,
Windows and (absent) Linux icon sets alone.

**Rationale**: the spec's FR-002/FR-003 and SC-002 name Android and iOS only, and
the constitution's target is iPhone + Android. The other sets are unvalidatable
on this host (no macOS, no Windows), so generating them would add unreviewable
binary churn.

**Alternatives considered**: `web/windows/macos: true` in the same run — one flag
each and no extra validation path; recorded here as a deliberate deferral, since
"brand every launcher" is a product decision the spec did not make.

### D8 — What the automated test asserts

**Decision**: a Dart test (`test/app_icon_test.dart`) over the **generated
artifacts**: every Android density exists as a PNG of its declared pixel size,
the adaptive XML and its foreground/background layers exist, `values/colors.xml`
declares the configured background colour, and every `filename` in the iOS
`Contents.json` exists at the size and scale its entry claims.

**Rationale**: these are contracts between the config and the files it produces —
exactly the relationship a test may freeze — and they catch the real failure mode
(a generator run with one platform disabled, a half-written asset set, a
`Contents.json` pointing at a file that no longer exists). With no CI in this
repo, a test is the only automatic check such a mistake can trip.

**Alternatives considered**: asserting pixel content (change-detector: any art
tweak fails it); asserting the config block's literal values (a change-detector
over `pubspec.yaml`, and it cannot see the files); no test at all (the mistake
surfaces only as a wrong icon on a device).

### D9 — What "verified on device" means for an icon

**Decision**: three independent pieces of evidence, in this order: (1) the APK's
packaged `res/mipmap-*/ic_launcher.png` bytes are identical to the committed
files (`unzip -p` + hash), (2) `aapt2 dump badging` names those resources as the
application icon for the densities, (3) a launcher screenshot cropped to the app
cell for human review.

**Rationale**: an icon is pixels, and this agent cannot assert a visual match
from a dump — but "the launcher loads the bytes we generated for this density" is
decidable from the APK, which is where the launcher reads them from. (1)+(2)
alone would pass if the files were wrong art; (3) alone is not machine-checkable.
Together they bound the claim honestly.

**Alternatives considered**: a screenshot-only PASS (unverifiable by the agent);
`dumpsys package`'s icon line (names the resource, says nothing about content).

## Grounding corrections to the spec's assumptions

1. **FR-002 says the Android icon is configured "in app/build.gradle and resource
   files".** There is no icon configuration in Gradle, and adding one would not
   work: `android/app/build.gradle.kts` only sets `compileSdk`/`minSdk`/`targetSdk`
   from `flutter.*`, while the manifest already points at
   `@mipmap/ic_launcher` (fact table). The change is the **resource files only**;
   Gradle is untouched.
2. **SC-002 / FR-003 ("both Android and iOS") cannot be *validated* here.**
   The iOS asset set is generated on Linux (pure file generation) and can be
   checked structurally (D8), but there is no macOS/Xcode on this host, so the
   iOS half of SC-002 stays UNVERIFIED WITH REASON in `breakpoint.md` — the same
   limitation spec 007 recorded.
3. **FR-006's "handle icon generation gracefully if the source file is missing"
   has no build-time meaning**: no build step reads the source (D5). The
   requirement is met by the generator failing loudly plus committed artifacts,
   and the quickstart proves it by moving the source away and building.
4. **The constitution's constraint line, "Android 10+ (API 29+) baseline;
   confirm in plan", does not match what ships**: the app's effective floor is
   `minSdk 24` (`flutter.minSdkVersion`), i.e. Android 7.0 (fact table). This
   feature does not change it; adaptive icons start at API 26, so they are inside
   the shipped floor. Recorded, not "fixed" — raising the floor is a product
   decision outside this spec.
5. **The adaptive layers are 108 *dp*, not 108 *px* on every density.** The
   first draft of `contracts/icon-assets.md` and `data-model.md` said "108 each";
   the generator's table scales them with the density —
   `lib/android.dart:21-27` lists `drawable-mdpi 108`, `hdpi 162`, `xhdpi 216`,
   `xxhdpi 324`, `xxxhdpi 432`, and that is what lands on disk (verified with
   PIL). The safe-zone argument (C3) is unchanged because 108 dp is the layer's
   *size in density-independent pixels*; only the pixel assertions in
   `test/app_icon_test.dart` were wrong and are now per-density.
6. **The spec's edge case "icon file size too large" is not a real risk here**:
   the source is 1024×1024 and every generated asset is smaller (fact table
   sizes); there is no compression step to configure and no size limit that
   applies to a launcher resource.

## Interfaces and contracts

No HTTP/API surface. The feature's real interface is the **generated asset set**
and the resource names the platform resolves: see
[contracts/icon-assets.md](./contracts/icon-assets.md). Entities (source,
configuration, generated sets) are in [data-model.md](./data-model.md).
