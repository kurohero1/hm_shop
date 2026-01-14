import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hm_shop/pages/Main/index.dart';
import 'package:hm_shop/pages/Login/index.dart';
import 'package:hm_shop/services/step_service.dart';
import 'package:hm_shop/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: webFirebaseOptions,
    );
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StepService()),
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, st) {
    debugPrint('Firebase initializeApp error: $e');
    debugPrint(st.toString());
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Firebase 初始化失败: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'さんぽアプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2FA84F)),
        useMaterial3: true,
      ),
      // 添加本地化支持
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'), // 日语
        Locale('en', 'US'), // 英语
      ],
      home: auth.isAuthenticated ? const MainPage() : const LoginPage(),
    );
  }
}
