import 'package:flutter/material.dart';

import '../core/settings_store.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Map<String, Map<String, String>> _groups = {
    'الهوية والتوقيع': {
      'BASE_URL': 'عنوان الخادم',
      'USERNAME': 'اسم المستخدم',
      'PASSWORD': 'كلمة السر الحالية',
      'NEW_PASSWORD': 'كلمة السر الجديدة',
      'SALT': 'SALT (passwordSalt)',
      'ACCESS_TOKEN': 'التوكن / كود التفعيل',
      'ANDROID_ID': 'ANDROID_ID',
      'COUNTER': 'COUNTER',
      'PAY_PIN': 'PIN التحويل (اختياري)',
    },
    'الهيدرز الثابتة': {
      'H_CONTENT_TYPE': 'Content-Type',
      'H_X_PALPAY_SOURCE': 'X-PALPAY-Source',
      'H_X_HISABI_VER': 'X-HISABI-VER',
      'H_X_LOGIN_MODE': 'X-LOGIN-MODE',
      'H_ACCEPT_LANGUAGE': 'Accept-Language',
    },
    'قيم تُحفظ تلقائياً من الريسبونس': {
      'ACCOUNT': 'رقم الحساب (ACCOUNT)',
      'FROM_ACCOUNT': 'حساب الشيكل (FROM_ACCOUNT)',
      'REFNUM': 'REFNUM',
      'TO_NAME': 'اسم المستلم (TO_NAME)',
      'DEST_CODE': 'DEST_CODE',
      'TRANSFER_ID': 'TRANSFER_ID',
      'TRANSFER_TOKEN': 'TRANSFER_TOKEN',
      'TR_REFNUM': 'TR_REFNUM',
    },
  };

  late final Map<String, TextEditingController> _controllers;
  late bool _devMode;

  @override
  void initState() {
    super.initState();
    final s = SettingsStore.instance;
    _devMode = s.devMode;
    _controllers = {
      for (final group in _groups.values)
        for (final key in group.keys) key: TextEditingController(text: s.get(key)),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final entries = <String, String?>{
      for (final e in _controllers.entries) e.key: e.value.text,
      'DEV_MODE': _devMode ? '1' : '0',
    };
    await SettingsStore.instance.putMany(entries);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والهيدرز')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: SwitchListTile(
              value: _devMode,
              onChanged: (v) => setState(() => _devMode = v),
              title: const Text('وضع المطور'),
              subtitle: const Text(
                'إظهار الرابط (URL) وسجل الطلب (الهيدرز/الـ canonical) والـ response الخام في كل صفحة.',
              ),
            ),
          ),
          for (final group in _groups.entries) _groupCard(group.key, group.value),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: const Text('حفظ الإعدادات'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.terminal),
            label: const Text('الكونسول (كل الركوستات)'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _groupCard(String title, Map<String, String> keys) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            for (final entry in keys.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _controllers[entry.key],
                  textDirection: TextDirection.ltr,
                  obscureText: const {'PASSWORD', 'NEW_PASSWORD', 'PAY_PIN'}.contains(entry.key),
                  decoration: InputDecoration(
                    labelText: '${entry.value}  (${entry.key})',
                    isDense: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
