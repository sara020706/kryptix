import 'package:flutter_test/flutter_test.dart';
import 'package:kryptix/main.dart';

void main() {
  testWidgets('Kryptix smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KryptixApp());
  });
}
