import 'package:flutter/material.dart';

import '../core/accounts.dart';
import '../widgets/account_cards.dart';

/// "حساباتي": calls getPalPayAccounts and shows every account, with a
/// copyable account number.
class MyAccountsScreen extends StatefulWidget {
  const MyAccountsScreen({super.key});

  @override
  State<MyAccountsScreen> createState() => _MyAccountsScreenState();
}

class _MyAccountsScreenState extends State<MyAccountsScreen> {
  AccountsResult? _accounts;

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
      appBar: AppBar(title: const Text('حساباتي')),
      body: accounts == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (accounts.error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(accounts.error!, style: const TextStyle(color: Color(0xFFB91C1C))),
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
