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
    apiKey: 'AIzaSyAGtkCWIPweFf4kNMIFsblbS_D5JpXvBVw',
    appId: '1:707465476062:web:645f68ab01cdf060c7cf4f',
    messagingSenderId: '707465476062',
    projectId: 'pathlume-18e66',
    authDomain: 'pathlume-18e66.firebaseapp.com',
    storageBucket: 'pathlume-18e66.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAGtkCWIPweFf4kNMIFsblbS_D5JpXvBVw',
    appId: '1:707465476062:android:645f68ab01cdf060c7cf4f',
    messagingSenderId: '707465476062',
    projectId: 'pathlume-18e66',
    storageBucket: 'pathlume-18e66.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAGtkCWIPweFf4kNMIFsblbS_D5JpXvBVw',
    appId: '1:707465476062:ios:645f68ab01cdf060c7cf4f',
    messagingSenderId: '707465476062',
    projectId: 'pathlume-18e66',
    storageBucket: 'pathlume-18e66.firebasestorage.app',
    iosBundleId: 'com.pathlume.app',
  );
}
