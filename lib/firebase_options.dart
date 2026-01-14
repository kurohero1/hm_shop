import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

FirebaseOptions get webFirebaseOptions {
  if (!kIsWeb) {
    throw StateError('webFirebaseOptions is only supported on web');
  }

  final dynamic config = js.context['__FIREBASE_CONFIG'];
  if (config == null) {
    throw StateError('__FIREBASE_CONFIG is not defined on window');
  }

  String _readString(String key) {
    final value = config[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw StateError('Missing or invalid Firebase config field: $key');
  }

  return FirebaseOptions(
    apiKey: _readString('apiKey'),
    authDomain: _readString('authDomain'),
    projectId: _readString('projectId'),
    storageBucket: _readString('storageBucket'),
    messagingSenderId: _readString('messagingSenderId'),
    appId: _readString('appId'),
    measurementId: _readString('measurementId'),
  );
}
