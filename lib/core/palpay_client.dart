import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/request_def.dart';
import 'palpay_signer.dart';
import 'settings_store.dart';

/// Result of sending a PalPay request.
class PalpayResult {
  PalpayResult({
    required this.ok,
    required this.status,
    required this.body,
    required this.json,
    required this.error,
    required this.requestHeaders,
    required this.canonical,
    required this.sentBody,
    this.saved = const {},
  });

  final bool ok;
  final int? status;
  final String body;
  final dynamic json;
  final String? error;
  final Map<String, String> requestHeaders;
  final String canonical;
  final String sentBody;
  Map<String, String> saved;
}

/// Builds signed headers, sends the request, and applies the registry's
/// auto-save rules — a port of `App\Services\Palpay\PalpayClient` plus the
/// controller's buildBody().
class PalpayClient {
  PalpayClient(this.settings);

  final SettingsStore settings;

  /// Build the typed body map and the raw string input map from form values.
  /// Returns (data, input).
  (Map<String, dynamic>, Map<String, String>) buildBody(
    RequestDef def,
    Map<String, String> formValues,
  ) {
    final data = <String, dynamic>{};
    final input = <String, String>{};

    for (final field in def.fields) {
      final raw = formValues[field.name] ?? '';
      input[field.name] = raw;

      if (field.type == 'checkbox') {
        data[field.name] = raw == '1' || raw.toLowerCase() == 'true';
        continue;
      }

      switch (field.cast) {
        case 'int':
          data[field.name] = int.tryParse(raw) ?? 0;
          break;
        case 'float':
          data[field.name] = double.tryParse(raw) ?? 0;
          break;
        case 'bool':
          data[field.name] = raw.isNotEmpty && raw != '0';
          break;
        default:
          data[field.name] = raw;
      }
    }

    return (data, input);
  }

  Map<String, String> buildHeaders(String body, String authorization) {
    final s = settings;
    final androidId = s.get('ANDROID_ID').isEmpty ? 'a1b2c3d4e5f60718' : s.get('ANDROID_ID');
    return {
      'Authorization': authorization,
      'Content-MD5': PalpaySigner.contentMd5(body),
      'Content-Type': s.get('H_CONTENT_TYPE'),
      'X-PALPAY-Source': s.get('H_X_PALPAY_SOURCE'),
      'X-HISABI-VER': s.get('H_X_HISABI_VER'),
      'X-LOGIN-MODE': s.get('H_X_LOGIN_MODE'),
      'X-PALPAY-UserToken': s.get('ACCESS_TOKEN'),
      'Accept-Language': s.get('H_ACCEPT_LANGUAGE'),
      'X-MBS-Udid': PalpaySigner.udid(androidId),
    };
  }

  /// Sign and send; applies save rules on success.
  Future<PalpayResult> send(RequestDef def, Map<String, String> formValues) async {
    final (data, input) = buildBody(def, formValues);
    final body = data.isEmpty
        ? '{}'
        : jsonEncode(data);

    final s = settings;
    final username = s.get('USERNAME');
    final password = s.get('PASSWORD');
    final salt = s.get('SALT');
    final accessToken = s.get('ACCESS_TOKEN');
    final counter = int.tryParse(s.get('COUNTER')) ?? 0;

    final signingKey = def.signing == 'registration'
        ? ''
        : PalpaySigner.signingKey(username, salt, password);

    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final path = PalpaySigner.normalisePath(def.path);
    final contentMd5 = PalpaySigner.contentMd5(body);
    final canonical = PalpaySigner.canonical(def.method, contentMd5, ts, counter, accessToken, path);
    final authorization = PalpaySigner.authorization(canonical, ts, counter, signingKey);

    final headers = buildHeaders(body, authorization);

    final base = s.get('BASE_URL').replaceAll(RegExp(r'/+$'), '');
    final url = Uri.parse('$base$path');

    try {
      final request = http.Request(def.method, url);
      request.headers.addAll(headers);
      request.body = body;

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      final raw = response.body;
      dynamic json;
      try {
        json = jsonDecode(raw);
      } catch (_) {
        json = null;
      }

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      final result = PalpayResult(
        ok: ok,
        status: response.statusCode,
        body: raw,
        json: json,
        error: null,
        requestHeaders: headers,
        canonical: canonical,
        sentBody: body,
      );

      if (ok && json != null) {
        result.saved = await applySaveRules(def, json, input);
      }

      return result;
    } catch (e) {
      return PalpayResult(
        ok: false,
        status: null,
        body: '',
        json: null,
        error: e.toString(),
        requestHeaders: headers,
        canonical: canonical,
        sentBody: body,
      );
    }
  }

  /// Apply save rules to a successful JSON response; persists and returns them.
  Future<Map<String, String>> applySaveRules(
    RequestDef def,
    dynamic json,
    Map<String, String> input,
  ) async {
    final saved = <String, String>{};
    for (final rule in def.save) {
      final value = _resolveSaveValue(rule, json, input);
      if (value != null && value.toString().isNotEmpty) {
        saved[rule.setting] = value.toString();
      }
    }
    if (saved.isNotEmpty) {
      await settings.putMany(saved);
    }
    return saved;
  }

  dynamic _resolveSaveValue(SaveRule rule, dynamic json, Map<String, String> input) {
    switch (rule.source) {
      case 'input':
        return input[rule.input];
      case 'json':
        return _dotGet(json, rule.key ?? '');
      case 'array_first':
        if (json is List && json.isNotEmpty && json[0] is Map) {
          return (json[0] as Map)[rule.key];
        }
        return null;
      case 'array_find':
        if (json is List) {
          for (final item in json) {
            if (item is! Map) {
              continue;
            }
            var matches = true;
            rule.match?.forEach((mk, mv) {
              // loose comparison like PHP (==): compare string forms
              if (item[mk]?.toString() != mv?.toString()) {
                matches = false;
              }
            });
            if (matches) {
              return item[rule.key];
            }
          }
        }
        return null;
    }
    return null;
  }

  /// Dotted-path getter: 'accounts.0.accountNumber'.
  dynamic _dotGet(dynamic json, String path) {
    if (path.isEmpty) {
      return null;
    }
    dynamic current = json;
    for (final part in path.split('.')) {
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        final idx = int.tryParse(part);
        if (idx == null || idx < 0 || idx >= current.length) {
          return null;
        }
        current = current[idx];
      } else {
        return null;
      }
    }
    return current;
  }
}
