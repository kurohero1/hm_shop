import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService() {
    try {
      _auth.setLanguageCode('ja');
    } catch (_) {}
    _auth.authStateChanges().listen((user) {
      notifyListeners();
    });
  }

  bool get isAuthenticated {
    final user = _auth.currentUser;
    return user != null && user.emailVerified;
  }

  String? get email => _auth.currentUser?.email;

  Future<bool> signIn(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return false;
      }
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        await _auth.signOut();
        return false;
      }
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('signIn error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('signIn error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
  }

  Future<bool> register(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return false;
      }
      await user.sendEmailVerification();
      await _auth.signOut();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('register error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('register error: $e');
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    if (email.isEmpty) return false;
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('requestPasswordReset error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('requestPasswordReset error: $e');
      return false;
    }
  }

  Future<bool> resendVerificationEmail(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        return false;
      }
      if (user.emailVerified) {
        await _auth.signOut();
        return true;
      }
      await user.sendEmailVerification();
      await _auth.signOut();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('resendVerificationEmail error: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('resendVerificationEmail error: $e');
      return false;
    }
  }
}
