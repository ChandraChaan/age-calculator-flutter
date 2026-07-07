# Age Calculator – App Icon Assets

Modern launcher icon concept for the Age Calculator app using Material 3 colors.

## Design Concept

- **Theme:** Calendar + birthday cake
- **Primary color:** `#6750A4` (Material 3 purple)
- **Accent colors:** `#E8DEF8`, `#FFD8E4`, `#FFBA47`
- **Style:** Flat, rounded, professional, Play Store ready

## Included Assets

| File | Purpose |
|------|---------|
| `android/app/src/main/res/drawable/ic_launcher_background.xml` | Adaptive icon background |
| `android/app/src/main/res/drawable/ic_launcher_foreground.xml` | Calendar + cake foreground |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | Android adaptive icon (API 26+) |

## Recommended Production Assets

For Play Store submission, also generate:

1. **512×512 PNG** – Play Store listing icon
2. **1024×500 PNG** – Feature graphic (optional)
3. **Adaptive icon PNGs** for legacy devices using [Android Asset Studio](https://romannurik.github.io/AndroidAssetStudio/icons-launcher.html)

### Quick generation with ImageMagick (optional)

If you have ImageMagick installed, export the vector concept to PNG:

```bash
# From project root — requires a vector-to-PNG tool or design export
```

### Recommended workflow

1. Open the XML foreground/background in Android Studio
2. Use **File → New → Image Asset** to generate all mipmap densities
3. Export a 512×512 version for the Play Console

## Play Store Icon Guidelines

- No transparency in store listing icon
- Keep important content inside the safe zone (center 66%)
- Use high contrast for small sizes
- Test on light and dark launchers
