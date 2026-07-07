# Age Calculator

A clean, modern, and lightweight **Age Calculator** built with Flutter and Material 3. Calculate your exact age instantly with detailed breakdowns, birthday countdown, and beautiful light/dark themes — designed for Android and ready for the Google Play Store.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Dart](https://img.shields.io/badge/Dart-3.x-blue)
![Material 3](https://img.shields.io/badge/Material-3-purple)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Project Overview

**Age Calculator** is an offline-first Android utility app that lets users select their date of birth and instantly view a comprehensive age breakdown. The app follows Flutter best practices with a modular architecture that separates UI, business logic, and utilities.

Built with Material 3, it features responsive layouts, animated result cards, leap-year-aware calculations, and persistent theme preferences. No backend, authentication, or network access is required.

| Detail | Value |
|--------|-------|
| Package name | `com.chandra.agecalculator` |
| App name | Age Calculator |
| Min SDK | 23 (Android 6.0) |
| Target SDK | Latest Android SDK |

---

## Features

- **Exact age calculation** — Years, months, days, weeks, hours, and minutes
- **Total time lived** — Total days, months, weeks, hours, and minutes
- **Birthday insights** — Next birthday countdown, birthday weekday, age in months/days
- **Material 3 UI** — Rounded cards, smooth animations, and clean typography
- **Dark & Light mode** — AppBar theme toggle with SharedPreferences persistence
- **Date picker** — Native Flutter date picker with future-date validation
- **Leap year support** — Correct handling of February 29 birthdays
- **Offline first** — No backend, no internet required
- **Accessible** — Semantic labels and readable contrast
- **Lightweight** — Minimal dependencies, fast startup

---

## Screenshots

> Capture screenshots after running the app and place them in `assets/screenshots/`.

| Light Mode | Dark Mode | Results |
|:----------:|:---------:|:-------:|
| _Add screenshot_ | _Add screenshot_ | _Add screenshot_ |

```bash
flutter run
```

---

## Installation

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable)
- Android Studio or VS Code with Flutter extensions
- Android SDK (API 23+)

### Steps

```bash
git clone https://github.com/<your-username>/agecalculator.git
cd agecalculator
flutter pub get
flutter run
```

---

## Folder Structure

```
agecalculator/
├── android/                    # Android platform configuration
├── assets/
│   ├── icon/                   # App icon documentation
│   └── screenshots/            # App screenshots for README / Play Store
├── lib/
│   ├── main.dart               # App entry point
│   ├── app.dart                # Root widget & theme persistence
│   ├── theme/
│   │   └── app_theme.dart      # Material 3 light/dark themes
│   ├── models/
│   │   └── age_result.dart     # Age calculation result model
│   ├── services/
│   │   └── age_service.dart    # Age calculation business logic
│   ├── screens/
│   │   └── home_screen.dart    # Main home screen
│   ├── widgets/
│   │   ├── dob_picker.dart     # Date of birth picker
│   │   ├── age_card.dart       # Animated age metric card
│   │   ├── info_card.dart      # Grouped info card
│   │   └── theme_switch.dart   # Theme toggle button
│   └── utils/
│       └── date_utils.dart     # Date helpers & formatting
├── test/
│   ├── age_service_test.dart   # Unit tests for age logic
│   └── widget_test.dart        # Widget smoke tests
├── pubspec.yaml
├── README.md
└── LICENSE
```

---

## Technologies Used

| Technology | Purpose |
|------------|---------|
| Flutter | Cross-platform UI framework |
| Dart | Programming language |
| Material 3 | Modern design system |
| shared_preferences | Theme mode persistence |
| intl | Date formatting |

---

## Build Commands

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Release AAB (Play Store)
flutter build appbundle --release

# Analyze & test
flutter analyze
flutter test
```

---

## Play Store Publishing Checklist

- [ ] Update `version` in `pubspec.yaml`
- [ ] Configure release signing in `android/app/build.gradle.kts`
- [ ] Build release AAB: `flutter build appbundle --release`
- [ ] Test on multiple Android devices and screen sizes
- [ ] Prepare 512×512 app icon for Play Console
- [ ] Add screenshots and store listing copy
- [ ] Complete content rating questionnaire
- [ ] Add privacy policy (no data collected — offline app)
- [ ] Upload AAB and submit for review

---

## Future Improvements

- Share results via system share sheet
- Save calculation history locally
- Home screen widget for birthday countdown
- Multiple language support (i18n)
- Exact time-of-birth support
- Export age report as PDF
- Tablet-optimized layout
- iOS App Store release

---

## License

This project is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 Chandra Reddy
