import 'package:flutter_test/flutter_test.dart';
import 'package:palpay_mobile/main.dart';

void main() {
  testWidgets('opens on the token screen when no token is saved', (tester) async {
    await tester.pumpWidget(const PalpayApp());
    expect(find.text('أدخل التوكن'), findsOneWidget);
  });
}
