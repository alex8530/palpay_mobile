import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/accounts.dart';
import '../core/palpay_client.dart';
import '../core/result_utils.dart';
import '../core/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';

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
      appBar: AppBar(
        title: const FlickerText('الدفع إلى صديق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child),
            ),
            child: _step == _Step.done
                ? KeyedSubtree(key: const ValueKey('done'), child: _doneCard())
                : KeyedSubtree(key: const ValueKey('form'), child: FadeSlideIn(child: _formCard())),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _Shake(
              key: ValueKey(_error),
              child: Card(
                color: AppColors.bloodBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.blood),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.blood),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.blood))),
                    ],
                  ),
                ),
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
        child: AnimatedSize(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
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
                FadeSlideIn(
                  key: const ValueKey('recipient'),
                  child: _recipientBadge(_settings.get('TO_NAME')),
                ),
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
                  FadeSlideIn(
                    key: const ValueKey('summary'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _info('من حساب', _settings.get('FROM_ACCOUNT')),
                        _info('المبلغ', '${_amount.text.trim()} ₪'),
                      ],
                    ),
                  ),
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
      ),
    );
  }

  Widget _recipientBadge(String name) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.purpleTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purpleDeep),
      ),
      child: Row(
        children: [
          const GlowPulse(
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.purpleDeep,
              child: Icon(Icons.person, size: 20, color: AppColors.purpleGlow),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المستلم', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Icon(Icons.verified, color: AppColors.green),
        ],
      ),
    );
  }

  Widget _doneCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: const GlowPulse(
                color: AppColors.green,
                intensity: 1.3,
                child: Icon(Icons.check_circle, color: AppColors.green, size: 84),
              ),
            ),
            const SizedBox(height: 16),
            const FlickerText('تم التحويل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            CountUp(
              value: double.tryParse(_amount.text.trim()) ?? 0,
              format: (v) => '${v.toStringAsFixed(2)} ₪',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.green,
                shadows: [Shadow(color: AppColors.green, blurRadius: 20)],
              ),
            ),
            const SizedBox(height: 4),
            Text('إلى ${_settings.get('TO_NAME')}', style: const TextStyle(color: AppColors.textMuted)),
            if (_doneMessage != null && _doneMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_doneMessage!, style: const TextStyle(color: AppColors.textMuted)),
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
    return PressScale(
      child: GlowPulse(
        radius: 14,
        intensity: _busy ? 0.3 : 1,
        child: FilledButton(
          onPressed: _busy ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _busy ? const EyeLoader(size: 24) : Text(label),
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// Shakes its child horizontally once when first shown (used for errors).
class _Shake extends StatelessWidget {
  const _Shake({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      builder: (_, v, c) => Transform.translate(
        offset: Offset(math.sin(v * math.pi * 6) * 10 * (1 - v), 0),
        child: c,
      ),
      child: child,
    );
  }
}
