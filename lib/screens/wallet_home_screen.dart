import 'package:flutter/material.dart';

import '../core/accounts.dart';
import '../core/settings_store.dart';
import 'my_accounts_screen.dart';
import 'pay_friend_screen.dart';
import 'settings_screen.dart';
import 'token_screen.dart';

/// Main screen: the holder's info from getPalPayAccounts, then the two actions.
class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  AccountsResult? _accounts;
  bool _loading = false;

  SettingsStore get _settings => SettingsStore.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final accounts = await loadAccounts();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    }
  }

  Future<void> _push(Widget screen, {bool reload = false}) async {
    final changed = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (reload || changed == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PalPay'),
        actions: [
          IconButton(
            tooltip: 'تعديل التوكن',
            icon: const Icon(Icons.key),
            onPressed: () => _push(const TokenScreen(editing: true)),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings),
            onPressed: () => _push(const SettingsScreen(), reload: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _infoCard(),
            const SizedBox(height: 16),
            _actionButton(
              icon: Icons.send,
              label: 'الدفع إلى صديق',
              onTap: () => _push(const PayFriendScreen(), reload: true),
            ),
            const SizedBox(height: 12),
            _actionButton(
              icon: Icons.account_balance_wallet,
              label: 'حساباتي',
              onTap: () => _push(const MyAccountsScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard() {
    final accounts = _accounts;
    final Widget content;
    if (_loading && accounts == null) {
      content = const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    } else if (accounts?.error != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تعذّر جلب المعلومات', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
          const SizedBox(height: 6),
          Text(accounts!.error!, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.tonal(onPressed: _loading ? null : _load, child: const Text('إعادة المحاولة')),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _push(const TokenScreen(editing: true)),
                child: const Text('تعديل التوكن'),
              ),
            ],
          ),
        ],
      );
    } else {
      final rows = accounts?.rows ?? const [];
      final shekel = rows.where((r) => r['curCode']?.toString() == '376').firstOrNull;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFFCCFBF1),
                child: Icon(Icons.person, color: Color(0xFF0F766E), size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  holderName(rows) ??
                      (_settings.get('USERNAME').isEmpty ? '—' : _settings.get('USERNAME')),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 14),
          if (_settings.get('USERNAME').isNotEmpty) _row('اسم المستخدم', _settings.get('USERNAME')),
          if (_settings.get('ACCOUNT').isNotEmpty) _row('رقم الحساب', _settings.get('ACCOUNT')),
          _row('عدد الحسابات', '${rows.length}'),
          if (shekel != null) _row('رصيد الشيكل', '₪ ${_money(shekel['balance'] ?? shekel['availableBalance'])}'),
        ],
      );
    }

    return Card(child: Padding(padding: const EdgeInsets.all(16), child: content));
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Color(0xFF64748B)))),
          Expanded(
            child: Text(value, textDirection: TextDirection.ltr, textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _money(dynamic v) {
    final n = (v is num) ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    return n.toStringAsFixed(2);
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0F766E),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
