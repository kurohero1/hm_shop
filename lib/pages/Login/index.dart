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
  String? _info;
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
      _info = null;
    });
    final auth = context.read<AuthService>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isRegister && password.length < 6) {
      setState(() {
        _loading = false;
        _error = 'パスワードは６文字以上で設定してください。';
        _info = null;
      });
      return;
    }
    bool ok;
    if (_isRegister) {
      ok = await auth.register(email, password);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (ok) {
          _info = '登録用の確認メールを送信しました。メールを確認してからログインしてください。';
          _error = null;
        } else {
          _error = '登録に失敗しました。メールアドレスが既に使われている可能性があります。';
          _info = null;
        }
      });
    } else {
      ok = await auth.signIn(email, password);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (ok) {
          _error = null;
          _info = null;
        } else {
          _error =
              'ログインに失敗しました。メールアドレス、パスワード、メール認証状態を確認してください。';
          _info = null;
        }
      });
    }
  }

  Future<void> _requestReset() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    final email = _emailController.text.trim();
    final ok = await context.read<AuthService>().requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (ok) {
        _info = 'パスワード再設定用のリンクを送信しました。';
        _error = null;
      } else {
        _error = '再設定に失敗しました。メールアドレスをご確認ください。';
        _info = null;
      }
    });
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF7F5AF0),
                Color(0xFF2CB67D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.wb_sunny_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'さんぽ天気',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRegister ? 'はじめてのさんぽを登録' : '今日のさんぽにログイン',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _isRegister ? '新規登録' : 'ログイン',
                  key: ValueKey(_isRegister),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isRegister ? 'Welcome' : 'Welcome back',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next, // 回车跳到下一项
            style: const TextStyle(color: Colors.white),
            decoration: _buildInputDecoration('メールアドレス'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done, // 回车完成
            onSubmitted: (_) {
               if (!_loading) _submit(); // 触发提交
            },
            style: const TextStyle(color: Colors.white),
            decoration: _buildInputDecoration('パスワード'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                      ),
                    )
                  : Text(
                      _isRegister ? '登録' : 'ログイン',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _isRegister = !_isRegister;
                          _error = null;
                          _info = null;
                        });
                      },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: Text(
                  _isRegister
                      ? 'すでにアカウントをお持ちの方 ログイン'
                      : 'アカウントをお持ちでない方 新規登録',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _requestReset,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: const Text(
                  'パスワードをお忘れの方',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (_info != null) ...[
            const SizedBox(height: 10),
            Text(
              _info!,
              style: const TextStyle(
                color: Color(0xFFB3FFB3),
                fontSize: 12,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFFB3B3),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
                child: TextButton(
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
                            if (ok) {
                              _info = '確認メールを再送しました。メールをご確認ください。';
                              _error = null;
                              _resendCooldown = 60;
                            } else {
                              _error =
                                  '再送に失敗しました。メールアドレス、パスワードをご確認ください。';
                              _info = null;
                              _resendCooldown = 0;
                            }
                          });
                          _resendTimer?.cancel();
                          if (ok) {
                            _resendTimer =
                                Timer.periodic(const Duration(seconds: 1), (t) {
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
                          }
                        },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
                child: Text(
                  _resendCooldown > 0 ? '確認メールを再送（$_resendCooldown 秒）' : '確認メールを再送',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF020617),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -80,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7F5AF0).withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2CB67D).withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 32),
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildFormCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
