import 'package:flutter_test/flutter_test.dart';
import 'package:palpay_mobile/core/palpay_signer.dart';

/// These expected values were generated from the PHP implementation
/// (App\Services\Palpay\PalpaySigner) with fixed inputs, to prove the Dart
/// port signs byte-for-byte identically. If any of these fail, the mobile app
/// would be rejected by PalPay.
void main() {
  const username = '0599123456';
  const salt = 'abc123SALT';
  const password = 'SecretPass!';
  const androidId = 'a1b2c3d4e5f60718';
  const body = '{"account":"090000353286"}';
  const ts = 1700000000;
  const counter = 5;
  const accessToken = 'TOKEN123';

  test('signingKey matches PHP', () {
    expect(
      PalpaySigner.signingKey(username, salt, password),
      'SyGz1H+hfzTaVy9AA97lSpFw6M3jbT5Gn1sjsNomXGs=',
    );
  });

  test('contentMd5 matches PHP', () {
    expect(PalpaySigner.contentMd5(body), 'blrtFHNLXItxa4jKt0bktg==');
    expect(PalpaySigner.contentMd5(''), '');
  });

  test('udid matches PHP', () {
    expect(
      PalpaySigner.udid(androidId),
      'uC78RsBz2dj239Ctc4pwdN93iYR92PBBxi6WAAMjJgw=',
    );
  });

  test('canonical + authorization (user mode) match PHP', () {
    final md5 = PalpaySigner.contentMd5(body);
    final canonical = PalpaySigner.canonical(
      'POST',
      md5,
      ts,
      counter,
      accessToken,
      '/api/v1.0/palpayaccount/getPalPayAccounts',
    );
    expect(
      canonical,
      'POST\nblrtFHNLXItxa4jKt0bktg==\n1700000000\n5\nTOKEN123\n/api/v1.0/palpayaccount/getpalpayaccounts',
    );

    final sk = PalpaySigner.signingKey(username, salt, password);
    expect(
      PalpaySigner.authorization(canonical, ts, counter, sk),
      'MBS_AUTH ARYntze2vNAGJ/oi8++oD7EXtBZXE36E8GQCXMRVl6Q=:1700000000:5',
    );
  });

  test('registration mode produces empty signature', () {
    final canonical = PalpaySigner.canonical(
      'POST',
      '',
      ts,
      0,
      '',
      '/api/v1.0/register/addNewDevice',
    );
    expect(
      canonical,
      'POST\n\n1700000000\n0\n\n/api/v1.0/register/addnewdevice',
    );
    expect(PalpaySigner.authorization(canonical, ts, 0, ''), ':1700000000:0');
  });
}
