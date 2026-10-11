import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/palpay_client.dart';
import '../core/palpay_requests.dart';
import '../core/result_utils.dart';
import '../core/settings_store.dart';
import '../models/request_def.dart';
import '../widgets/account_cards.dart';
import '../widgets/transactions_table.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key, required this.requestKey});

  final String requestKey;

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  late final RequestDef _def;
  final _values = <String, String>{};
  final _controllers = <String, TextEditingController>{};
  PalpayResult? _result;
  bool _sending = false;

  SettingsStore get _settings => SettingsStore.instance;

  @override
  void initState() {
    super.initState();
    _def = PalpayRequests.find(widget.requestKey)!;
    for (final f in _def.fields) {
      final fromSetting = f.from != null ? _settings.get(f.from!) : '';
      final initial = fromSetting.isNotEmpty ? fromSetting : (f.defaultValue ?? '');
      _values[f.name] = initial;
      if (f.type == 'text' || f.type == 'textarea' || f.type == 'number' || f.type == 'date') {
        _controllers[f.name] = TextEditingController(text: initial);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final client = PalpayClient(_settings);
    final result = await client.send(_def, _values);
    if (mounted) {
      setState(() {
        _result = result;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dev = _settings.devMode;
    return Scaffold(
      appBar: AppBar(title: Text(_def.name, style: const TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dev)
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('${_def.method} ${_def.path}',
                          style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF334155))),
                    ),
                  if (dev && _def.note != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_def.note!, style: const TextStyle(color: Color(0xFF334155))),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_def.fields.isEmpty)
                    const Text('هذا الركوست بدون باراميترات (Body = {}).',
                        style: TextStyle(color: Color(0xFF64748B)))
                  else
                    for (final f in _def.fields) _field(f),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _sending ? null : _send,
                        child: _sending
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('إرسال'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_result != null) _resultCard(dev),
        ],
      ),
    );
  }

  Widget _field(FieldDef f) {
    final dir = f.dir == 'ltr' ? TextDirection.ltr : null;
    final label = '${f.label}  (${f.name})';

    switch (f.type) {
      case 'select':
        final current = _values[f.name];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: current,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true),
            items: [
              for (final e in (f.options ?? {}).entries)
                DropdownMenuItem(value: e.key, child: Text('${e.value} (${e.key})')),
            ],
            onChanged: (v) => setState(() => _values[f.name] = v ?? ''),
          ),
        );
      case 'checkbox':
        final on = _values[f.name] == '1';
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: on,
          onChanged: (v) => setState(() => _values[f.name] = v ? '1' : '0'),
          title: Text(label),
        );
      case 'date':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            readOnly: true,
            controller: _controllers[f.name],
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            onTap: () async {
              final init = DateTime.tryParse(_values[f.name] ?? '') ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: init,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                final text =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                setState(() {
                  _values[f.name] = text;
                  _controllers[f.name]!.text = text;
                });
              }
            },
          ),
        );
      case 'textarea':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _controllers[f.name],
            textDirection: dir,
            maxLines: 3,
            decoration: InputDecoration(labelText: label, isDense: true),
            onChanged: (v) => _values[f.name] = v,
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _controllers[f.name],
            textDirection: dir,
            keyboardType: f.type == 'number' ? TextInputType.number : null,
            decoration: InputDecoration(labelText: label, isDense: true),
            onChanged: (v) => _values[f.name] = v,
          ),
        );
    }
  }

  Widget _resultCard(bool dev) {
    final r = _result!;
    final rows = extractRows(r.json);
    final columns = columnsFor(rows);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('النتيجة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                _statusBadge(r),
              ],
            ),
            const SizedBox(height: 10),
            if (r.error != null)
              _alert(r.error!, const Color(0xFFFEE2E2), const Color(0xFF991B1B), ltr: true),
            if (r.saved.isNotEmpty)
              _alert(
                'تم حفظ تلقائي: ${r.saved.entries.map((e) => '${e.key}=${_short(e.value)}').join(' · ')}',
                const Color(0xFFDCFCE7),
                const Color(0xFF166534),
              ),
            const SizedBox(height: 8),
            if (rows != null && _def.key == 'getPalPayAccounts')
              AccountCards(
                rows: rows,
                onUseAsFromAccount: (acc) async {
                  await _settings.put('FROM_ACCOUNT', acc);
                  if (_settings.get('ACCOUNT').isEmpty) {
                    await _settings.put('ACCOUNT', acc);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('FROM_ACCOUNT = $acc')),
                    );
                  }
                },
              )
            else if (rows != null)
              TransactionsTable(rows: rows, columns: columns, exportName: _def.key)
            else if (dev)
              _rawJson(r)
            else if (r.saved.isEmpty && r.error == null)
              const Text('تم استلام الرد. فعّل «وضع المطور» من الإعدادات لعرض التفاصيل الخام.',
                  style: TextStyle(color: Color(0xFF64748B))),
            if (dev) ...[
              const SizedBox(height: 12),
              if (rows != null) _rawJson(r),
              const SizedBox(height: 8),
              _logBlock('Request Body', r.sentBody),
              _logBlock('Request Headers',
                  r.requestHeaders.entries.map((e) => '${e.key}: ${e.value}').join('\n')),
              _logBlock('Canonical', r.canonical),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(PalpayResult r) {
    final text = r.error != null ? 'خطأ اتصال' : '${r.status}';
    final ok = r.error == null && r.ok;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 13, color: ok ? const Color(0xFF166534) : const Color(0xFF991B1B))),
    );
  }

  Widget _alert(String text, Color bg, Color fg, {bool ltr = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          textDirection: ltr ? TextDirection.ltr : null, style: TextStyle(color: fg)),
    );
  }

  Widget _rawJson(PalpayResult r) {
    final text = r.json != null
        ? const JsonEncoder.withIndent('  ').convert(r.json)
        : r.body;
    return _logBlock('Response Body', text);
  }

  Widget _logBlock(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(
              content,
              style: const TextStyle(
                  color: Color(0xFFE6EDF3), fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }

  String _short(String v) => v.length > 40 ? '${v.substring(0, 40)}…' : v;
}
