import 'package:flutter/material.dart';

import '../core/palpay_requests.dart';
import '../core/settings_store.dart';
import '../models/request_def.dart';
import 'request_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _statusKeys = {
    'USERNAME': 'المستخدم',
    'SALT': 'SALT',
    'ACCESS_TOKEN': 'التوكن',
    'ACCOUNT': 'الحساب',
    'FROM_ACCOUNT': 'حساب الشيكل',
  };

  @override
  Widget build(BuildContext context) {
    final settings = SettingsStore.instance;
    final grouped = PalpayRequests.grouped();

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('PalPay API Console'),
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
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الحالة الحالية',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _statusKeys.entries.map((e) {
                          final on = settings.get(e.key).isNotEmpty;
                          return Chip(
                            label: Text('${e.value}: ${on ? '✓' : '—'}'),
                            backgroundColor:
                                on ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              color: on ? const Color(0xFF166534) : const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              for (final entry in grouped.entries) _group(context, entry.key, entry.value, settings),
            ],
          ),
        );
      },
    );
  }

  Widget _group(BuildContext context, String title, List<RequestDef> defs, SettingsStore settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            for (final def in defs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RequestScreen(requestKey: def.key)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(def.method,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                        const SizedBox(height: 2),
                        Text(def.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (settings.devMode) ...[
                          const SizedBox(height: 4),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(def.path,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B), fontFamily: 'monospace')),
                          ),
                        ],
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
