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
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAMTRkNcgtEbI1mUEGtfC8rhb9MEDmfjE0',
    appId: '1:297037244393:web:7c3842776b6b41a7fe0d78',
    messagingSenderId: '297037244393',
    projectId: 'sira-67284',
    authDomain: 'sira-67284.firebaseapp.com',
    storageBucket: 'sira-67284.firebasestorage.app',
    measurementId: 'G-YGVCFTD21J',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyARoyB4z4EDNIOk_ucChPa8U8Ru-JkFMes',
    appId: '1:297037244393:android:741e6793764f4b7ffe0d78',
    messagingSenderId: '297037244393',
    projectId: 'sira-67284',
    storageBucket: 'sira-67284.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCcz9PZlNX4WEBbQgOCRlFJH_NWBtjlUSA',
    appId: '1:297037244393:ios:db7136c5b7f4685dfe0d78',
    messagingSenderId: '297037244393',
    projectId: 'sira-67284',
    storageBucket: 'sira-67284.firebasestorage.app',
    iosBundleId: 'online.xpertbot.sirapro',
  );
}
