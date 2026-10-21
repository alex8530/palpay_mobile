import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';

/// Phone + password login. Accounts are created by the admin (Users screen or
/// the Firebase console); on success [RootScreen] switches to the right home.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AuthService.instance.login(_phone.text, _password.text);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('PalPay', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3)),
      ),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: staggered([
            const SizedBox(height: 40),
            const Center(
              child: GlowPulse(
                intensity: 1.4,
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.purpleDeep,
                  child: Icon(Icons.lock_person, size: 46, color: AppColors.purpleGlow),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Center(
              child: FlickerText('تسجيل الدخول', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phone,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'رقم الجوال', prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hide,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _busy ? null : _login(),
              decoration: InputDecoration(
                labelText: 'كلمة السر',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.blood)),
            ],
            const SizedBox(height: 16),
            PressScale(
              child: GlowPulse(
                radius: 14,
                child: FilledButton(
                  onPressed: _busy ? null : _login,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: EyeLoader(size: 20))
                        : const Text('دخول'),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
