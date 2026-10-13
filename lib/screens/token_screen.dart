import 'package:flutter/material.dart';

import '../core/settings_store.dart';
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
        title: Text(widget.editing ? 'تعديل التوكن' : 'PalPay'),
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
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.key, size: 56, color: Color(0xFF0F766E)),
          const SizedBox(height: 16),
          const Text(
            'أدخل التوكن',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'بيتحفظ على الجوال وبيضل موجود لحد ما تعدّله.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
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
          FilledButton(
            onPressed: _save,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('حفظ ومتابعة'),
            ),
          ),
        ],
      ),
    );
  }
}
