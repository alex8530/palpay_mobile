import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/accounts.dart';
import '../core/result_utils.dart';
import '../core/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import '../widgets/transaction_card.dart';
import 'my_accounts_screen.dart';
import 'pay_friend_screen.dart';
import 'settings_screen.dart';
import 'token_screen.dart';
import 'transactions_screen.dart';

/// Main screen: holder info, balances, this month's totals and the latest
/// transactions, plus the two actions.
class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  static const _recentCount = 5;
  static const _currencyNames = {'376': 'شيكل', '840': 'دولار', '400': 'دينار أردني'};

  RowsResult? _accounts;
  RowsResult? _recent;
  RowsResult? _month;
  DateTime? _updatedAt;
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
    RowsResult? recent;
    RowsResult? month;
    // The statement calls need FROM_ACCOUNT, which getPalPayAccounts saves.
    if (accounts.error == null) {
      final now = DateTime.now();
      final results = await Future.wait([
        loadRows('ministatement'),
        loadRows('transfersHistory', {
          'from': _ymd(DateTime(now.year, now.month, 1)),
          'to': _ymd(now),
          'type': '0',
        }),
      ]);
      recent = results[0];
      month = results[1];
    }
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _recent = recent;
        _month = month;
        _updatedAt = DateTime.now();
        _loading = false;
      });
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _push(Widget screen, {bool reload = false}) async {
    final changed = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (reload || changed == true) {
      _load();
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ $label.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('PalPay', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4)),
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
          children: staggered([
            if (accounts == null)
              const Card(child: LoaderBox())
            else if (accounts.error != null)
              _errorCard(accounts)
            else ...[
              _infoCard(accounts.rows),
              _balancesCard(accounts.rows),
            ],
            const SizedBox(height: 8),
            _actionButton(
              icon: Icons.send,
              label: 'الدفع إلى صديق',
              onTap: () => _push(const PayFriendScreen(), reload: true),
            ),
            const SizedBox(height: 8),
            _actionButton(
              icon: Icons.account_balance_wallet,
              label: 'حساباتي',
              onTap: () => _push(const MyAccountsScreen()),
            ),
            if (accounts?.error == null && accounts != null) ...[
              const SizedBox(height: 8),
              _monthCard(),
              _recentCard(),
            ],
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- info

  Widget _errorCard(RowsResult accounts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    accounts.unauthorized ? 'الخادم رفض التوكن' : 'تعذّر جلب المعلومات',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.blood),
                  ),
                ),
                _tokenChip(accounts),
              ],
            ),
            const SizedBox(height: 6),
            Text(accounts.error!, style: const TextStyle(fontSize: 13)),
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
        ),
      ),
    );
  }

  Widget _infoCard(List<Map<String, dynamic>> rows) {
    final name = holderName(rows) ?? (_settings.get('USERNAME').isEmpty ? '—' : _settings.get('USERNAME'));
    final nick = firstField(rows, const ['nickName']);
    final iban = firstField(rows, const ['iban']);
    final points = firstField(rows, const ['availablePoints']);
    final account = _settings.get('ACCOUNT');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const GlowPulse(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.purpleDeep,
                    child: Icon(Icons.person, color: AppColors.purpleGlow, size: 32),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (nick != null && nick != name)
                        Text(nick, style: const TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (_loading)
                  const EyeLoader(size: 26)
                else
                  _tokenChip(_accounts!),
              ],
            ),
            const SizedBox(height: 14),
            if (_settings.get('USERNAME').isNotEmpty) _row('اسم المستخدم', _settings.get('USERNAME')),
            if (account.isNotEmpty) _row('رقم الحساب', account, copyLabel: 'رقم الحساب'),
            if (iban != null) _row('IBAN', iban, copyLabel: 'الـ IBAN'),
            if (points != null) _row('النقاط', points),
            if (_updatedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'آخر تحديث: ${_updatedAt!.hour.toString().padLeft(2, '0')}:${_updatedAt!.minute.toString().padLeft(2, '0')}  ·  اسحب لتحت للتحديث',
                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tokenChip(RowsResult accounts) {
    final ok = accounts.error == null;
    final (text, bg, fg) = ok
        ? ('التوكن فعّال', AppColors.greenBg, AppColors.green)
        : accounts.unauthorized
            ? ('التوكن مرفوض', AppColors.bloodBg, AppColors.blood)
            : ('غير متصل', AppColors.amberBg, AppColors.amber);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }

  Widget _row(String label, String value, {String? copyLabel}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
          Expanded(
            child: SelectableText(value,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (copyLabel != null)
            IconButton(
              tooltip: 'نسخ',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () => _copy(copyLabel, value),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ balances

  Widget _balancesCard(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الأرصدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            for (final acc in rows) _balanceRow(acc),
          ],
        ),
      ),
    );
  }

  Widget _balanceRow(Map<String, dynamic> acc) {
    final code = acc['curCode']?.toString() ?? '';
    final symbol = TxColumns.currencySymbolFor(code);
    num? toNum(dynamic v) => v is num ? v : num.tryParse(v?.toString() ?? '');
    final balance = toNum(acc['balance']) ?? toNum(acc['availableBalance']) ?? 0;
    final available = toNum(acc['availableBalance']);
    final showAvailable = available != null && acc['balance'] != null && available != balance;
    final isDefault = acc['defaultAccount'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDefault ? AppColors.purpleTint : AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDefault ? AppColors.purpleDeep : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_currencyNames[code] ?? code, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (isDefault) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, size: 14, color: AppColors.purple),
                    ],
                  ],
                ),
                if (showAvailable)
                  Text('المتاح: ${formatMoney(available)} $symbol',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          CountUp(
            value: balance,
            format: (v) => '${v < 0 ? '-' : ''}${formatMoney(v)} $symbol',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
              shadows: [Shadow(color: AppColors.purple, blurRadius: 18)],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- this month

  Widget _monthCard() {
    final month = _month;
    final Widget body;
    if (month == null) {
      body = const LoaderBox();
    } else if (month.error != null) {
      body = Text(month.error!, style: const TextStyle(fontSize: 13, color: AppColors.blood));
    } else {
      final cols = TxColumns(month.rows, columnsFor(month.rows));
      num incoming = 0, outgoing = 0, unknown = 0;
      for (final row in month.rows) {
        final a = (cols.amountOf(row) ?? 0).abs();
        switch (cols.directionOf(row)) {
          case 1:
            incoming += a;
          case -1:
            outgoing += a;
          default:
            unknown += a;
        }
      }
      body = Row(
        children: [
          if (incoming > 0 || outgoing > 0) ...[
            _stat('وارد', incoming, (v) => '+${formatMoney(v)}', AppColors.green),
            _stat('صادر', outgoing, (v) => '-${formatMoney(v)}', AppColors.blood),
          ],
          if (unknown > 0 || (incoming == 0 && outgoing == 0))
            _stat('المجموع', unknown, formatMoney, AppColors.text),
          _stat('الحركات', month.rows.length, (v) => '${v.round()}', AppColors.text),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هالشهر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            body,
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, num value, String Function(num) format, Color color) {
    return Expanded(
      child: Column(
        children: [
          CountUp(
            value: value,
            format: format,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
              shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- recent

  Widget _recentCard() {
    final recent = _recent;
    final List<Widget> body;
    if (recent == null) {
      body = [const LoaderBox()];
    } else if (recent.error != null) {
      body = [Text(recent.error!, style: const TextStyle(fontSize: 13, color: AppColors.blood))];
    } else if (recent.rows.isEmpty) {
      body = [const Text('ما في حركات.', style: TextStyle(color: AppColors.textMuted))];
    } else {
      final cols = TxColumns(recent.rows, columnsFor(recent.rows));
      final sorted = [...recent.rows];
      if (cols.date != null) {
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        sorted.sort((a, b) => (cols.dateOf(b) ?? epoch).compareTo(cols.dateOf(a) ?? epoch));
      }
      body = [
        ...staggered([
          for (final row in sorted.take(_recentCount)) TransactionCard(key: ObjectKey(row), row: row, cols: cols),
        ], step: 110),
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('آخر الحركات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                TextButton(
                  onPressed: () => _push(const TransactionsScreen(title: 'كل الحركات')),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...body,
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
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
}
