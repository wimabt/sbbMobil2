# sbb_mobile

SBB Mobile App - Flutter implementation of the React web application.

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Google Maps API Key (for map functionality)

### Google Maps API Key Setup

The app uses Google Maps for the map screen. You need to set up an API key:

1. **Get a Google Maps API Key:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Enable "Maps SDK for Android" (Android için) ve "Maps SDK for iOS" (iOS için)
   - **Credentials** → **Create Credentials** → **API Key** seçin
   - **ÖNEMLİ:** JavaScript key DEĞİL, **Android API key** kullanın!
   - API key'i kısıtlamak için:
     - **Application restrictions** → **Android apps** seçin
     - Package name: `com.example.sbb_mobile` (veya projenizin package name'i)
     - SHA-1 certificate fingerprint ekleyin (debug ve release için)

2. **Add API Key to Android:**
   - Open `android/app/src/main/AndroidManifest.xml`
   - Find the line: `<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_API_KEY_HERE" />`
   - Replace `YOUR_API_KEY_HERE` with your **Android API key** (JavaScript key değil!)
   - Dosyayı kaydedin

3. **Add API Key to iOS (if needed):**
   - Open `ios/Runner/AppDelegate.swift`
   - Add: `GMSServices.provideAPIKey("YOUR_API_KEY_HERE")`
   - Replace `YOUR_API_KEY_HERE` with your **iOS API key** (veya kısıtlanmamış bir key)
   
### API Key Tipleri

- ❌ **JavaScript key** → Web uygulamaları için (React, Angular, vb.)
- ✅ **Android API key** → Android mobil uygulamaları için (Flutter Android)
- ✅ **iOS API key** → iOS mobil uygulamaları için (Flutter iOS)
- ✅ **Kısıtlanmamış key** → Tüm platformlar için (geliştirme aşamasında)

**Not:** Geliştirme aşamasında kısıtlanmamış bir key kullanabilirsiniz, ancak production'da mutlaka kısıtlayın!

### Running the App

```bash
# Install dependencies
flutter pub get

# Run on Android
flutter run

# Run on iOS
flutter run
```

## Project Structure

- `lib/features/` - Feature-based architecture
- `lib/core/` - Core utilities (routing, theme, etc.)
- `lib/main.dart` - App entry point

## Features

- ✅ Home screen with hero section and quick access
- ✅ Places listing and detail pages
- ✅ Routes listing and detail pages
- ✅ Recipes listing and detail pages
- ✅ Culture & Arts section
- ✅ Announcements
- ✅ Campaigns
- ✅ Map with Google Maps integration
- ✅ User profile
- ✅ Theme support (Light/Dark/System)

## Notes

- The app uses Riverpod for state management
- GoRouter for navigation
- Material Design 3 theming
