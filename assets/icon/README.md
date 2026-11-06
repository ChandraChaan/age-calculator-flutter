# Age Calculator – App Icon

iOS-style glass, no colour: a frosted glass calendar card with a white cake on
a graphite-to-black gradient.

| File | Purpose |
|------|---------|
| `android/app/src/main/res/drawable/ic_launcher_background.xml` | Adaptive icon background (gradient + soft light) |
| `android/app/src/main/res/drawable/ic_launcher_foreground.xml` | Glass card, rings and cake, inside the 66dp safe zone |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | Legacy icons for Android 7.x |
| `store_assets/icon-512.png` | Google Play listing icon |

The PNGs and all store listing images are rendered by
`tool/store_assets/render_store_assets_test.dart`:

```bash
flutter test tool/store_assets/render_store_assets_test.dart
```
