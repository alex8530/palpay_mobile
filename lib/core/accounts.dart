import 'palpay_client.dart';
import 'result_utils.dart';
import 'settings_store.dart';

/// Outcome of a list-returning PalPay call: its rows, or an error message.
class RowsResult {
  RowsResult(this.rows, this.error, this.status);

  final List<Map<String, dynamic>> rows;
  final String? error;
  final int? status;

  /// The server refused our credentials (expired token or bad signature).
  bool get unauthorized => status == 401 || status == 403;
}

/// Call a registry request and extract its rows. On success the registry's
/// save rules run too.
Future<RowsResult> loadRows(String key, [Map<String, String> overrides = const {}]) async {
  final result = await PalpayClient(SettingsStore.instance).sendKey(key, overrides);
  if (!result.ok) {
    return RowsResult(const [], errorMessage(result), result.status);
  }
  return RowsResult(extractRows(result.json) ?? const [], null, result.status);
}

/// getPalPayAccounts; also stores the shekel account in FROM_ACCOUNT.
Future<RowsResult> loadAccounts() => loadRows('getPalPayAccounts');

/// The holder's display name from the account rows, if any.
String? holderName(List<Map<String, dynamic>> rows) => firstField(rows, const ['holderName', 'accountName']);

/// First non-empty value of any of [keys] across [rows].
String? firstField(List<Map<String, dynamic>> rows, List<String> keys) {
  for (final key in keys) {
    for (final row in rows) {
      final v = row[key]?.toString() ?? '';
      if (v.isNotEmpty) {
        return v;
      }
    }
  }
  return null;
}
