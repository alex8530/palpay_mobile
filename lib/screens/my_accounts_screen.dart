import 'package:flutter/material.dart';

import '../core/accounts.dart';
import '../theme/app_theme.dart';
import '../widgets/account_cards.dart';
import '../widgets/fx.dart';

/// "حساباتي": calls getPalPayAccounts and shows every account, with a
/// copyable account number.
class MyAccountsScreen extends StatefulWidget {
  const MyAccountsScreen({super.key});

  @override
  State<MyAccountsScreen> createState() => _MyAccountsScreenState();
}

class _MyAccountsScreenState extends State<MyAccountsScreen> {
  RowsResult? _accounts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await loadAccounts();
    if (mounted) {
      setState(() => _accounts = accounts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    return Scaffold(
      appBar: AppBar(
        title: const FlickerText('حساباتي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      ),
      body: accounts == null
          ? const LoaderBox()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (accounts.error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(accounts.error!, style: const TextStyle(color: AppColors.blood)),
                      ),
                    )
                  else if (accounts.rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('ما في حسابات بالرد.'),
                      ),
                    )
                  else
                    AccountCards(rows: accounts.rows, title: 'حساباتي'),
                ],
              ),
            ),
    );
  }
}
