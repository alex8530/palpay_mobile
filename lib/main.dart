import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_config.dart';
import 'core/auth_service.dart';
import 'core/settings_store.dart';
import 'firebase_options.dart';
import 'screens/root_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_gate.dart';
import 'widgets/fx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await SettingsStore.instance.load();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(PalpayApp(startupError: '$e'));
    return;
  }
  await AuthService.instance.restore();
  AppConfig.instance.start();
  runApp(const PalpayApp());
}

class PalpayApp extends StatelessWidget {
  const PalpayApp({super.key, this.startupError});

  /// Set when Firebase could not start; the app then only shows this error.
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PalPay',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      // One animated background behind every route; the gate applies the
      // admin's on/off switch and message (config/app).
      builder: (context, child) => HauntedBackground(
        child: AppGate(child: child ?? const SizedBox.shrink()),
      ),
      home: startupError == null
          ? const RootScreen()
          : Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('تعذّر تشغيل Firebase:\n$startupError', textAlign: TextAlign.center),
                ),
              ),
            ),
    );
  }
}
