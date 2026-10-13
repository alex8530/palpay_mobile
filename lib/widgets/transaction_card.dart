import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fx.dart';

/// Which response fields play which role in a transaction, guessed from the
/// column names since the exact PalPay field names vary per request.
class TxColumns {
  TxColumns(this.rows, this.columns) {
    date = _detectDateColumn();
    amount = _find([r'^amount$', r'amount', r'amt', r'^value$', r'total']);
    title = _find([
      r'desc',
      r'details',
      r'narrat',
      r'remark',
      r'purpose',
      r'note',
      r'trans.*type',
      r'type.*(name|desc)',
      r'^type$'
    ]);
    party = _find([r'(to|from|benef|receiver|sender|client|customer|holder).*name', r'name']);
    ref = _find([r'ref', r'transfer.*id', r'trans.*id', r'^id$']);
    currency = _find([r'cur']);
    direction = _find([r'debit.*credit', r'^(dr|cr)', r'direction', r'in.?out', r'sign']);
  }

  final List<Map<String, dynamic>> rows;
  final List<String> columns;
  String? date;
  String? amount;
  String? title;
  String? party;
  String? ref;
  String? currency;
  String? direction;

  /// Columns already shown on the card face.
  Set<String?> get summary => {amount, title, party, ref, currency, direction, date};

  static String cellText(Map<String, dynamic> row, String col) {
    final v = row[col];
    if (v == null) return '';
    if (v is String || v is num || v is bool) return v.toString();
    return jsonEncode(v);
  }

  static DateTime? parseDate(String t) {
    final s = t.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String? _detectDateColumn() {
    for (final col in columns) {
      var filled = 0, dated = 0;
      for (final row in rows) {
        final txt = cellText(row, col).trim();
        if (txt.isEmpty) continue;
        filled++;
        if (RegExp(r'\d{4}').hasMatch(txt) && RegExp(r'[-/:]').hasMatch(txt) && parseDate(txt) != null) {
          dated++;
        }
      }
      if (filled >= 1 && dated / filled >= 0.7) {
        return col;
      }
    }
    return null;
  }

  /// First column whose name matches one of [patterns] (in priority order)
  /// and has at least one non-empty value.
  String? _find(List<String> patterns) {
    for (final pattern in patterns) {
      final re = RegExp(pattern, caseSensitive: false);
      for (final col in columns) {
        if (re.hasMatch(col) && rows.any((r) => cellText(r, col).trim().isNotEmpty)) {
          return col;
        }
      }
    }
    return null;
  }

  num? amountOf(Map<String, dynamic> row) {
    if (amount == null) return null;
    return num.tryParse(cellText(row, amount!).replaceAll(RegExp(r'[,\s]'), ''));
  }

  DateTime? dateOf(Map<String, dynamic> row) => date == null ? null : parseDate(cellText(row, date!));

  /// -1 outgoing, 1 incoming, 0 unknown. A negative amount wins; otherwise a
  /// debit/credit style column decides.
  int directionOf(Map<String, dynamic> row) {
    final a = amountOf(row);
    if (a != null && a < 0) return -1;
    if (direction == null) return 0;
    final v = cellText(row, direction!).trim().toLowerCase();
    if (v.startsWith('d') || v == '-' || v == 'out' || v == '-1') return -1;
    if (v.startsWith('c') || v == '+' || v == 'in' || v == '1') return 1;
    return 0;
  }

  String currencySymbol(Map<String, dynamic> row) {
    if (currency == null) return '';
    return currencySymbolFor(cellText(row, currency!).trim());
  }

  static String currencySymbolFor(String code) {
    const symbols = {'376': '₪', 'ILS': '₪', '840': '\$', 'USD': '\$', '400': 'د.أ', 'JOD': 'د.أ'};
    return symbols[code.toUpperCase()] ?? code;
  }
}

/// 1,234.50 style formatting (absolute value).
String formatMoney(num n) {
  final parts = n.abs().toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '$intPart.${parts[1]}';
}

/// One transaction: description + coloured amount on top, party, date and
/// reference below; tap to show every field.
class TransactionCard extends StatefulWidget {
  const TransactionCard({super.key, required this.row, required this.cols});

  final Map<String, dynamic> row;
  final TxColumns cols;

  @override
  State<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<TransactionCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final c = widget.cols;
    String text(String? col) => col == null ? '' : TxColumns.cellText(row, col);

    final amount = c.amountOf(row);
    final dir = c.directionOf(row);
    final amountColor = dir < 0 ? AppColors.blood : (dir > 0 ? AppColors.green : AppColors.text);
    final title = text(c.title);
    final party = c.party != c.title ? text(c.party) : '';
    final date = text(c.date);
    final ref = text(c.ref);
    final summary = c.summary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.purple.withValues(alpha: 0.25),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlowPulse(
                    color: amountColor == AppColors.text ? AppColors.purple : amountColor,
                    intensity: 0.6,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: dir < 0 ? AppColors.bloodBg : (dir > 0 ? AppColors.greenBg : AppColors.surface2),
                      child: Icon(
                        dir < 0 ? Icons.north_east : (dir > 0 ? Icons.south_west : Icons.receipt_long),
                        size: 16,
                        color: amountColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isNotEmpty ? title : (party.isNotEmpty ? party : 'حركة'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (party.isNotEmpty && title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(party, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (amount != null)
                    Text(
                      '${dir < 0 ? '-' : (dir > 0 ? '+' : '')}${formatMoney(amount)} ${c.currencySymbol(row)}'.trim(),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: amountColor),
                    ),
                ],
              ),
              if (date.isNotEmpty || ref.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (date.isNotEmpty) ...[
                      const Icon(Icons.schedule, size: 13, color: AppColors.textFaint),
                      const SizedBox(width: 4),
                      Text(date,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                    const Spacer(),
                    if (ref.isNotEmpty)
                      Flexible(
                        child: Text('#$ref',
                            textDirection: TextDirection.ltr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textFaint)),
                      ),
                  ],
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_open
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 20),
                          // Fields not on the card face first, then the summarised ones.
                          for (final col in [
                            ...c.columns.where((col) => !summary.contains(col)),
                            ...c.columns.where(summary.contains),
                          ])
                            if (text(col).trim().isNotEmpty) _detail(col, text(col)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: SelectableText(value,
                textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}
