import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TransactionsTable extends StatefulWidget {
  const TransactionsTable({
    super.key,
    required this.rows,
    required this.columns,
    required this.exportName,
  });

  final List<Map<String, dynamic>> rows;
  final List<String> columns;
  final String exportName;

  @override
  State<TransactionsTable> createState() => _TransactionsTableState();
}

class _TransactionsTableState extends State<TransactionsTable> {
  final _searchCtrl = TextEditingController();
  String _searchTerm = '';
  String? _searchColumn; // null = all
  int _sortCol = -1;
  bool _sortAsc = true;
  int _dateColIdx = -1;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _asCards = true;
  final _expanded = <int>{};

  // Columns guessed from their names, used by the card view.
  String? _amountCol;
  String? _titleCol;
  String? _partyCol;
  String? _refCol;
  String? _currencyCol;
  String? _directionCol;

  @override
  void initState() {
    super.initState();
    _dateColIdx = _detectDateColumn();
    if (_dateColIdx >= 0) {
      _sortCol = _dateColIdx;
      _sortAsc = false;
    }
    _amountCol = _findCol([r'^amount$', r'amount', r'amt', r'^value$', r'total']);
    _titleCol = _findCol([r'desc', r'details', r'narrat', r'remark', r'purpose', r'note', r'trans.*type', r'type.*(name|desc)', r'^type$']);
    _partyCol = _findCol([r'(to|from|benef|receiver|sender|client|customer|holder).*name', r'name']);
    _refCol = _findCol([r'ref', r'transfer.*id', r'trans.*id', r'^id$']);
    _currencyCol = _findCol([r'cur']);
    _directionCol = _findCol([r'debit.*credit', r'^(dr|cr)', r'direction', r'in.?out', r'sign']);
  }

