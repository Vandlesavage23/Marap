# Fonts (Bible §16)

Design: a **serif for headings** and a **sans for body/UI**, bundled as subsets
(Latin + Latin Extended) so the app never downloads fonts at runtime.

## Current state

The theme already declares two font families, `McSerif` (headings) and
`McSans` (body), in `apps/mobile/lib/src/core/theme/tokens.dart` (`McFonts`).
**No font files are bundled yet**, so Flutter silently falls back through
`McFonts.headingFallback` (Noto Serif, Georgia, Times New Roman, serif) and
`McFonts.bodyFallback` (Roboto, Noto Sans, San Francisco, Helvetica Neue,
Arial, sans-serif). The app renders correctly today; only the brand look is
missing. Layout is tested at 200% text scale with the test font; after adding the real
fonts, check wrapping visually on a device (the test goldens do not use them).

## What a human must add

Pick any pair with an open licence (SIL OFL / Apache 2.0). Suggested, matching
the warm, respectful tone:

| Role | Family | Weights needed |
| --- | --- | --- |
| Headings (`McSerif`) | Source Serif 4 (or Lora / Merriweather) | 600, 700 |
| Body (`McSans`) | Inter (or Noto Sans / Source Sans 3) | 400, 600 |

1. Download the static TTF/OTF files (or variable fonts) from the foundry.
2. Subset to **Latin + Latin Extended** to keep each file small (target under
   60 KB each), e.g. with `pyftsubset` from fonttools:

   ```bash
   pyftsubset SourceSerif4-Bold.ttf \
     --unicodes="U+0000-00FF,U+0100-024F,U+1E00-1EFF,U+2013-2014,U+2018-201D,U+2022,U+2026,U+20AC" \
     --layout-features='*' --flavor=ttf --output-file=assets/fonts/McSerif-Bold.ttf
   ```

   (Repeat per file. Keep `U+20AC` and add `U+20B5`-style currency symbols only
   if needed; Ugandan shilling is written "UGX", so no special glyph is needed.)
3. Put the files in `apps/mobile/assets/fonts/` and commit the OFL/Apache
   licence text next to them as `assets/fonts/LICENSES.txt`.
4. Add to `apps/mobile/pubspec.yaml`, under the existing `flutter:` key
   (keep `uses-material-design`, `generate`, `assets`):

   ```yaml
   flutter:
     fonts:
       - family: McSerif
         fonts:
           - asset: assets/fonts/McSerif-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/McSerif-Bold.ttf
             weight: 700
       - family: McSans
         fonts:
           - asset: assets/fonts/McSans-Regular.ttf
             weight: 400
           - asset: assets/fonts/McSans-SemiBold.ttf
             weight: 600
   ```

5. `flutter pub get`, run the app, check headings (serif) and body (sans) and
   Latin Extended names (e.g. "Zoë", "Ngũgĩ") on a small Android device at
   default and 200% font size.

No Dart change is needed: family names and fallbacks are already wired through
`buildTheme()`.

## Do not

* Do not load fonts through `google_fonts` (runtime download, not on the
  approved package list).
* Do not add font files that are not under an open licence.
