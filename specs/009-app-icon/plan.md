# Implementation Plan: App Icon Update

**Branch**: `009-app-icon` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-app-icon/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

> **Grounding notes (2026-09-23, verified in this checkout, the pub cache and on
> `emulator-5554`):** the spec's FR-002 ("configure Android app icon in
> app/build.gradle **and** resource files") does not survive the check — the
> manifest already points at `@mipmap/ic_launcher` and Gradle has no icon entry,
> so the change is **resources only** and Gradle stays untouched. FR-003's iOS
> half can be generated on Linux but **not validated** (no macOS/Xcode), so it is
> structural evidence plus an UNVERIFIED row in `breakpoint.md`. FR-006 has no
> build-time meaning: nothing in the build reads the source
> (`images/kalahoo.jpeg` is not even a declared Flutter asset), so a missing
> source cannot break a build — the generator fails loudly instead. The
> constitution's "Android 10+ (API 29+)" baseline does not match what ships
> (`minSdk 24` via `flutter.minSdkVersion`); adaptive icons start at API 26 and
> are inside that floor. See `research.md` § Grounding corrections.

## Summary

Replace the default Flutter launcher icon with the app's own art
(`images/kalahoo.jpeg`, 1024×1024 on a uniform white background) on Android and
iOS, in every density the platforms ask for, and give Android 8+ a proper
adaptive icon so the launcher's mask does not clip the subject. The work is
additive: one dev dependency (`flutter_launcher_icons 0.14.4`), one
configuration block in `pubspec.yaml`, and the generated PNG/XML asset set
committed alongside the source. No application code, no runtime dependency, no
build step — the source stays a build-time input and the generator is run by
hand. Correctness is checked by a test over the generated asset set (sizes,
formats, catalogue consistency) and by proving on device that the launcher loads
those exact bytes.

## Technical Context

**Language/Version**: Dart `^3.13.3` on Flutter 3.47.5 (stable) — unchanged; the
feature adds no Dart code to `lib/`

**Primary Dependencies**: **new (dev-only)**: `flutter_launcher_icons ^0.14.4`
(pulls `image 4.10.1`, `archive 4.3.0`, `checked_yaml 2.0.4`, `cli_util 0.4.2`,
`json_annotation 4.12.0`, `posix 6.5.2`); runtime dependencies unchanged
(`flutter_tts`, `shared_preferences`, `intl`, `path_provider`)

**Storage**: N/A at runtime. The persisted artifacts are repository files:
`android/app/src/main/res/**` (10 PNGs + `mipmap-anydpi-v26/ic_launcher.xml` +
`values/colors.xml`) and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
(15 PNGs + `Contents.json`)

**Testing**: `test/app_icon_test.dart` (new, over the generated assets) plus the
existing suite (218 tests) for regressions; device/structural walk per
`quickstart.md`; `flutter analyze` for the pubspec edit

**Target Platform**: Android (effective floor `minSdk 24`, target 36 — verified
on device; adaptive icons need API 26, inside that floor) and iOS 16+ per the
constitution (project deployment target 15.0, untouched). The macOS, web and
Windows icon sets are explicitly out of scope (`research.md` D7)

**Project Type**: Mobile app, single Flutter codebase — this feature touches
native resource directories and the manifest-level icon reference only

**Performance Goals**: N/A — build-time assets. The generator is a one-shot
developer action (seconds), never part of `flutter build`; the icon's runtime
cost is the platform's own resource lookup

**Constraints**: Constitution IV (On-Device First) — no network at runtime, no
account, nothing leaves the device; the icon source is **not** bundled
(`research.md` D4). The configuration lives in the tool's declared `pubspec.yaml`
block, not in a new mechanism. The generated assets must be reviewable in a diff
(PNG churn is expected and named in `quickstart.md` Setup)

**Scale/Scope**: 1 `dev_dependencies` entry + 1 configuration block; ~28
generated files (10 Android PNGs, 15 iOS PNGs, 1 adaptive XML, 1 `colors.xml`,
1 `Contents.json`); 1 new test file; 0 `lib/` changes; 0 new strings/ARBs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- ✅ **I. Flutter Single Codebase** — both platforms are generated from the one
  source by the one configuration; no `lib/platform/` code, no platform fork,
  no per-platform source file.
- ✅ **II. Spec-Driven (NON-NEGOTIABLE)** — spec reviewed 2026-09-23; this plan
  (+ `research.md`, `data-model.md`, `contracts/`, `quickstart.md`) precedes
  `tasks.md` and any asset generation.
