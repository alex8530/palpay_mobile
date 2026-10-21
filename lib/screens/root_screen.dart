import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../core/settings_store.dart';
import 'login_screen.dart';
import 'token_screen.dart';
import 'user_home_screen.dart';
import 'wallet_home_screen.dart';

/// Picks the first screen from the login state: login, the full app for the
/// admin, or the reduced home for a regular user. Rebuilds on login/logout
/// and when the admin changes someone's role.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final user = AuthService.instance.user;
        if (user == null) {
          return const LoginScreen();
        }
        if (!user.isAdmin) {
          return const UserHomeScreen();
        }
        // The token is entered once and kept; skip straight home when present.
        return SettingsStore.instance.get('ACCESS_TOKEN').isEmpty ? const TokenScreen() : const WalletHomeScreen();
      },
    );
  }
}

/// Signs out and drops every open screen, back to the login.
Future<void> logoutToRoot(BuildContext context) async {
  final navigator = Navigator.of(context);
  await AuthService.instance.logout();
  navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const RootScreen()), (_) => false);
}
