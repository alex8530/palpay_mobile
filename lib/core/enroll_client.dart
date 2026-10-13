import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'enroll_config.dart';
import 'palpay_signer.dart';
import 'settings_store.dart';

/// Result of a registration-server request.
class EnrollResult {
  EnrollResult({
    required this.status,
    required this.json,
    required this.raw,
    required this.error,
    this.url = '',
    this.requestHeaders = const {},
    this.requestBody = '',
    this.durationMs,
  });

  final int? status;
  final dynamic json;
  final String raw;
  final String? error;
  final String url;
  final Map<String, String> requestHeaders;
  final String requestBody;
  final int? durationMs;
}

/// Low-level client for the upstream registration API — a Dart port of
/// App\Services\EnrollmentClient (unsigned "registration" mode, Content-MD5 =
/// Base64(MD5(raw body))).
class EnrollClient {
  EnrollClient([SettingsStore? settings]) : _s = settings ?? SettingsStore.instance;

  final SettingsStore _s;

  String get _base => _s.get('BASE_URL').replaceAll(RegExp(r'/+$'), '');
  String get _udid => PalpaySigner.udid(
      _s.get('ANDROID_ID').isEmpty ? 'a1b2c3d4e5f60718' : _s.get('ANDROID_ID'));

  static String encode(Map<String, dynamic> payload) =>
      jsonEncode(payload); // compact, no whitespace

  static String contentMd5(String body) =>
      base64.encode(md5.convert(utf8.encode(body)).bytes);

  /// "MBS_AUTH <HMAC-SHA256>:<ts>:0", or ":<ts>:0" when there is no secret key.
  /// Signed text: "POST\n<Content-MD5>\n<ts>\n0\n<userToken>\n<lowercase path>".
  static String authorization(String contentMd5, String path, String ts,
      [String userToken = '']) {
    const counter = '0';
    const secret = EnrollConfig.secretKey;
    var signature = '';
    if (secret.isNotEmpty) {
      final signText = [
        'POST',
        contentMd5,
        ts,
        counter,
        userToken,
        '/${path.toLowerCase().replaceFirst(RegExp(r'^/+'), '')}',
      ].join('\n');
      final mac = Hmac(sha256, base64.decode(secret)).convert(utf8.encode(signText));
      signature = 'MBS_AUTH ${base64.encode(mac.bytes)}';
    }
    return '$signature:$ts:$counter';
  }

  Map<String, String> _postHeaders(String body, String path) {
    final md5h = contentMd5(body);
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    return {
      'Authorization': authorization(md5h, path, ts),
      'Content-MD5': md5h,
      'X-MBS-Udid': _udid,
      'X-HISABI-VER': '2.0',
      'X-PALPAY-Source': 'WALLET_MOBILE',
      'X-LOGIN-MODE': '0',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': '*/*',
    };
  }

  Future<EnrollResult> post(String endpointKey, Map<String, dynamic> payload) async {
    final body = encode(payload);
    final path = EnrollConfig.endpoints[endpointKey]!;
    final url = '$_base$path';
    final headers = _postHeaders(body, path);
    final start = DateTime.now();

    try {
      final req = http.Request('POST', Uri.parse(url));
      req.headers.addAll(headers);
      req.body = body;
      final streamed =
          await req.send().timeout(const Duration(seconds: EnrollConfig.timeoutSeconds));
      final res = await http.Response.fromStream(streamed);
      dynamic json;
      try {
        json = jsonDecode(res.body);
      } catch (_) {
        json = null;
      }
      return EnrollResult(
        status: res.statusCode,
        json: json,
        raw: res.body,
        error: null,
        url: url,
        requestHeaders: headers,
        requestBody: body,
        durationMs: DateTime.now().difference(start).inMilliseconds,
      );
    } catch (e) {
      return EnrollResult(
        status: null,
        json: null,
        raw: '',
        error: e.toString(),
        url: url,
        requestHeaders: headers,
        requestBody: body,
        durationMs: DateTime.now().difference(start).inMilliseconds,
      );
    }
  }

  /// GET an info list (countries/cities/…) — mirrors LookupService::fetch.
  /// Returns a list of {id, name}; throws on failure.
  Future<List<Map<String, String>>> getLookup(String path, Map<String, String> query) async {
    final md5h = contentMd5('');
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final headers = {
      'Authorization': authorization(md5h, path, ts),
      'Content-MD5': md5h,
      'X-MBS-Udid': _udid,
      'X-HISABI-VER': '2.0',
      'X-PALPAY-Source': 'WALLET_MOBILE',
      'Content-Type': 'application/json; charset=utf-8',
      'Accept-Language': 'ar',
      'X-LOGIN-MODE': '0',
      'X-PALPAY-UserToken': '',
    };
    final uri = Uri.parse('$_base$path').replace(queryParameters: query.isEmpty ? null : query);

    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: EnrollConfig.timeoutSeconds));
    dynamic items;
    try {
      items = jsonDecode(res.body);
    } catch (_) {
      items = null;
    }
    if (res.statusCode < 200 || res.statusCode >= 300 || items is! List) {
      throw Exception('Lookup failed: HTTP ${res.statusCode}');
    }
    return [
      for (final it in items)
        if (it is Map && it['id'] != null && it['name'] != null)
          {'id': it['id'].toString(), 'name': it['name'].toString()},
    ];
  }

  /// Finds a key anywhere in a decoded response, ignoring case. Scalars only.
  static String? find(dynamic json, String key) {
    if (json is Map) {
      for (final entry in json.entries) {
        if (entry.key.toString().toLowerCase() == key.toLowerCase() &&
            (entry.value is String || entry.value is num || entry.value is bool)) {
          return entry.value.toString();
        }
      }
      for (final v in json.values) {
        final found = find(v, key);
        if (found != null) return found;
      }
    } else if (json is List) {
      for (final v in json) {
        final found = find(v, key);
        if (found != null) return found;
      }
    }
    return null;
  }
}
