import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import 'pending_screen.dart';
import 'registration_screen.dart';
import 'requests_screen.dart';
import 'root_screen.dart';

/// Home for a regular user: registration, their own requests and the
/// pending (unsent) ones.
class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('PalPay', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4)),
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
            onPressed: () => logoutToRoot(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: staggered([
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.purpleDeep,
                child: Icon(Icons.person, color: AppColors.purpleGlow),
              ),
              title: Text(user?.name.isNotEmpty == true ? user!.name : 'أهلاً', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(user?.phone ?? '', textDirection: TextDirection.ltr, textAlign: TextAlign.right),
            ),
          ),
          const SizedBox(height: 8),
          homeActionButton(
            icon: Icons.person_add,
            label: 'التسجيل',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationScreen())),
          ),
          const SizedBox(height: 8),
          homeActionButton(
            icon: Icons.assignment,
            label: 'طلباتي',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => RequestsScreen(byPhone: user?.phone, title: 'طلباتي')),
            ),
          ),
          const SizedBox(height: 8),
          homeActionButton(
            icon: Icons.pending_actions,
            label: 'الطلبات العالقة',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PendingScreen())),
          ),
        ]),
      ),
    );
  }
}

/// Big full-width action button, same look as the wallet home actions.
Widget homeActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
  return PressScale(
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: GlowPulse(
          child: CircleAvatar(
            backgroundColor: AppColors.purple,
            child: Icon(icon, color: Colors.white),
          ),
        ),
        title: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.purpleGlow),
        onTap: onTap,
      ),
    ),
  );
}
