import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Default [FirebaseOptions] for the app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // Values from android/app/google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyExampleKey',
    appId: '1:1234567890:android:abcdef123456',
    messagingSenderId: '1234567890',
    projectId: 'reduce-smoking-app',
    storageBucket: 'reduce-smoking-app.appspot.com',
  );
}
