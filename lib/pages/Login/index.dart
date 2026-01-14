import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hm_shop/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _isRegister = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    bool ok;
    if (_isRegister) {
      ok = await auth.register(email, password);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ok
            ? '登録用の確認メールを送信しました。メールを確認してからログインしてください'
            : '登録に失敗しました。メールアドレスが既に使われている可能性があります';
      });
    } else {
      ok = await auth.signIn(email, password);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ok
            ? null
            : 'ログインに失敗しました。メールアドレス・パスワード、メール認証状態を確認してください';
      });
    }
  }

  Future<void> _requestReset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final email = _emailController.text.trim();
    final ok = await context.read<AuthService>().requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = ok
          ? 'パスワード再設定用のリンクを送信しました'
          : '再設定に失敗しました。メールアドレスをご確認ください';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegister ? "新規登録" : "ログイン"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'パスワード',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(_isRegister ? '登録' : 'ログイン'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _isRegister = !_isRegister;
                            _error = null;
                          });
                        },
                  child: Text(
                    _isRegister
                        ? 'すでにアカウントをお持ちの方 ログイン'
                        : 'アカウントをお持ちでない方 新規登録',
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _requestReset,
                  child: const Text('パスワードをお忘れの方'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: (_loading || _resendCooldown > 0)
                    ? null
                    : () async {
                        setState(() {
                          _loading = true;
                        });
                        final ok = await context.read<AuthService>().resendVerificationEmail(
                              _emailController.text.trim(),
                              _passwordController.text,
                            );
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                          _error = ok
                              ? '確認メールを再送しました。メールをご確認ください'
                              : '再送に失敗しました。メールアドレス・パスワードをご確認ください';
                          _resendCooldown = 60;
                        });
                        _resendTimer?.cancel();
                        _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
                          if (!mounted) {
                            t.cancel();
                            return;
                          }
                          setState(() {
                            _resendCooldown -= 1;
                            if (_resendCooldown <= 0) {
                              t.cancel();
                              _resendCooldown = 0;
                            }
                          });
                        });
                      },
                child: Text(
                  _resendCooldown > 0 ? '確認メールを再送（$_resendCooldown 秒）' : '確認メールを再送',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
