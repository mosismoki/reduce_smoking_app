# reduce_smoking_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase configuration

This project uses Firebase. Download your `google-services.json` from the
Firebase console and place it in `android/app/`.

If you enable API key restrictions, ensure the Android package name matches the
application ID in `android/app/build.gradle.kts`:

```
applicationId = "com.example.reduce_smoking_app"
```

API key restrictions that do not include this package name will block the app
from connecting to Firebase.
