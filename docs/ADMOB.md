# AdMob

Ads follow the same setup as Vajra Automate: optional, consent-gated, and off unless a real ad unit is
supplied at build time.

## How it behaves

- Only Google's documented **test** IDs exist in the code (`ca-app-pub-3940256099942544/...`).
- **Release builds** request ads only when built with `--dart-define=ADMOB_BANNER_UNIT_ID=...`. Without it, no ads load.
- **Debug builds** show Google's test banner only with `--dart-define=FORCE_ADS=true` (`kDebugMode && FORCE_ADS`, so a
  release build can't honour it).
- The AdMob **app ID** goes into the manifest from the Gradle property `ADMOB_APP_ID`
  (`--android-project-arg=ADMOB_APP_ID=...`). It defaults to Google's test app ID; release builds fail on a malformed
  ID and warn when the test ID is used.
- **Consent**: Google's User Messaging Platform runs once the app has loaded, and shows its form only where the law
  requires it (e.g. EEA/UK). If consent is refused or fails, nothing is requested. Settings shows **Ad privacy options**
  when UMP says the user must be able to change their choice.
- **Placement**: one banner pinned above the navigation bar on the **Upcoming** and **Age** tabs only. Never in
  Settings, editors, imports, permission prompts or dialogs.
- A failed load is retried 3 times (after 20 s, 60 s and 180 s); then the banner stays collapsed. The app is identical
  without ads.
- Every stage logs with the `Ads:` prefix: `adb logcat -s flutter | grep "Ads:"`.

## What you must do before ads earn anything

1. In your AdMob account, add the Android app **`com.chandra.agecalculator`** (Age Calculator). Vajra's IDs can't be
   reused: AdMob ties each app ID and ad unit to one app.
2. Copy its **App ID** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`) and create a **Banner** ad unit
   (`ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`).
3. Build the release with both:
   ```bash
   flutter build appbundle --release \
     --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ \
     --android-project-arg=ADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
   ```
4. AdMob → Privacy & messaging: create and publish a GDPR message (and US states if relevant); UMP shows it.
5. Add `app-ads.txt` to <https://chandrachaan.com/> with the line AdMob gives you.
6. Play Console → App content: set **Ads: Yes**, complete the **Advertising ID** declaration, and update **Data safety**
   (device or other IDs, collected and shared, for advertising). Publish the updated privacy policy
   (`docs/privacy-policy.html`) first.
7. Test with your device registered as an AdMob test device. Never tap your own live ads.
