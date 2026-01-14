import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:js' as js;

class AuthService extends ChangeNotifier {
  static const String _baseUrl = 'https://your-api.example.com';
  static const String _keyEmail = 'auth_email';
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';

  String? _email;
  String? _accessToken;
  String? _refreshToken;

  AuthService() {
    _init();
  }

  bool get isAuthenticated => _accessToken != null;
  String? get email => _email;
  String? get accessToken => _accessToken;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _email = prefs.getString(_keyEmail);
    _accessToken = prefs.getString(_keyAccessToken);
    _refreshToken = prefs.getString(_keyRefreshToken);
    if (kIsWeb && _accessToken == 'dev-access-token') {
      _email = null;
      _accessToken = null;
      _refreshToken = null;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;
    try {
      if (_baseUrl.contains('your-api.example.com')) {
        final prefs = await SharedPreferences.getInstance();
        _email = email;
        _accessToken = 'dev-access-token';
        _refreshToken = 'dev-refresh-token';
        await prefs.setString(_keyEmail, _email!);
        await prefs.setString(_keyAccessToken, _accessToken!);
        await prefs.setString(_keyRefreshToken, _refreshToken!);
        notifyListeners();
        return true;
      }

      final uri = Uri.parse('$_baseUrl/auth/login');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (res.statusCode != 200) {
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['accessToken'] as String?;
      final refresh = data['refreshToken'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      if (token == null || refresh == null || user == null) {
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      _email = user['email'] as String?;
      _accessToken = token;
      _refreshToken = refresh;
      if (_email != null) {
        await prefs.setString(_keyEmail, _email!);
      }
      await prefs.setString(_keyAccessToken, _accessToken!);
      await prefs.setString(_keyRefreshToken, _refreshToken!);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('signIn error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    _email = null;
    _accessToken = null;
    _refreshToken = null;
    notifyListeners();
  }

  Future<bool> register(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;
    try {
      if (_baseUrl.contains('your-api.example.com')) {
        return true;
      }
      final uri = Uri.parse('$_baseUrl/auth/register');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('register error: $e');
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    if (email.isEmpty) return false;
    try {
      if (_baseUrl.contains('your-api.example.com')) {
        return true;
      }
      final uri = Uri.parse('$_baseUrl/auth/forgot-password');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('requestPasswordReset error: $e');
      return false;
    }
  }

  Future<bool> startGoogleLogin() async {
    if (!kIsWeb) return false;
    try {
      final fn = js.context['hmGoogleLogin'];
      if (fn is js.JsFunction) {
        fn.apply(const []);
      } else {
        debugPrint('hmGoogleLogin is not defined on window');
        return false;
      }
      const totalMs = 6000;
      const stepMs = 200;
      final steps = totalMs ~/ stepMs;
      for (var i = 0; i < steps; i++) {
        await Future.delayed(const Duration(milliseconds: stepMs));
        final cred = js.context['hmGoogleCredential'];
        if (cred is String && cred.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          _email = 'google-user';
          _accessToken = cred;
          _refreshToken = null;
          await prefs.setString(_keyEmail, _email!);
          await prefs.setString(_keyAccessToken, _accessToken!);
          await prefs.remove(_keyRefreshToken);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('startGoogleLogin error: $e');
      return false;
    }
  }

  Future<void> startAppleLogin() async {
    if (!kIsWeb) return;
    final url = '$_baseUrl/auth/apple';
    try {
      await Future.microtask(() {
        throw UnimplementedError('Apple login flow should be implemented with real backend');
      });
    } catch (e) {
      debugPrint('startAppleLogin stub: $url');
    }
  }
}
