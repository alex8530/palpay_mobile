import 'package:flutter_test/flutter_test.dart';
import 'package:palpay_mobile/main.dart';

void main() {
  testWidgets('opens on the home screen when a token is set by default', (tester) async {
    await tester.pumpWidget(const PalpayApp());
    expect(find.text('الدفع إلى صديق'), findsOneWidget);
    expect(find.text('حساباتي'), findsOneWidget);
  });
}