  /// First column whose name matches one of [patterns] (in priority order)
  /// and has at least one non-empty value.
  String? _findCol(List<String> patterns) {
    for (final pattern in patterns) {
      final re = RegExp(pattern, caseSensitive: false);
      for (final col in widget.columns) {
        if (re.hasMatch(col) && widget.rows.any((r) => _cellText(r, col).trim().isNotEmpty)) {
          return col;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _cellText(Map<String, dynamic> row, String col) {
    final v = row[col];
    if (v == null) return '';
    if (v is String || v is num || v is bool) return v.toString();
    return jsonEncode(v);
  }

  DateTime? _parseDate(String t) {
    final s = t.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  int _detectDateColumn() {
    for (var c = 0; c < widget.columns.length; c++) {
      final col = widget.columns[c];
      var filled = 0, dated = 0;
      for (final row in widget.rows) {
        final txt = _cellText(row, col).trim();
        if (txt.isEmpty) continue;
        filled++;
        if (RegExp(r'\d{4}').hasMatch(txt) &&
            RegExp(r'[-/:]').hasMatch(txt) &&
            _parseDate(txt) != null) {
          dated++;
        }
      }
      if (filled >= 2 && dated / filled >= 0.7) {
        return c;
      }
    }
    return -1;
  }

  bool _matchesDate(Map<String, dynamic> row) {
    if (_dateColIdx < 0 || (_dateFrom == null && _dateTo == null)) return true;
    final d = _parseDate(_cellText(row, widget.columns[_dateColIdx]));
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    if (_dateFrom != null && day.isBefore(_dateFrom!)) return false;
    if (_dateTo != null && day.isAfter(_dateTo!)) return false;
    return true;
  }

  List<Map<String, dynamic>> get _visible {
    final term = _searchTerm.trim().toLowerCase();
    var list = widget.rows.where((row) {
      final haystack = _searchColumn == null
          ? widget.columns.map((c) => _cellText(row, c)).join(' ')
          : _cellText(row, _searchColumn!);
      final textOk = term.isEmpty || haystack.toLowerCase().contains(term);
      return textOk && _matchesDate(row);
    }).toList();

    if (_sortCol >= 0) {
      final col = widget.columns[_sortCol];
      list.sort((a, b) {
        final ka = _sortKey(_cellText(a, col));
        final kb = _sortKey(_cellText(b, col));
        if (ka.$1 != kb.$1) {
          if (ka.$1 == 2 || kb.$1 == 2) return ka.$1 - kb.$1; // empties last
          return (ka.$1 - kb.$1) * (_sortAsc ? 1 : -1);
        }
        int cmp;
        if (ka.$1 == 0) {
          cmp = (ka.$2 as num).compareTo(kb.$2 as num);
        } else {
          cmp = ka.$2.toString().compareTo(kb.$2.toString());
        }
        return cmp * (_sortAsc ? 1 : -1);
      });
    }
    return list;
  }

  /// (rank, value): rank 0 = date/number, 1 = text, 2 = empty.
  (int, Object) _sortKey(String text) {
    final t = text.trim();
    if (t.isEmpty) return (2, '');
    if (RegExp(r'\d{4}').hasMatch(t) && RegExp(r'[-/:]').hasMatch(t)) {
      final d = _parseDate(t);
      if (d != null) return (0, d.millisecondsSinceEpoch);
    }
    final cleaned = t.replaceAll(RegExp(r'[,\s]'), '');
    if (RegExp(r'^-?\d*\.?\d+$').hasMatch(cleaned)) {
      return (0, num.parse(cleaned));
    }
    return (1, t);
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = DateTime(picked.year, picked.month, picked.day);
        } else {
          _dateTo = DateTime(picked.year, picked.month, picked.day);
        }
      });
    }
  }

  String _csvCell(String t) {
    if (RegExp(r'[",\n]').hasMatch(t)) {
      return '"${t.replaceAll('"', '""')}"';
    }
    return t;
  }

  Future<void> _exportCsv() async {
    final visible = _visible;
    final lines = <String>[
      widget.columns.map(_csvCell).join(','),
      for (final row in visible)
        widget.columns.map((c) => _csvCell(_cellText(row, c))).join(','),
    ];
    final content = '﻿${lines.join('\r\n')}';
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${widget.exportName}-$date.csv');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final fmt = (DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('الحركات (${visible.length} من ${widget.rows.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            IconButton(
              tooltip: _asCards ? 'عرض كجدول' : 'عرض كبطاقات',
              icon: Icon(_asCards ? Icons.table_rows_outlined : Icons.view_agenda_outlined, size: 20),
              onPressed: () => setState(() => _asCards = !_asCards),
            ),
            TextButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('CSV'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchTerm = v),
                decoration: const InputDecoration(
                  hintText: 'بحث…',
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _searchColumn,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل الأعمدة')),
                  for (final c in widget.columns)
                    DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _searchColumn = v),
              ),
            ),
          ],
        ),
        if (_dateColIdx >= 0) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('فلترة بعمود ${widget.columns[_dateColIdx]}:',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              OutlinedButton(
                onPressed: () => _pickDate(true),
                child: Text(_dateFrom == null ? 'من' : fmt(_dateFrom!)),
              ),
              OutlinedButton(
                onPressed: () => _pickDate(false),
                child: Text(_dateTo == null ? 'إلى' : fmt(_dateTo!)),
              ),
              if (_dateFrom != null || _dateTo != null)
                TextButton(
                  onPressed: () => setState(() {
                    _dateFrom = null;
                    _dateTo = null;
                  }),
                  child: const Text('مسح'),
                ),
            ],
          ),
        ],
        if (_asCards) ...[
          const SizedBox(height: 8),
          _sortBar(),
        ],
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('لا توجد نتائج مطابقة.', style: TextStyle(color: Color(0xFF64748B))),
          )
        else if (_asCards)
          Column(children: [for (final row in visible) _txCard(row)])
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: DataTable(
                sortColumnIndex: _sortCol >= 0 ? _sortCol : null,
                sortAscending: _sortAsc,
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: [
                  for (var i = 0; i < widget.columns.length; i++)
                    DataColumn(
                      label: Text(widget.columns[i],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      onSort: (idx, asc) => setState(() {
                        _sortCol = idx;
                        _sortAsc = asc;
                      }),
                    ),
                ],
                rows: [
                  for (final row in visible)
                    DataRow(
                      cells: [
                        for (final col in widget.columns)
                          DataCell(Text(_cellText(row, col),
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _sortBar() {
    return Row(
      children: [
        const Text('ترتيب حسب:', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _sortCol,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem(value: -1, child: Text('بدون')),
              for (var i = 0; i < widget.columns.length; i++)
                DropdownMenuItem(value: i, child: Text(widget.columns[i], overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _sortCol = v ?? -1),
          ),
        ),
        IconButton(
          tooltip: _sortAsc ? 'تصاعدي' : 'تنازلي',
          icon: Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 20),
          onPressed: _sortCol < 0 ? null : () => setState(() => _sortAsc = !_sortAsc),
        ),
      ],
    );
  }

  /// -1 outgoing, 1 incoming, 0 unknown. A negative amount wins; otherwise a
  /// debit/credit style column decides.
  int _direction(Map<String, dynamic> row, num? amount) {
    if (amount != null && amount < 0) return -1;
    if (_directionCol == null) return 0;
    final v = _cellText(row, _directionCol!).trim().toLowerCase();
    if (v.startsWith('d') || v == '-' || v == 'out' || v == '-1') return -1;
    if (v.startsWith('c') || v == '+' || v == 'in' || v == '1') return 1;
    return 0;
  }

  num? _amountOf(Map<String, dynamic> row) {
    if (_amountCol == null) return null;
    return num.tryParse(_cellText(row, _amountCol!).replaceAll(RegExp(r'[,\s]'), ''));
  }

  String _money(num n) {
    final parts = n.abs().toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intPart.${parts[1]}';
  }

  String _currencySymbol(Map<String, dynamic> row) {
    if (_currencyCol == null) return '';
    final c = _cellText(row, _currencyCol!).trim();
    const symbols = {'376': '₪', 'ILS': '₪', '840': '\$', 'USD': '\$', '400': 'د.أ', 'JOD': 'د.أ'};
    return symbols[c.toUpperCase()] ?? c;
  }

  /// One transaction as a card: description + amount on top, party, date
  /// and reference below; tap to show every field.
  Widget _txCard(Map<String, dynamic> row) {
    final id = identityHashCode(row);
    final open = _expanded.contains(id);
    final amount = _amountOf(row);
    final dir = _direction(row, amount);
    final amountColor = dir < 0
        ? const Color(0xFFB91C1C)
        : (dir > 0 ? const Color(0xFF15803D) : const Color(0xFF0F172A));
    final title = _titleCol != null ? _cellText(row, _titleCol!) : '';
    final party = _partyCol != null && _partyCol != _titleCol ? _cellText(row, _partyCol!) : '';
    final date = _dateColIdx >= 0 ? _cellText(row, widget.columns[_dateColIdx]) : '';
    final ref = _refCol != null ? _cellText(row, _refCol!) : '';
    final summaryCols = {
      _amountCol,
      _titleCol,
      _partyCol,
      _refCol,
      _currencyCol,
      _directionCol,
      if (_dateColIdx >= 0) widget.columns[_dateColIdx],
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => open ? _expanded.remove(id) : _expanded.add(id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: dir < 0
                        ? const Color(0xFFFEE2E2)
                        : (dir > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9)),
                    child: Icon(
                      dir < 0 ? Icons.north_east : (dir > 0 ? Icons.south_west : Icons.receipt_long),
                      size: 16,
                      color: amountColor,
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
                            child: Text(party, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (amount != null)
                    Text(
                      '${dir < 0 ? '-' : (dir > 0 ? '+' : '')}${_money(amount)} ${_currencySymbol(row)}'.trim(),
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
                      const Icon(Icons.schedule, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(date,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                    const Spacer(),
                    if (ref.isNotEmpty)
                      Flexible(
                        child: Text('#$ref',
                            textDirection: TextDirection.ltr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ),
                  ],
                ),
              ],
              if (open) ...[
                const Divider(height: 20),
                // Fields not on the card face first, then the summarised ones.
                for (final col in [
                  ...widget.columns.where((c) => !summaryCols.contains(c)),
                  ...widget.columns.where(summaryCols.contains),
                ])
                  if (_cellText(row, col).trim().isNotEmpty) _detail(col, _cellText(row, col)),
              ],
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
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: SelectableText(value,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}
