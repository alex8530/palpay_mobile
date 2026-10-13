import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/settings_store.dart';
import 'screens/token_screen.dart';
import 'screens/wallet_home_screen.dart';
import 'theme/app_theme.dart';
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
  runApp(const PalpayApp());
}

class PalpayApp extends StatelessWidget {
  const PalpayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PalPay',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(),
      // One animated background behind every route.
      builder: (context, child) => HauntedBackground(child: child ?? const SizedBox.shrink()),
      // The token is entered once and kept; skip straight home when present.
      home: SettingsStore.instance.get('ACCESS_TOKEN').isEmpty
          ? const TokenScreen()
          : const WalletHomeScreen(),
    );
  }
}
