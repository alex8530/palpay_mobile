import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:palpay_mobile/core/enroll_client.dart';
import 'package:palpay_mobile/core/enroll_config.dart';
import 'package:palpay_mobile/core/enroll_images.dart';
import 'package:palpay_mobile/core/lookups.dart';
import 'package:palpay_mobile/core/registration_service.dart';
import 'package:palpay_mobile/screens/registration_screen.dart';
import 'package:palpay_mobile/theme/app_theme.dart';

// The registration flow is exercised against a fake upstream (MockClient), never
// the real server: a real run would enroll a real national ID.

const _preEnrollOk = {'desc': 'Your uploaded images have been received'};
const _resendOk = {'message': 'Wait for resent SMS/email to arrive, then activate'};

RegistrationData _data() => RegistrationData(
      fullname: 'Test User',
      arabicfullname: 'مستخدم تجريبي',
      username: '400000000',
      password: 'Aa10203040##',
      mobile: '0590000000',
      email: 'test@gmail.com',
      placeOfBirth: '1995-03-07',
      gender: '1',
      idNumber: '400000000',
      issuanceCountry: '134',
      nationality: '134',
      country: '134',
      region: '2',
      governorate: '5',
      city: '17',
      address: 'غزة',
      jobTitle: '3',
      jobPosition: '9',
      incomeRate: '1000',
      termAccepted: true,
      noOtherWallet: true,
      hasBankAccount: false,
    );

Uint8List _png(int w, int h, {bool alpha = false}) {
  final image = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  img.fill(image, color: alpha ? img.ColorRgba8(120, 40, 200, 90) : img.ColorRgb8(120, 40, 200));
  return Uint8List.fromList(img.encodePng(image));
}

/// Fake upstream: answers each endpoint from [responses] and records requests.
class _Upstream {
  _Upstream(this.responses);

  /// path -> (status, json body) or an Exception to simulate a network error.
  final Map<String, Object> responses;
  final requests = <http.Request>[];

  MockClient get client => MockClient((req) async {
        requests.add(req);
        final r = responses[req.url.path];
        if (r == null) return http.Response('not found', 404);
        if (r is Exception) throw r;
        final (status, body) = r as (int, Object?);
        return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});
      });

  Future<RegistrationResult> run([RegistrationData? data]) => http.runWithClient(
        () => RegistrationService().run(data ?? _data(), _png(40, 30), _png(30, 40)),
        () => client,
      );

  List<String> get paths => [for (final r in requests) r.url.path];
  Map<String, dynamic> body(int i) => jsonDecode(requests[i].body) as Map<String, dynamic>;
}

final _pre = EnrollConfig.endpoints['pre_enroll']!;
final _enroll = EnrollConfig.endpoints['enroll']!;
final _resend = EnrollConfig.endpoints['resend']!;

