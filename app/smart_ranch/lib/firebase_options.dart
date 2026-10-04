// File generated for smartranch-innova
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA9aFR2W6KRQoMYNaKkfbn4ourvW314XAI',
    appId: '1:486367377643:web:af0935b50da93a0919a6ae',
    messagingSenderId: '486367377643',
    projectId: 'smartranch-innova',
    authDomain: 'smartranch-innova.firebaseapp.com',
    storageBucket: 'smartranch-innova.firebasestorage.app',
    databaseURL: 'https://smartranch-innova-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA9aFR2W6KRQoMYNaKkfbn4ourvW314XAI',
    appId: '1:486367377643:android:e1180dee76ebd68019a6ae',
    messagingSenderId: '486367377643',
    projectId: 'smartranch-innova',
    storageBucket: 'smartranch-innova.firebasestorage.app',
    databaseURL: 'https://smartranch-innova-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA9aFR2W6KRQoMYNaKkfbn4ourvW314XAI',
    appId: '1:486367377643:web:af0935b50da93a0919a6ae',
    messagingSenderId: '486367377643',
    projectId: 'smartranch-innova',
    authDomain: 'smartranch-innova.firebaseapp.com',
    storageBucket: 'smartranch-innova.firebasestorage.app',
    databaseURL: 'https://smartranch-innova-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA9aFR2W6KRQoMYNaKkfbn4ourvW314XAI',
    appId: '1:486367377643:ios:smartranch-innova',
    messagingSenderId: '486367377643',
    projectId: 'smartranch-innova',
    storageBucket: 'smartranch-innova.firebasestorage.app',
    databaseURL: 'https://smartranch-innova-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA9aFR2W6KRQoMYNaKkfbn4ourvW314XAI',
    appId: '1:486367377643:ios:smartranch-innova',
    messagingSenderId: '486367377643',
    projectId: 'smartranch-innova',
    storageBucket: 'smartranch-innova.firebasestorage.app',
    databaseURL: 'https://smartranch-innova-default-rtdb.firebaseio.com',
  );
}
