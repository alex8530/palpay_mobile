import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Global key/value settings store, ported from `App\Models\PalpaySetting`.
///
/// The whole map is persisted as a single encrypted JSON blob via
/// flutter_secure_storage, since several values (PASSWORD, SALT, ACCESS_TOKEN)
/// are sensitive. Defaults are merged under any stored overrides.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();

  static final SettingsStore instance = SettingsStore._();

  static const _storageKey = 'palpay_settings_v1';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const Map<String, String> defaults = {
    'BASE_URL': 'https://mahfazatim2.palpay.ps',
    // identity / signing
    'USERNAME': '',
    'PASSWORD': '',
    'SALT': '',
    'ACCESS_TOKEN': '',
    'NEW_PASSWORD': '',
    'ANDROID_ID': 'a1b2c3d4e5f60718',
    'COUNTER': '0',
    // UI
    'DEV_MODE': '0',
    // static headers
    'H_X_PALPAY_SOURCE': 'WALLET_MOBILE',
    'H_X_HISABI_VER': '2.0',
    'H_X_LOGIN_MODE': '0',
    'H_ACCEPT_LANGUAGE': 'en,ar;q=0.8',
    'H_CONTENT_TYPE': 'application/json; charset=utf-8',
    // chained values (filled automatically from responses)
    'ACCOUNT': '',
    'REFNUM': '',
    'FROM_ACCOUNT': '',
    'TO_NAME': '',
    'DEST_CODE': '',
    'TRANSFER_ID': '',
    'TRANSFER_TOKEN': '',
    'TR_REFNUM': '',
  };

  Map<String, String> _values = Map.of(defaults);

  Map<String, String> get values => Map.unmodifiable(_values);

  bool get devMode => get('DEV_MODE') == '1';

  Future<void> load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final stored = (jsonDecode(raw) as Map).map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
        _values = {...defaults, ...stored};
      }
    } catch (_) {
      _values = Map.of(defaults);
    }
    notifyListeners();
  }

  String get(String key, [String fallback = '']) =>
      _values[key] ?? fallback;

  Future<void> put(String key, String? value) async {
    _values[key] = value ?? '';
    await _persist();
    notifyListeners();
  }

  Future<void> putMany(Map<String, String?> entries) async {
    entries.forEach((k, v) => _values[k] = v ?? '');
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.write(key: _storageKey, value: jsonEncode(_values));
  }
}
