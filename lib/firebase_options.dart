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

  String _readRequired(String field) {
    final value = config[field];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw StateError('Missing Firebase config field: $field');
  }

  String? _readOptional(String field) {
    final value = config[field];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  return FirebaseOptions(
    apiKey: _readRequired('apiKey'),
    authDomain: _readRequired('authDomain'),
    projectId: _readRequired('projectId'),
    storageBucket: _readRequired('storageBucket'),
    messagingSenderId: _readRequired('messagingSenderId'),
    appId: _readRequired('appId'),
    measurementId: _readOptional('measurementId'),
  );
}
