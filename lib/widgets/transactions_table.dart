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

  @override
  void initState() {
    super.initState();
    _dateColIdx = _detectDateColumn();
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
            TextButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('تصدير CSV'),
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
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('لا توجد نتائج مطابقة.', style: TextStyle(color: Color(0xFF64748B))),
          )
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
}