void main() {
  group('RegistrationService — full flow', () {
    test('success: runs PreEnroll -> Enroll -> resend in order and reports success', () async {
      final up = _Upstream({
        _pre: (200, _preEnrollOk),
        _enroll: (200, {'status': 'ok'}),
        _resend: (200, _resendOk),
      });
      final result = await up.run();

      expect(result.ok, isTrue);
      expect(result.message, 'تمت عملية التسجيل بنجاح');
      expect(up.paths, [_pre, _enroll, _resend]);
      expect(result.log.map((s) => s.step), ['PreEnroll', 'EnrollInMobileBanking', 'resendActivationInfo']);
      expect(result.log.every((s) => s.ok), isTrue);
    });

    test('PreEnroll payload: nationalId + both images as JPEG base64', () async {
      final up = _Upstream({_pre: (200, _preEnrollOk), _enroll: (200, {}), _resend: (200, _resendOk)});
      await up.run();

      final body = up.body(0);
      expect(body.keys, unorderedEquals(['nationalId', 'idImage', 'personalImage']));
      expect(body['nationalId'], '400000000');
      for (final key in ['idImage', 'personalImage']) {
        final bytes = base64.decode(body[key] as String);
        expect(bytes.sublist(0, 2), [0xFF, 0xD8], reason: '$key should be a JPEG');
      }
    });

    test('Enroll payload has the exact upstream shape', () async {
      final up = _Upstream({_pre: (200, _preEnrollOk), _enroll: (200, {}), _resend: (200, _resendOk)});
      await up.run();

      final body = up.body(1);
      expect(body['dob'], '1995-03-07T00:00:00');
      expect(body['placeOfBirth'], '1995-03-07T00:00:00');
      expect(body['id'], '400000000');
      expect(body['idType'], '1');
      expect(body['username'], '400000000');
      expect(body['termAccepted'], isTrue);
      expect(body['noOtherWallet'], isTrue);
      expect(body['hasBankAccount'], isFalse);
      expect(body.keys, containsAll(['fullname', 'arabicfullname', 'password', 'mobile', 'email', 'gender',
          'issuanceCountry', 'nationality', 'country', 'region', 'governorate', 'city', 'address',
          'jobTitle', 'jobPosition', 'incomeRate']));

      expect(up.body(2), {'username': '400000000', 'mobile': '0590000000', 'email': 'test@gmail.com'});
    });

    test('every POST carries matching Content-MD5, unsigned Authorization and the static headers', () async {
      final up = _Upstream({_pre: (200, _preEnrollOk), _enroll: (200, {}), _resend: (200, _resendOk)});
      await up.run();

      for (final r in up.requests) {
        expect(r.method, 'POST');
        expect(r.headers['Content-MD5'], base64.encode(md5.convert(utf8.encode(r.body)).bytes));
        expect(r.headers['Authorization'], matches(RegExp(r'^:\d{10}:0$')));
        expect(r.headers['X-MBS-Udid'], isNotEmpty);
        expect(r.headers['X-PALPAY-Source'], 'WALLET_MOBILE');
        expect(r.headers['X-HISABI-VER'], '2.0');
        expect(r.headers['X-LOGIN-MODE'], '0');
        expect(r.url.toString(), startsWith('https://mahfazatim2.palpay.ps/api/v1.0/register/'));
      }
    });
  });

  group('RegistrationService — failures stop the flow', () {
    test('PreEnroll rejected: stops after step 1 with the server desc', () async {
      final up = _Upstream({
        _pre: (200, {'desc': 'Images are not clear'}),
        _enroll: (200, {}),
        _resend: (200, _resendOk),
      });
      final result = await up.run();

      expect(result.ok, isFalse);
      expect(up.paths, [_pre]);
      expect(result.message, contains('PreEnroll'));
      expect(result.message, contains('Images are not clear'));
      expect(result.log.single.ok, isFalse);
    });

    test('PreEnroll desc nested in the response is still found', () async {
      final up = _Upstream({
        _pre: (200, {'result': {'Desc': 'Your uploaded images are under review'}}),
        _enroll: (200, {}),
        _resend: (200, _resendOk),
      });
      expect((await up.run()).ok, isTrue);
    });

    test('Enroll HTTP 400: stops after step 2 with the server message', () async {
      final up = _Upstream({
        _pre: (200, _preEnrollOk),
        _enroll: (400, {'message': 'Username already exists'}),
        _resend: (200, _resendOk),
      });
      final result = await up.run();

      expect(result.ok, isFalse);
      expect(up.paths, [_pre, _enroll]);
      expect(result.message, contains('EnrollInMobileBanking'));
      expect(result.message, contains('HTTP 400'));
      expect(result.message, contains('Username already exists'));
      expect(result.log.map((s) => s.ok), [true, false]);
    });

    test('resend without the success message: fails at step 3', () async {
      final up = _Upstream({
        _pre: (200, _preEnrollOk),
        _enroll: (200, {}),
        _resend: (200, {'message': 'Too many requests'}),
      });
      final result = await up.run();

      expect(result.ok, isFalse);
      expect(up.paths, [_pre, _enroll, _resend]);
      expect(result.message, contains('resendActivationInfo'));
      expect(result.message, contains('Too many requests'));
    });

    test('network error: reports a connection failure and sends nothing else', () async {
      final up = _Upstream({_pre: const SocketException('Failed host lookup')});
      final result = await up.run();

      expect(result.ok, isFalse);
      expect(up.paths, [_pre]);
      expect(result.message, contains('تعذر الاتصال بالخادم'));
    });

    test('empty server body: reason says there was no response', () async {
      final up = _Upstream({_pre: (502, '')});
      final result = await http.runWithClient(
        () => RegistrationService().run(_data(), _png(10, 10), _png(10, 10)),
        () => MockClient((req) async {
          up.requests.add(req);
          return http.Response('', 502);
        }),
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('HTTP 502'));
      expect(result.message, contains('لا يوجد رد من الخادم'));
    });
  });

  group('Image compression', () {
    test('large photo is scaled to 1280 on its long side and re-encoded as JPEG', () {
      final out = base64.decode(compressToBase64(_png(3000, 2000)));
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 1280);
      expect(decoded.height, closeTo(853, 1));
    });

    test('portrait photo is scaled by height', () {
      final decoded = img.decodeJpg(base64.decode(compressToBase64(_png(1000, 2600))))!;
      expect(decoded.height, 1280);
    });

    test('small photo keeps its size; transparency is flattened', () {
      final decoded = img.decodeJpg(base64.decode(compressToBase64(_png(200, 100, alpha: true))))!;
      expect([decoded.width, decoded.height], [200, 100]);
      expect(decoded.hasAlpha, isFalse);
    });

    test('unreadable bytes throw instead of sending garbage', () {
      expect(() => compressToBase64(Uint8List.fromList([1, 2, 3, 4])), throwsException);
    });
  });

  group('Lookups (dropdown lists)', () {
    test('getLookup parses {id,name}, drops malformed rows and sends the parent query', () async {
      late Uri seen;
      final items = await http.runWithClient(
        () => EnrollClient().getLookup('/api/v1.0/info/cities', {'govid': '5'}),
        () => MockClient((req) async {
          seen = req.url;
          return http.Response(
            jsonEncode([
              {'id': 17, 'name': 'غزة'},
              {'id': 18, 'name': 'خانيونس'},
              {'name': 'no id'},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(seen.queryParameters, {'govid': '5'});
      expect(items, [
        {'id': '17', 'name': 'غزة'},
        {'id': '18', 'name': 'خانيونس'},
      ]);
    });

    test('getLookup throws on an error status or a non-list body', () async {
      Future<void> call(http.Response res) => http.runWithClient(
            () => EnrollClient().getLookup('/api/v1.0/info/countries', {}),
            () => MockClient((_) async => res),
          );
      await expectLater(call(http.Response('[]', 500)), throwsException);
      await expectLater(call(http.Response('{"a":1}', 200)), throwsException);
    });

    test('child lists without a parent are empty (no request); regions are fixed', () async {
      expect(await Lookups.options('governorates'), isEmpty);
      expect(await Lookups.options('cities', ''), isEmpty);
      expect(Lookups.regions().map((o) => o.id), ['1', '2']);
    });
  });

  group('EnrollClient.find', () {
    test('finds scalar keys case-insensitively at any depth, including inside lists', () {
      final json = {
        'outer': [
          {'x': 1},
          {'inner': {'MESSAGE': 'deep'}},
        ],
      };
      expect(EnrollClient.find(json, 'message'), 'deep');
      expect(EnrollClient.find(json, 'missing'), isNull);
      expect(EnrollClient.find({'message': {'not': 'scalar'}}, 'message'), isNull);
    });
  });

  group('Registration screen', () {
    testWidgets('submitting an empty form lists what is missing and sends nothing', (tester) async {
      var sent = 0;
      await http.runWithClient(() async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: const Directionality(textDirection: TextDirection.rtl, child: RegistrationScreen()),
        ));
        await tester.pump(const Duration(seconds: 1));

        final submit = find.text('إرسال الطلب والتسجيل');
        await tester.scrollUntilVisible(submit, 400, scrollable: find.byType(Scrollable).first);
        await tester.tap(submit);
        await tester.pump(const Duration(seconds: 1));

        expect(find.textContaining('أرفق صورة الهوية والصورة الشخصية'), findsOneWidget);
        expect(find.textContaining('يجب الموافقة على الشروط والأحكام'), findsOneWidget);
      }, () => MockClient((req) async {
            if (req.method == 'POST') sent++;
            return http.Response('[]', 200, headers: {'content-type': 'application/json'});
          }));
      expect(sent, 0);
    });
  });
}
