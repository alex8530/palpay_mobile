import 'package:flutter/material.dart';

import '../core/accounts.dart';
import '../core/palpay_client.dart';
import '../core/result_utils.dart';
import '../core/settings_store.dart';

enum _Step { mobile, amount, confirm, done }

/// Pay to a friend: checkPayToFriendAccount → prePayToFriendTransfer →
/// confirmPayToFriendTransfer. The user only types the mobile and the amount;
/// everything else is chained through the registry's save rules.
class PayFriendScreen extends StatefulWidget {
  const PayFriendScreen({super.key});

  @override
  State<PayFriendScreen> createState() => _PayFriendScreenState();
}

class _PayFriendScreenState extends State<PayFriendScreen> {
  final _mobile = TextEditingController();
  final _amount = TextEditingController();
  _Step _step = _Step.mobile;
  bool _busy = false;
  String? _error;
  String? _doneMessage;
  PalpayResult? _last;

  SettingsStore get _settings => SettingsStore.instance;
  PalpayClient get _client => PalpayClient(_settings);

  @override
  void dispose() {
    _mobile.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Step 1: look up the recipient by mobile.
  Future<void> _check() async {
    final mobile = _mobile.text.trim();
    if (mobile.isEmpty) {
      setState(() => _error = 'اكتب رقم الجوال.');
      return;
    }
    await _run(() async {
      // Clear values from any previous transfer so stale ones are never reused.
      await _settings.putMany({
        'TO_NAME': '',
        'DEST_CODE': '',
        'TRANSFER_ID': '',
        'TRANSFER_TOKEN': '',
        'TR_REFNUM': '',
      });
      final r = await _client.sendKey('checkPayToFriendAccount', {'mobileNumber': mobile});
      _last = r;
      if (!r.ok) {
        _error = errorMessage(r);
      } else if (_settings.get('TO_NAME').isEmpty) {
        _error = 'ما لقيت حساب PalPay على هالرقم.';
      } else {
        _step = _Step.amount;
      }
    });
  }

  /// Step 2: prepare the transfer with the amount.
  Future<void> _prepare() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'اكتب مبلغ صحيح.');
      return;
    }
    await _run(() async {
      if (_settings.get('FROM_ACCOUNT').isEmpty) {
        final accounts = await loadAccounts();
        if (accounts.error != null || _settings.get('FROM_ACCOUNT').isEmpty) {
          _error = accounts.error ?? 'ما لقيت حساب شيكل تحوّل منه.';
          return;
        }
      }
      await _settings.putMany({'TRANSFER_ID': '', 'TRANSFER_TOKEN': '', 'TR_REFNUM': ''});
      final r = await _client.sendKey('prePayToFriendTransfer', {
        'mobileNumber': _mobile.text.trim(),
        'amount': amount.toString(),
      });
      _last = r;
      if (!r.ok) {
        _error = errorMessage(r);
      } else if (_settings.get('TRANSFER_ID').isEmpty) {
        _error = 'الخادم ما رجّع transferId. ${errorMessage(r)}';
      } else {
        _step = _Step.confirm;
      }
    });
  }

  /// Step 3: confirm — this actually sends the money.
  Future<void> _confirm() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد التحويل'),
        content: Text('رح يتم تحويل ${_amount.text.trim()} ₪ إلى ${_settings.get('TO_NAME')}. متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (sure != true) {
      return;
    }
    await _run(() async {
      final r = await _client.sendKey('confirmPayToFriendTransfer', {'pin': _settings.get('PAY_PIN')});
      _last = r;
      if (!r.ok) {
        _error = errorMessage(r);
        return;
      }
      final json = r.json;
      final message = json is Map ? (json['message'] ?? json['description'])?.toString() : null;
      _doneMessage = message;
      _step = _Step.done;
    });
  }

  void _restart() {
    setState(() {
      _step = _Step.mobile;
      _error = null;
      _doneMessage = null;
      _last = null;
      _amount.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدفع إلى صديق')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_step == _Step.done) _doneCard() else _formCard(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFEE2E2),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B))),
              ),
            ),
          ],
          if (_settings.devMode && _last != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(
                  'HTTP ${_last!.status}\n${_last!.body}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _mobile,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'جوال المستلم', prefixIcon: Icon(Icons.phone)),
              // Changing the mobile invalidates any lookup done for the old one.
              onChanged: (_) {
                if (_step != _Step.mobile) {
                  setState(() => _step = _Step.mobile);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_step == _Step.mobile)
              _button('تحقق', _check)
            else ...[
              _info('المستلم', _settings.get('TO_NAME')),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                enabled: !_busy && _step == _Step.amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'المبلغ (₪)', prefixIcon: Icon(Icons.payments)),
              ),
              const SizedBox(height: 12),
              if (_step == _Step.amount)
                _button('متابعة', _prepare)
              else ...[
                _info('من حساب', _settings.get('FROM_ACCOUNT')),
                _info('المبلغ', '${_amount.text.trim()} ₪'),
                const SizedBox(height: 12),
                _button('تأكيد وإرسال المبلغ', _confirm),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : () => setState(() => _step = _Step.amount),
                  child: const Text('تعديل المبلغ'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _doneCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 64),
            const SizedBox(height: 12),
            const Text('تم التحويل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${_amount.text.trim()} ₪ إلى ${_settings.get('TO_NAME')}'),
            if (_doneMessage != null && _doneMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_doneMessage!, style: const TextStyle(color: Color(0xFF64748B))),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: _restart, child: const Text('تحويل جديد'))),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('الرئيسية')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, Future<void> Function() onPressed) {
    return FilledButton(
      onPressed: _busy ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
