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

  // TODO: Replace the placeholder values below with the actual values
  // from android/app/google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO: apiKey',
    appId: 'TODO: appId',
    messagingSenderId: 'TODO: messagingSenderId',
    projectId: 'TODO: projectId',
    storageBucket: 'TODO: storageBucket',
  );
}
