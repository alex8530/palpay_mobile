import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:palpay_mobile/core/app_config.dart';
import 'package:palpay_mobile/core/auth_service.dart';
import 'package:palpay_mobile/core/pending_store.dart';
import 'package:palpay_mobile/main.dart';

/// The gate waits up to 2s for secure storage, which has no plugin in tests;
/// let that time pass so no timer is left pending when the test ends.
Future<void> settleGate(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

void main() {
  tearDown(() {
    AuthService.instance.debugSetUser(null);
    AppConfig.instance.debugSet();
  });

  testWidgets('opens on the login screen when nobody is signed in', (tester) async {
    await tester.pumpWidget(const PalpayApp());
    await tester.pump();
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('الدفع إلى صديق'), findsNothing);
    await settleGate(tester);
  });

  testWidgets('an admin gets the full app', (tester) async {
    AuthService.instance.debugSetUser(const AppUser(phone: '0599000000', name: 'Admin', password: 'x', role: 'admin'));
    await tester.pumpWidget(const PalpayApp());
    await tester.pump();
    expect(find.text('الدفع إلى صديق'), findsOneWidget);
    expect(find.text('حساباتي'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('المستخدمين'), 200);
    expect(find.text('المستخدمين'), findsOneWidget);
    await settleGate(tester);
  });

  testWidgets('a regular user only sees registration and their requests', (tester) async {
    AuthService.instance.debugSetUser(const AppUser(phone: '0599111111', name: 'User', password: 'x'));
    await tester.pumpWidget(const PalpayApp());
    await tester.pump();
    expect(find.text('التسجيل'), findsOneWidget);
    expect(find.text('طلباتي'), findsOneWidget);
    expect(find.text('الدفع إلى صديق'), findsNothing);
    expect(find.text('المستخدمين'), findsNothing);
    await settleGate(tester);
  });

  testWidgets('switching the app off locks users but not the admin', (tester) async {
    AuthService.instance.debugSetUser(const AppUser(phone: '0599111111', name: 'User', password: 'x'));
    AppConfig.instance.debugSet(enabled: false);
    await tester.pumpWidget(const PalpayApp());
    await tester.pump();
    // Actually on screen, not just in the tree.
    expect(find.text('التطبيق متوقف').hitTestable(), findsOneWidget);
    expect(tester.getSize(find.text('التطبيق متوقف')).width, greaterThan(0));

    AuthService.instance.debugSetUser(const AppUser(phone: '0599000000', name: 'Admin', password: 'x', role: 'admin'));
    await tester.pump();
    expect(find.text('التطبيق متوقف'), findsNothing);
    await settleGate(tester);
  });

  testWidgets('with the app switched off, the login screen still shows so the admin can get in', (tester) async {
    AppConfig.instance.debugSet(enabled: false);
    await tester.pumpWidget(const PalpayApp());
    await tester.pump(const Duration(seconds: 2)); // let the login screen animate in
    expect(find.text('التطبيق متوقف'), findsNothing);
    expect(find.text('تسجيل الدخول').hitTestable(), findsOneWidget);
    await settleGate(tester);
  });

  testWidgets('the admin message shows to regular users but never to the admin', (tester) async {
    AppConfig.instance.debugSet(message: const AppMessage(id: 'm-test', title: 'تنبيه', body: 'رسالة للمستخدمين'));

    AuthService.instance.debugSetUser(const AppUser(phone: '0599000000', name: 'Admin', password: 'x', role: 'admin'));
    await tester.pumpWidget(const PalpayApp());
    await tester.pump();
    await tester.pump();
    expect(find.text('رسالة للمستخدمين'), findsNothing);

    AuthService.instance.debugSetUser(const AppUser(phone: '0599111111', name: 'User', password: 'x'));
    // The "already seen" list comes from secure storage, which has no
    // plugin in tests; the gate gives up on reading it, then on saving the
    // message as seen, after 2 seconds each.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('رسالة للمستخدمين'), findsOneWidget);
    await settleGate(tester);
  });

  test('reads the admin message and rejects incomplete ones', () {
    final m = AppMessage.fromMap({'id': 'm1', 'title': 'تنبيه', 'body': 'مرحبا', 'dismissible': false})!;
    expect(m.id, 'm1');
    expect(m.button, 'تمام');
    expect(m.dismissible, isFalse);
    expect(m.repeat, isFalse);
    expect(AppMessage.fromMap(null), isNull);
    expect(AppMessage.fromMap({'id': 'x'}), isNull);
    expect(AppMessage.fromMap('not a map'), isNull);
  });

  test('pending requests round-trip per user, with photos', () async {
    final dir = await Directory.systemTemp.createTemp('pending_test');
    addTearDown(() => dir.delete(recursive: true));
    final store = PendingStore.instance..debugDirectory = dir;

    final r = PendingRequest(
      id: 'p1',
      owner: '0599111111',
      form: {'arabicfullname': 'أحمد', 'idNumber': '123456789', 'dobDay': 3},
      updatedAt: DateTime(2026, 10, 21),
      error: 'تعذر الاتصال',
    );
    await store.save(r, idImage: Uint8List.fromList([1, 2, 3]));

    final mine = await store.list('0599111111');
    expect(mine.single.title, 'أحمد');
    expect(mine.single.form['dobDay'], 3);
    expect(mine.single.error, 'تعذر الاتصال');
    expect(await store.list('0599222222'), isEmpty);

    final (idImage, personal) = await store.images('p1');
    expect(idImage, [1, 2, 3]);
    expect(personal, isNull);

    await store.delete('p1');
    expect(await store.list('0599111111'), isEmpty);
  });

  test('normalizes phone numbers to digits', () {
    expect(AuthService.normalizePhone(' 059 912-3456 '), '0599123456');
  });
}
