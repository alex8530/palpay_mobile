import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders getPalPayAccounts rows as per-account cards, mirroring the web view.
class AccountCards extends StatelessWidget {
  const AccountCards({
    super.key,
    required this.rows,
    this.onUseAsFromAccount,
    this.title = 'الحسابات',
  });

  final List<Map<String, dynamic>> rows;
  /// When null, the "use as FROM_ACCOUNT" button is hidden.
  final void Function(String accountNumber)? onUseAsFromAccount;
  final String title;

  static const _currencies = {
    '376': ['شيكل', '₪'],
    '840': ['دولار', '\$'],
    '400': ['دينار أردني', 'د.أ'],
  };

  List<String> _cur(dynamic code) {
    return _currencies[code.toString()] ?? [code.toString(), ''];
  }

  String _money(dynamic v) {
    final n = (v is num) ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    final fixed = n.toStringAsFixed(2);
    // add thousands separators
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title (${rows.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        for (final acc in rows) _card(context, acc),
      ],
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> acc) {
    final c = _cur(acc['curCode'] ?? '');
    final isDefault = acc['defaultAccount'] == true;
    final balance = acc['balance'] ?? acc['availableBalance'] ?? 0;
    final showAvail = acc['availableBalance'] != null &&
        acc['balance'] != null &&
        acc['availableBalance'].toString() != acc['balance'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDefault ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c[0],
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('افتراضي',
                      style: TextStyle(fontSize: 12, color: Color(0xFF166534))),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${c[1]} ${_money(balance)}',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ),
          ),
          if (showAvail)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('المتاح: ${c[1]} ${_money(acc['availableBalance'])}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              ),
            ),
          const SizedBox(height: 8),
          _accountNumber(context, acc['accountNumber']?.toString() ?? ''),
          if ((acc['accountName'] ?? '').toString().isNotEmpty) _meta('الاسم', acc['accountName'].toString()),
          if ((acc['holderName'] ?? '').toString().isNotEmpty) _meta('صاحب الحساب', acc['holderName'].toString()),
          if ((acc['nickName'] ?? '').toString().isNotEmpty) _meta('اللقب', acc['nickName'].toString()),
          if ((acc['iban'] ?? '').toString().isNotEmpty) _meta('IBAN', acc['iban'].toString(), ltr: true),
          if (acc['availablePoints'] != null) _meta('النقاط', acc['availablePoints'].toString(), ltr: true),
          if (onUseAsFromAccount != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onUseAsFromAccount!(acc['accountNumber']?.toString() ?? ''),
                child: const Text('اعتماد كـ FROM_ACCOUNT'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Account number row: selectable, with a copy-to-clipboard button.
  Widget _accountNumber(BuildContext context, String number) {
    return Row(
      children: [
        const SizedBox(
          width: 110,
          child: Text('رقم الحساب', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: SelectableText(
            number.isEmpty ? '—' : number,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ),
        if (number.isNotEmpty)
          IconButton(
            tooltip: 'نسخ',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: number));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ رقم الحساب.')),
                );
              }
            },
          ),
      ],
    );
  }

  Widget _meta(String label, String value, {bool ltr = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
