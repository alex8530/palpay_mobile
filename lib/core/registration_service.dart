import 'dart:typed_data';

import 'enroll_client.dart';
import 'enroll_config.dart';
import 'enroll_images.dart';

/// The data the registration form collects (before images). Mirrors
/// RegistrationRequest fields; dob always equals placeOfBirth and idType is '1'.
class RegistrationData {
  RegistrationData({
    required this.fullname,
    required this.arabicfullname,
    required this.username,
    required this.password,
    required this.mobile,
    required this.email,
    required this.placeOfBirth, // yyyy-MM-dd (dob uses the same value)
    required this.gender,
    required this.idNumber,
    required this.issuanceCountry,
    required this.nationality,
    required this.country,
    required this.region,
    required this.governorate,
    required this.city,
    required this.address,
    required this.jobTitle,
    required this.jobPosition,
    required this.incomeRate,
    required this.termAccepted,
    required this.noOtherWallet,
    required this.hasBankAccount,
  });

  final String fullname, arabicfullname, username, password, mobile, email;
  final String placeOfBirth, gender, idNumber, issuanceCountry, nationality;
  final String country, region, governorate, city, address, jobTitle, jobPosition, incomeRate;
  final bool termAccepted, noOtherWallet, hasBankAccount;

  /// Body for /register/EnrollInMobileBanking (exact upstream shape).
  Map<String, dynamic> toEnrollPayload() => {
        'fullname': fullname,
        'arabicfullname': arabicfullname,
        'username': username,
        'password': password,
        'mobile': mobile,
        'email': email,
        'dob': '${placeOfBirth}T00:00:00',
        'gender': gender,
        'id': idNumber,
        'idType': '1',
        'issuanceCountry': issuanceCountry,
        'nationality': nationality,
        'placeOfBirth': '${placeOfBirth}T00:00:00',
        'country': country,
        'region': region,
        'governorate': governorate,
        'city': city,
        'address': address,
        'jobTitle': jobTitle,
        'jobPosition': jobPosition,
        'incomeRate': incomeRate,
        'termAccepted': termAccepted,
        'noOtherWallet': noOtherWallet,
        'hasBankAccount': hasBankAccount,
      };

  /// Body for /register/resendActivationInfo.
  Map<String, dynamic> toResendPayload() => {
        'username': username,
        'mobile': mobile,
        'email': email,
      };
}

/// One attempted step, shown in the result log (like the web api_log).
class RegistrationStep {
  RegistrationStep({
    required this.step,
    required this.ok,
    required this.status,
    required this.reason,
    required this.response,
  });

  final String step;
  final bool ok;
  final int? status;
  final String? reason;
  final String response;
}

class RegistrationResult {
  RegistrationResult({
    required this.ok,
    required this.message,
    required this.log,
    this.idImageBase64,
    this.personalImageBase64,
  });

  final bool ok;
  final String message;
  final List<RegistrationStep> log;

  /// The compressed JPEGs actually sent to PreEnroll (kept for the archive).
  final String? idImageBase64, personalImageBase64;
}

/// Runs the registration flow against the upstream API — a Dart port of
/// App\Services\EnrollmentService, with the same steps, success checks and
/// error messages. No admin approval: it runs immediately on submit.
///
///   1. PreEnroll {nationalId, idImage, personalImage} -> desc starts with "Your uploaded images"
///   2. EnrollInMobileBanking   -> HTTP 2xx
///   3. resendActivationInfo    -> message starts with "Wait for resent SMS/email to arrive"
class RegistrationService {
  RegistrationService([EnrollClient? client]) : _client = client ?? EnrollClient();

  final EnrollClient _client;

  Future<RegistrationResult> run(
    RegistrationData data,
    Uint8List idImage,
    Uint8List personalImage,
  ) async {
    final log = <RegistrationStep>[];

    // 1) PreEnroll
    final idBase64 = compressToBase64(idImage);
    final personalBase64 = compressToBase64(personalImage);
    final preEnrollPayload = {
      'nationalId': data.idNumber,
      'idImage': idBase64,
      'personalImage': personalBase64,
    };
    var result = await _client.post('pre_enroll', preEnrollPayload);
    var desc = EnrollClient.find(result.json, 'desc');
    var ok = desc != null && desc.trim().startsWith(EnrollConfig.successPreEnroll);
    log.add(_entry('PreEnroll', result, ok));
    if (!ok) {
      return _fail('فشل رفع الصور (PreEnroll): ${_reason(result, desc)}', log);
    }

    // 2) EnrollInMobileBanking
    result = await _client.post('enroll', data.toEnrollPayload());
    ok = result.error == null && (result.status ?? 0) >= 200 && (result.status ?? 0) < 300;
    log.add(_entry('EnrollInMobileBanking', result, ok));
    if (!ok) {
      return _fail('فشل إرسال البيانات (EnrollInMobileBanking): ${_reason(result)}', log);
    }

    // 3) resendActivationInfo
    result = await _client.post('resend', data.toResendPayload());
    final message = EnrollClient.find(result.json, 'message');
    ok = message != null && message.trim().startsWith(EnrollConfig.successResend);
    log.add(_entry('resendActivationInfo', result, ok));
    if (!ok) {
      return _fail('لم تتم عملية التسجيل (resendActivationInfo): ${_reason(result, message)}', log);
    }

    return RegistrationResult(
      ok: true,
      message: 'تمت عملية التسجيل بنجاح',
      log: log,
      idImageBase64: idBase64,
      personalImageBase64: personalBase64,
    );
  }

  RegistrationResult _fail(String message, List<RegistrationStep> log) =>
      RegistrationResult(ok: false, message: message, log: log);

  RegistrationStep _entry(String step, EnrollResult r, bool ok) => RegistrationStep(
        step: step,
        ok: ok,
        status: r.status,
        reason: ok ? null : _reason(r),
        response: _limit(r.error ?? r.raw, 2000),
      );

  /// The upstream's own explanation: its "message" field, or "desc" when none.
  String? _errorMessage(EnrollResult r) =>
      EnrollClient.find(r.json, 'message') ?? EnrollClient.find(r.json, 'desc');

  String _reason(EnrollResult r, [String? text]) {
    if (r.error != null) {
      return 'تعذر الاتصال بالخادم: ${r.error}';
    }
    text ??= _errorMessage(r) ?? (r.raw.trim().isEmpty ? 'لا يوجد رد من الخادم' : _limit(r.raw, 300));
    return 'HTTP ${r.status} - $text';
  }

  String _limit(String s, int n) => s.length > n ? '${s.substring(0, n)}...' : s;
}
