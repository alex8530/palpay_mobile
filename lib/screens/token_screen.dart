import 'package:flutter/material.dart';

import '../core/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import 'settings_screen.dart';
import 'wallet_home_screen.dart';

/// Manual token entry. The token is stored in ACCESS_TOKEN and kept until the
/// user edits it here again.
class TokenScreen extends StatefulWidget {
  const TokenScreen({super.key, this.editing = false});

  /// true when opened from the home screen to change an existing token.
  final bool editing;

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: SettingsStore.instance.get('ACCESS_TOKEN'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _controller.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب التوكن أولاً.')),
      );
      return;
    }
    await SettingsStore.instance.put('ACCESS_TOKEN', token);
    if (!mounted) {
      return;
    }
    if (widget.editing) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WalletHomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FlickerText(widget.editing ? 'تعديل التوكن' : 'PalPay',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3)),
        actions: [
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: staggered([
          const SizedBox(height: 40),
          const Center(
            child: GlowPulse(
              intensity: 1.4,
              child: CircleAvatar(
                radius: 46,
                backgroundColor: AppColors.purpleDeep,
                child: Icon(Icons.key, size: 46, color: AppColors.purpleGlow),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Center(
            child: FlickerText(
              'أدخل التوكن',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'بيتحفظ على الجوال وبيضل موجود لحد ما تعدّله.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            textDirection: TextDirection.ltr,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'التوكن (ACCESS_TOKEN)'),
          ),
          const SizedBox(height: 16),
          PressScale(
            child: GlowPulse(
              radius: 14,
              child: FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('حفظ ومتابعة'),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
