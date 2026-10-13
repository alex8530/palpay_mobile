import 'package:flutter/material.dart';

import '../core/accounts.dart';
import '../core/result_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/fx.dart';
import '../widgets/transactions_table.dart';

/// Full list of transactions from a registry request (ministatement by default).
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    this.requestKey = 'ministatement',
    this.overrides = const {},
    this.title = 'الحركات',
  });

  final String requestKey;
  final Map<String, String> overrides;
  final String title;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  RowsResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await loadRows(widget.requestKey, widget.overrides);
    if (mounted) {
      setState(() => _result = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(
        title: FlickerText(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: r == null
          ? const LoaderBox()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (r.error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(r.error!, style: const TextStyle(color: AppColors.blood)),
                      ),
                    )
                  else if (r.rows.isEmpty)
                    const Card(
                      child: Padding(padding: EdgeInsets.all(16), child: Text('ما في حركات.')),
                    )
                  else
                    TransactionsTable(rows: r.rows, columns: columnsFor(r.rows), exportName: widget.requestKey),
                ],
              ),
            ),
    );
  }
}
