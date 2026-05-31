import 'package:flutter_test/flutter_test.dart';
import 'package:vaultx/main.dart';

void main() {
  testWidgets('VaultX smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VaultXApp());
  });
}
