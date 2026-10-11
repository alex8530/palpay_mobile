import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Exact Dart port of the PalPay / Mahfazati request signing used by the web
/// app (`App\Services\Palpay\PalpaySigner`) and the Postman pre-request script.
///
///   SIGNING_KEY   = Base64( SHA256( username + ":" + salt + ":" + password ) )  // user mode
///                 = ""                                                           // registration mode
///   Content-MD5   = Base64( MD5(body) )                                          // "" when no body
///   X-MBS-Udid    = Base64( SHA256(android_id) )
///   canonical     = METHOD \n Content-MD5 \n ts \n counter \n accessToken \n path(lowercase)
///   signature     = "MBS_AUTH " + Base64( HmacSHA256(canonical, Base64Decode(SIGNING_KEY)) )
///   Authorization = signature + ":" + ts + ":" + counter
class PalpaySigner {
  /// X-MBS-Udid = Base64(SHA256(android_id)).
  static String udid(String androidId) {
    return base64.encode(sha256.convert(utf8.encode(androidId.trim())).bytes);
  }

  /// Content-MD5 = Base64(MD5(body)); empty string when the body is empty.
  static String contentMd5(String body) {
    if (body.isEmpty) {
      return '';
    }
    return base64.encode(md5.convert(utf8.encode(body)).bytes);
  }

  /// SIGNING_KEY = Base64(SHA256(username:salt:password)).
  static String signingKey(String username, String salt, String password) {
    final digest = sha256.convert(utf8.encode('$username:$salt:$password'));
    return base64.encode(digest.bytes);
  }

  /// The canonical string that gets signed.
  static String canonical(
    String method,
    String contentMd5,
    int ts,
    int counter,
    String accessToken,
    String path,
  ) {
    return [
      method,
      contentMd5.trim(),
      ts.toString(),
      counter.toString(),
      accessToken,
      path.toLowerCase(),
    ].join('\n');
  }

  /// Build the Authorization header value.
  ///
  /// [signingKeyB64] is a Base64 key, or "" for registration mode (empty signature).
  static String authorization(
    String canonicalString,
    int ts,
    int counter,
    String signingKeyB64,
  ) {
    var sig = '';
    if (signingKeyB64.isNotEmpty) {
      final key = base64.decode(signingKeyB64);
      final raw = Hmac(sha256, key).convert(utf8.encode(canonicalString));
      sig = 'MBS_AUTH ${base64.encode(raw.bytes)}';
    }

    return '$sig:$ts:$counter'
        .trim()
        .replaceAll('\n', '')
        .replaceAll('\r', '');
  }

  /// Normalise a path: ensure a single leading slash (lowercasing happens in canonical).
  static String normalisePath(String path) {
    var p = path;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.path.isNotEmpty) {
      p = uri.path;
    }
    if (!p.startsWith('/')) {
      p = '/$p';
    }
    return p;
  }
}
