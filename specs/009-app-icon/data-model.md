# Data Model: App Icon Update

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-09-23

This feature has no runtime data: nothing is stored, nothing is loaded by the
app. What exists is a **source file**, a **configuration**, and the **asset sets
a generator derives from them**. They are modelled here because the invariants
below are what the tests and the device walk actually check.

## Entities

### IconSource

The single art file the whole feature is defined by.

| Attribute | Value / rule | Source |
|---|---|---|
| Path | `images/kalahoo.jpeg` | FR-001 |
| Format | JPEG, RGB, **no alpha channel** | measured (research fact table) |
| Pixels | 1024 × 1024 (square, 1:1 — required for an icon) | measured |
| Background | uniform near-white (edge mean 253–255, max channel deviation ≤ 4.8) | measured |
| Tracked in git | yes | `git ls-files images/` |
| Declared as a Flutter asset | **no** — build-time input only | `pubspec.yaml` (D4) |

Invariants:

- **I1** The file is square and ≥ 1024 px, so every generated size is a clean
  downscale with the aspect ratio preserved (FR-005, SC-003).
- **I2** The file is not referenced by `pubspec.yaml`'s `assets:` list (D4) and
  no build step reads it (D5) — so its absence cannot change a build product.

### IconConfiguration

The declarative input that determines every generated file. Lives in
`pubspec.yaml` under `flutter_launcher_icons:` (D6).

| Field | Value | Requirement |
|---|---|---|
| `image_path` | `images/kalahoo.jpeg` | FR-001 |
| `android` | `true` | FR-002 |
| `ios` | `true` | FR-003 |
| `adaptive_icon_background` | `"#ffffff"` (the measured background of the art) | FR-005, D3 |
| `adaptive_icon_foreground` | `images/kalahoo.jpeg` | D3 |
| `adaptive_icon_foreground_inset` | omitted → tool default **16 %** | D3 |
| `remove_alpha_ios` | `true` | D2 |
| `background_color_ios` | `"#ffffff"` | D2 |
| `web` / `windows` / `macos` | omitted (out of scope) | D7 |

Validation rules:

- **V1** `image_path` and `adaptive_icon_foreground` must both resolve, and both
  adaptive keys must be present — otherwise the tool aborts with
  `InvalidConfigException` instead of producing a half-set (research D3).
- **V2** A colour background is distinct from a PNG background: colour →
  `values/colors.xml`; PNG → `drawable-*/ic_launcher_background.png` (research
  fact table). This plan uses the colour.
- **V3** No `min_sdk_android` value is set: it does not gate generation in
  0.14.4 and the shipped floor (24) is below the adaptive-icon API level (26)
  anyhow — the `-v26` resource qualifier is what decides at runtime.

### AndroidIconSet

| Artifact | Density | Pixels | Requirement |
|---|---|---|---|
| `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` | mdpi | 48 | FR-004 |
| `…/mipmap-hdpi/ic_launcher.png` | hdpi | 72 | FR-004 |
| `…/mipmap-xhdpi/ic_launcher.png` | xhdpi | 96 | FR-004 |
| `…/mipmap-xxhdpi/ic_launcher.png` | xxhdpi | 144 | FR-004 |
| `…/mipmap-xxxhdpi/ic_launcher.png` | xxxhdpi | 192 | FR-004 |
| `…/values/colors.xml` | — | declares `ic_launcher_background` = `#ffffff` | FR-002, D3 |
| `…/mipmap-anydpi-v26/ic_launcher.xml` | — | `<adaptive-icon>` with `background` + `<foreground><inset android:inset="16%">` | FR-004, D3 |
| `…/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png` | 5 densities | 108 dp → 108/162/216/324/432 px | FR-004 |
| `…/drawable-{mdpi…xxxhdpi}/ic_launcher_background.png` | — | **absent** (colour background) | V2 |

Invariants:

- **I3** The manifest's `android:icon="@mipmap/ic_launcher"` resolves on every
  density: the legacy PNGs and (API ≥ 26) the `anydpi-v26` XML exist together
  (research fact table).
- **I4** Each file's pixel size equals its density's declared size — for the
  legacy icons 48/72/96/144/192 px, for the adaptive layers 108 dp scaled to the
  density (108/162/216/324/432 px). A relationship between config and artifact,
  not a snapshot of the art.
- **I5** `values/colors.xml` is the **only** new non-PNG Android file; the tool
  creates it when missing and updates the single `ic_launcher_background` entry
  when present, leaving unrelated colours alone.

### IosIconSet

15 PNGs in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (20², 29², 40²,
60², 76², 83.5², 1024²; @1x/@2x/@3x variants) plus `Contents.json`.

Invariants:

- **I6** Every `filename` in `Contents.json` exists, at the pixel size its
  `size` × `scale` entry states (D8) — the failure this catches is a stale
  catalogue entry pointing at a renamed file.
- **I7** The PNGs carry **no alpha channel** (`remove_alpha_ios`, D2), unlike the
  RGBA set committed today.
- **I8** The 1024² entry is the one the App Store validates; it is a downscale
  target of the same source as Android's, so the two platforms cannot drift.

### GeneratedAssets (the committed deliverable)

The set of files a developer regenerates; **not** a build input (D5).

State transitions (per generation run, not at runtime):

```
source present ──> [dart run flutter_launcher_icons] ──> assets written ──> committed
source missing ──> generator fails loudly (non-zero exit), no partial set preferred
source unreadable ──> NoDecoderForImageFormatException, same
```

Invariants:

- **I9** A build never depends on this feature's source or tooling: `flutter
  build apk` succeeds with `images/kalahoo.jpeg` absent (quickstart 5).
- **I10** The APK's packaged `res/mipmap-*/ic_launcher.png` bytes equal the
  committed files (quickstart 1) — the launcher reads them from there.
- **I11** The other platforms' icon sets (macos, web, windows) are unchanged by
  this feature (D7, quickstart 7).

## Requirement coverage

| Requirement | Where it lands |
|---|---|
| FR-001 source file | IconSource; `image_path` |
| FR-002 Android configuration + resources | AndroidIconSet (Gradle untouched, correction 1) |
| FR-003 iOS assets | IosIconSet (structurally checked; device UNVERIFIED, correction 2) |
| FR-004 density variants | AndroidIconSet sizes; IosIconSet entries; I4, I6 |
| FR-005 quality / aspect ratio | I1 (square ≥1024 source, clean downscales); I8 (one source, both platforms) |
| FR-006 missing source handled | D5 + I9 (builds never read it); generator fails loudly |
| SC-001 launcher shows the icon | quickstart 1 (packaged bytes + badging + screenshot) |
| SC-002 both platforms | quickstart 1 (Android) / 6 (iOS structural only) |
| SC-003 quality across densities | quickstart 2 (dimension contract per density) |
| SC-004 no build errors | quickstart 5 (build with and without the source) |
| SC-005 matches the intended branding | the source itself, unchanged: single 1:1 interpretation, both platforms |
