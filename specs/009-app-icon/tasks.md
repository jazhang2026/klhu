# Tasks: App Icon Update

**Feature**: `009-app-icon` | **Date**: 2026-09-23
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Contract**: [contracts/icon-assets.md](./contracts/icon-assets.md) | **Validation**: [quickstart.md](./quickstart.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete dependency), `[Story]` = the spec's single story, `US1`.

## Status

**All 12 tasks done (2026-09-23).** `flutter analyze` clean,
`flutter test --concurrency=2` → **234 passing, 0 failing** (218 before this
feature + 16 in `test/app_icon_test.dart`). The device walk is recorded in
[breakpoint.md](./breakpoint.md): scenarios 1/3/4/5 walked PASS, 2 `[unit]`,
6/7 `[structural]`, and the iOS device half carries UNVERIFIED WITH REASON.

Deviations from the text above, recorded rather than silently absorbed:

1. **T002/T004 — the iOS assertion is a required-size set, not a count.** The
   generator's catalogue ships 25 entries (it also carries the legacy
   `50x50`/`57x57`/`72x72` iPhone+iPad sizes), so "the shipped catalogue is 15
   icons" would have failed on a correct run and was a change-detector anyway;
   the test now asserts the sizes a device and the App Store actually resolve.
2. **T002/T003 — the adaptive layers are 108 _dp_**, i.e. 108/162/216/324/432 px
   per density, not 108 px everywhere. Corrected in the contract, the data model
   and this file (T002's wording), and recorded as `research.md` § Grounding
   corrections 5.
3. **T003 — the generator also rewrote `ios/Runner.xcodeproj/project.pbxproj`**
   (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` `YES` →
   `AppIcon`, the wrong setting). Reverted, added to T005's forbidden list, and
   written into the regeneration runbook in `README.md`
   (`breakpoint.md` divergence 1).
4. **T005 — the forbidden list grew the Xcode project**, and the scope check is
   now scripted rather than eyeballed: no changed path outside
   `android/app/src/main/res/`, `ios/Runner/Assets.xcassets/`, `pubspec.*`,
   `test/app_icon_test.dart` and `specs/`.
5. **T007 — the launcher's workspace icons are not addressable by a dump** on
   this image (its node list has no per-icon entries), so the launcher half is
   the **app drawer** cell (its node box doubles as the icon square) and the
   **Settings app-info header**, both compared by template match against the art
   and against the default icon still in `HEAD` — ratios 0.22 and 0.37. The
   Settings SPA screen exports no `ImageView` either (`breakpoint.md`
   divergences 4/5).
6. **T008 — PASS structurally, device half UNVERIFIED**: 25 catalogue entries,
   25 files, 0 violations, every PNG RGB (no alpha). No macOS on this host.
7. **The two walk scripts are committed** under
   [scripts/](./scripts/) (`icon_render_check.py`,
   `ios_set_and_missing_source.py`) with `ADB_SERIAL`/`KLHU_REPO`/`KLHU_OUT`
   parameters instead of hardcoded paths, so the evidence outlives the scratch
   copies (spec 008's lesson).

## Grounding notes (decisions these tasks implement)

1. **The generator is `flutter_launcher_icons ^0.14.4`, dev-only**, run by hand
   (`dart run flutter_launcher_icons`); its 7 transitives are dev-time (research D1).
2. **One source for both platforms**: `images/kalahoo.jpeg`, with
   `remove_alpha_ios: true` + `background_color_ios: "#ffffff"` (D2).
3. **Adaptive icon** = background `#ffffff` + the source as foreground, inset 16 %
   by the tool's default — no pre-cropping needed because the measured subject is
   already 92.2 % inside the safe zone (D3). Colour background ⇒ the tool writes
   `values/colors.xml`, not a background PNG (`contracts/icon-assets.md` V2).
4. **The source stays out of `flutter: assets:`** — build-time input only (D4).
5. **Icons are committed; the build never reads the source** — that is what FR-006
   resolves to (D5), and T009 proves both halves.
6. **Scope is Android + iOS**; `macos/`, `web/`, `windows/` (and `linux/`) keep the
   Flutter default icons (D7) — their absence from the diff is part of the check.
7. **Gradle is untouched** — the manifest already declares
   `android:icon="@mipmap/ic_launcher"` (research § Grounding corrections 1).
8. **The iOS half cannot be validated here** (no macOS/Xcode): generated +
   structurally checked, device UNVERIFIED WITH REASON (correction 2, D9).
9. **Tests are written first** (constitution III): T002 must be run and seen
   failing before T003 generates anything.

## Path conventions

- Platform resources: `android/app/src/main/res/**`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/**`
- `export PATH=$HOME/development/flutter/bin:$PATH`; `flutter test --concurrency=2`
  (the emulator is up on this box); APK inspection uses
  `~/Android/Sdk/build-tools/36.0.0/aapt2` and `unzip`
- Device commands target `emulator-5554` (AVD `klhu`, API 36)

---

## Phase 1: Setup (shared infrastructure)

**Purpose**: the tool and its configuration — no generated art yet.

- [x] T001 Add the icon generator to `pubspec.yaml`: `flutter_launcher_icons: ^0.14.4`
      under `dev_dependencies`, plus the `flutter_launcher_icons:` block exactly as
      [contracts/icon-assets.md](./contracts/icon-assets.md) § 1 specifies —
      `image_path: "images/kalahoo.jpeg"`, `android: true`, `ios: true`,
      `adaptive_icon_background: "#ffffff"`,
      `adaptive_icon_foreground: "images/kalahoo.jpeg"`, `remove_alpha_ios: true`,
      `background_color_ios: "#ffffff"` (no `adaptive_icon_foreground_inset`, no
      `min_sdk_android`, no `web`/`windows`/`macos`), then `flutter pub get` and
      confirm `pubspec.lock` gains only the dev-time packages listed in research D1

**Checkpoint**: `flutter pub get` resolves; `pubspec.yaml` carries the block; no
icon file has changed yet.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the acceptance contract that turns "the icons look right" into
something a machine checks.

**⚠️ CRITICAL**: T002 must be RED before T003 runs.

- [x] T002 Write `test/app_icon_test.dart` — the generated-asset contract from
      [data-model.md](./data-model.md) (I4/I6/I7) and
      [contracts/icon-assets.md](./contracts/icon-assets.md) § 2/§ 3: for each
      density the legacy mipmap is 48/72/96/144/192 px, each
      `drawable-*/ic_launcher_foreground.png` is 108 dp at that density
      (108/162/216/324/432 px), `mipmap-anydpi-v26/ic_launcher.xml`
      exists and references `@color/ic_launcher_background` plus an inset
      foreground, `values/colors.xml` declares `#ffffff`, **no**
      `drawable-*/ic_launcher_background.png` exists, and every `filename` in the
      iOS `Contents.json` exists at `size × scale` with colour type 2 (RGB, no
      alpha). Read PNG dimensions/colour type from the IHDR bytes directly (offsets
      16–24 and byte 25) — do **not** add an image-decoding dependency. Run it and
      keep the RED output (`flutter test test/app_icon_test.dart`)

**Checkpoint**: the contract test exists and fails on the current default icons.

---

## Phase 3: User Story 1 — Custom App Icon (P1) 🎯 MVP

**Goal**: the launcher shows the project's own art on Android and iOS, in every
density, with a correct adaptive icon on Android 8+ — and the shipped APK provably
carries exactly those bytes.

**Independent Test**: install on `emulator-5554`, `pm clear`, return to the
launcher: the app's cell shows the character art (not the Flutter logo), and the
APK's packaged `res/mipmap-*/ic_launcher.png` are byte-identical to the generated
files.

### Implementation for US1

- [x] T003 [US1] Run `dart run flutter_launcher_icons` — generated set: `android/app/src/main/res/`
      and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`: the five
      `android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`, the five
      `drawable-…/ic_launcher_foreground.png`, `mipmap-anydpi-v26/ic_launcher.xml`,
      `values/colors.xml`, the 15 `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`
      and its regenerated `Contents.json`
- [x] T004 [US1] Turn the contract green — `flutter test test/app_icon_test.dart`
      (RED in T002 → PASS here) — and keep `flutter analyze` clean
      (`flutter analyze`)
- [x] T005 [US1] Scope check over `android/app/src/main/res/`, `ios/` and
      `android/app/build.gradle.kts`: `git status --short` lists only the T003 paths plus
      `pubspec.yaml`/`pubspec.lock`/`test/app_icon_test.dart`. Forbidden in the diff:
      `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`,
      `android/app/src/main/res/values/strings.xml`, and anything under `macos/`,
      `web/`, `windows/`, `linux/` (`macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
      must be unchanged)
- [x] T006 [US1] Build and prove the packaged bytes in `build/app/outputs/flutter-apk/app-debug.apk`:
      `flutter build apk --debug`, then compare `unzip -p build/app/outputs/flutter-apk/app-debug.apk
      res/mipmap-xxhdpi/ic_launcher.png` (and one more density) against
      `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` by sha256, and
      `~/Android/Sdk/build-tools/36.0.0/aapt2 dump badging … | grep application-icon`
      (quickstart § 1)
- [x] T007 [US1] Device walk on `emulator-5554` per [quickstart.md](./quickstart.md) § 1/3/4:
      install, `pm clear`, a home-screen screenshot, the app's entry in Settings → Apps, and the packaged adaptive
      descriptor (`unzip -l … | grep -E "anydpi|ic_launcher_foreground"`); keep the
      evidence lines and the screenshot paths
- [x] T008 [US1] iOS structural check of `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` (no macOS):
      run the catalogue ↔ files check from [quickstart.md](./quickstart.md) § 6 over the
      generated set, keep its output, and mark the device half of SC-002 as
      UNVERIFIED WITH REASON
- [x] T009 [US1] Prove FR-006 both ways per [quickstart.md](./quickstart.md) § 5:
      with `images/kalahoo.jpeg` moved aside, `flutter build apk --debug` **succeeds**
      (nothing in the build reads it) and `dart run flutter_launcher_icons` **fails
      loudly** (non-zero exit, no partial asset set); restore the file afterwards

**Checkpoint**: `US1` is complete and independently demonstrable — the generated
set is green in the contract test, the APK carries it, the device shows it.

---

## Phase 4: Polish & cross-cutting concerns

- [x] T010 [P] Write `specs/009-app-icon/breakpoint.md`: the per-scenario PASS/FAIL
      rows for quickstart § 1–7 with their evidence lines, the UNVERIFIED WITH REASON
      rows (iOS device half; anything dump-polling cannot show), the divergences found
      during the walk, and the measured facts (source bbox, safe-zone fit, APK hashes)
- [x] T011 [P] Update `README.md`: the icon source and the one-line regeneration
      command in the Development section, the dev-only dependency, the 009 row in the
      spec index, and the standing limitation that the iOS icon is unvalidated here
- [x] T012 Tick the boxes in `specs/009-app-icon/tasks.md`, record any deviation
      inline (moved work, superseded steps) instead of leaving the list disagreeing
      with the tree, run the tasks-format checker over `specs/009-app-icon/tasks.md`,
      and finish with `flutter analyze` + the full suite (`flutter test --concurrency=2`)

---

## Dependencies & ordering

- **T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → Polish.**
  The order is a dependency chain, not a preference: T003 needs the config from
  T001, T004 needs the test from T002, T006 needs the generated assets, T007 needs
  the installed build.
- **T002 blocks T003** in the TDD sense: a test first seen passing proves nothing
  (constitution III).
- **T005 and T009 are the two "must not happen" guards** (unrelated platform churn;
  a build that depends on the source) — they are cheap and they are the ones a
  reviewer will ask about.
- **T008 does not block T007** and vice versa; both depend on T003.

## Parallel opportunities

- Phase 4's T010 and T011 are independent files (`breakpoint.md`, `README.md`) and
  can be written together once T007–T009 have produced their evidence.
- Within US1 the chain is sequential — one command generates every file, so
  splitting it would create tasks that cannot be verified apart.

## Implementation strategy

1. **MVP** = Phase 1 + Phase 2 + US1 (T001–T009): both platforms carry the app's
   own icon, with the Android adaptive layer and the packaged-bytes proof.
2. **Polish** = T010–T012: the written record, the README, the final ticks.
3. There is no second increment: the spec has one story, and the per-story phasing
   the template describes collapses to a single phase (`research.md` D7 records the
   one thing deliberately left out — the other platforms' icon sets).

## Notes

- Regenerating the icons rewrites binary files; expect a diff of ~28 assets and
  review it as a set (dimension changes are caught by the contract test, art changes
  are not — the screenshot is what covers those).
- The generator is idempotent: re-running it with an unchanged source and config
  produces byte-identical files, so a re-run that shows churn means the config moved.
- Never add the icon source to `pubspec.yaml`'s `assets:` list (D4) — the app never
  renders it at runtime.
- `flutter test` needs `--concurrency=2` on this machine while the emulator runs.

---

## Requirement coverage

| Requirement | Tasks |
|---|---|
| FR-001 use `images/kalahoo.jpeg` as the source | T001, T003, T009 |
| FR-002 configure the Android icon in resources (Gradle not involved — correction 1) | T001, T003, T005, T006 |
| FR-003 configure the iOS icon set | T001, T003, T008 |
| FR-004 generate the required densities | T002, T003, T004, T007 |
| FR-005 keep quality and aspect ratio across sizes | T002, T003 (single square ≥1024 source, clean downscales) |
| FR-006 handle a missing source gracefully | T009 |
| SC-001 the icon appears in the launcher | T006, T007 |
| SC-002 both platforms | T007 (Android), T008 (iOS structural only) |
| SC-003 quality across densities | T002, T004 |
| SC-004 generation without build errors | T004, T006, T009 |
| SC-005 matches the intended branding | T003, T007 (the source is used unchanged; both platforms from one file) |
