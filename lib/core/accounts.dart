import 'palpay_client.dart';
import 'result_utils.dart';
import 'settings_store.dart';

/// Outcome of a getPalPayAccounts call: the account rows, or an error message.
class AccountsResult {
  AccountsResult(this.rows, this.error);

  final List<Map<String, dynamic>> rows;
  final String? error;
}

/// Call getPalPayAccounts and extract its rows. On success the registry's save
/// rule also stores the shekel account in FROM_ACCOUNT.
Future<AccountsResult> loadAccounts() async {
  final result = await PalpayClient(SettingsStore.instance).sendKey('getPalPayAccounts');
  if (!result.ok) {
    return AccountsResult(const [], errorMessage(result));
  }
  return AccountsResult(extractRows(result.json) ?? const [], null);
}

/// The holder's display name from the account rows, if any.
String? holderName(List<Map<String, dynamic>> rows) {
  for (final key in const ['holderName', 'accountName', 'nickName']) {
    for (final row in rows) {
      final v = row[key]?.toString() ?? '';
      if (v.isNotEmpty) {
        return v;
      }
    }
  }
  return null;
}
