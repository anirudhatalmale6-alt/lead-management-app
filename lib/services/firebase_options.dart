import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB4259m_Y1BI-McF8Q4zDTfbqc4QGtsh2o',
    appId: '1:697606010453:web:6e85781936994de974c6dc',
    messagingSenderId: '697606010453',
    projectId: 'leadmanagement-8aca6',
    authDomain: 'leadmanagement-8aca6.firebaseapp.com',
    storageBucket: 'leadmanagement-8aca6.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB4259m_Y1BI-McF8Q4zDTfbqc4QGtsh2o',
    appId: '1:697606010453:web:6e85781936994de974c6dc',
    messagingSenderId: '697606010453',
    projectId: 'leadmanagement-8aca6',
    storageBucket: 'leadmanagement-8aca6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB4259m_Y1BI-McF8Q4zDTfbqc4QGtsh2o',
    appId: '1:697606010453:web:6e85781936994de974c6dc',
    messagingSenderId: '697606010453',
    projectId: 'leadmanagement-8aca6',
    storageBucket: 'leadmanagement-8aca6.firebasestorage.app',
    iosBundleId: 'com.example.leadManagementDemo',
  );
}
