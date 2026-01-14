import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

FirebaseOptions get webFirebaseOptions {
  if (!kIsWeb) {
    throw StateError('webFirebaseOptions is only supported on web');
  }

  final dynamic config = js.context['__FIREBASE_CONFIG'];

  String? _readJsString(String key) {
    if (config == null) return null;
    final value = config[key];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  String? _readEnv(String key) {
    final v = String.fromEnvironment(key, defaultValue: '');
    return v.isEmpty ? null : v;
  }

  String _require(String? value, String field) {
    if (value != null && value.isNotEmpty) return value;
    throw StateError('Missing Firebase config field: $field');
  }

  return FirebaseOptions(
    apiKey: _require(_readJsString('apiKey') ?? _readEnv('FIREBASE_API_KEY'), 'apiKey'),
    authDomain:
        _require(_readJsString('authDomain') ?? _readEnv('FIREBASE_AUTH_DOMAIN'), 'authDomain'),
    projectId:
        _require(_readJsString('projectId') ?? _readEnv('FIREBASE_PROJECT_ID'), 'projectId'),
    storageBucket: _require(
        _readJsString('storageBucket') ?? _readEnv('FIREBASE_STORAGE_BUCKET'), 'storageBucket'),
    messagingSenderId: _require(_readJsString('messagingSenderId') ??
        _readEnv('FIREBASE_MESSAGING_SENDER_ID'), 'messagingSenderId'),
    appId: _require(_readJsString('appId') ?? _readEnv('FIREBASE_APP_ID'), 'appId'),
    measurementId:
        _readJsString('measurementId') ?? _readEnv('FIREBASE_MEASUREMENT_ID'),
  );
}