- ✅ **III. Test-First (NON-NEGOTIABLE)** — the asset contract is testable
  without a device (`test/app_icon_test.dart`: pixel sizes per density, format,
  the adaptive descriptor, `colors.xml`, and the iOS catalogue's internal
  consistency); the user story's independent acceptance test is the device walk
  in `quickstart.md` 1/3/4. The test is written and seen failing before the icons
  are generated.
- ✅ **IV. On-Device First** — nothing at runtime changes; no network, no
  account, no analytics; the source image is not shipped in the bundle at all.
  The generator is a developer tool that runs offline.
- ✅ **V. Simplicity** — one maintained tool instead of a bespoke script; one
  source image; no per-platform art; no dark/tinted iOS variants
  (`image_path_ios_dark_transparent` / `…_tinted_grayscale`) and no monochrome
  Android layer, since the spec asks for none. Unrequested scope (the other
  platforms' icon sets, a splash screen, an in-app icon preview) is explicitly
  not built. The one thing added beyond a naive reading — the adaptive icon
  (D3) — replaces a visibly worse default rather than adding a feature.
- ✅ **Constraints** — the icon is a native resource, so the accessibility
  clause (TalkBack/VoiceOver, 44 pt) is unaffected; the launcher **label** stays
  the localized `@string/app_name` already in `AndroidManifest.xml`, so no locale
  work is implied. iOS 16+ baseline unchanged.

**Post-Design Re-check**: ✅ PASS — Phase 1 introduced no new dependency, entity
or Dart file beyond those listed above; the contract
(`contracts/icon-assets.md`) is expressed in resource paths and sizes, i.e. what
the platforms resolve. No `NEEDS CLARIFICATION` survives (`research.md` D1–D9).

**Note for review (one open product decision, not a blocker):** D7 keeps macOS,
web and Windows on the default Flutter icon. Flipping that is three config keys
and a regeneration, but it is unreviewable on this host (no macOS/Windows), so it
is left out rather than smuggled in.

## Project Structure

### Documentation (this feature)

```text
specs/009-app-icon/
├── plan.md                       # This file (/speckit-plan command output)
├── research.md                   # Phase 0 output (/speckit-plan command)
├── data-model.md                 # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── icon-assets.md            # Phase 1 output: the resource contract
├── quickstart.md                 # Phase 1 output (/speckit-plan command)
└── tasks.md                      # Phase 2 output (/speckit-tasks command — NOT created here)
```

### Source Code (repository root)

```text
images/
└── kalahoo.jpeg                  # Unchanged input: 1024×1024 JPEG, white bg (FR-001)

android/app/src/main/res/
├── mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png                # Regenerated: 48/72/96/144/192 (FR-004)
├── drawable-{m,h,xh,xxh,xxxh}dpi/ic_launcher_foreground.png   # New: 108 px adaptive layers
├── mipmap-anydpi-v26/ic_launcher.xml                          # New: adaptive descriptor
└── values/colors.xml                                          # New: ic_launcher_background = #ffffff

android/app/src/main/AndroidManifest.xml   # Unchanged: already android:icon="@mipmap/ic_launcher"

ios/Runner/Assets.xcassets/AppIcon.appiconset/
├── Icon-App-*.png                           # Regenerated: 15 sizes, no alpha (FR-003/004)
└── Contents.json                            # Regenerated to match

pubspec.yaml                                 # Modified: dev dependency + flutter_launcher_icons block

test/
└── app_icon_test.dart                       # New: generated-asset contract (D8)

# Untouched by design: android/app/build.gradle.kts, lib/**, macos/**, web/**, windows/**
```

**Structure Decision**: The feature lands entirely in platform resource
directories plus one configuration block — the layout Flutter itself defines — so
no new module, service or `lib/` file is created. The only Dart added is a test,
because with no CI in this repository a test is the single automatic check that
the generated set is complete and consistent (`research.md` D8). The source image
stays under `images/` and stays out of `flutter: assets:` (D4), so the shipped
bundle does not grow.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. The single new dependency is dev-only and justified in
`research.md` D1 (its alternatives are a bespoke generator or manual export); the
adaptive icon (D3) and the asset-set test (D8) are the only additions beyond the
spec's literal wording, and both are recorded in `research.md` § Decisions
rather than assumed.
