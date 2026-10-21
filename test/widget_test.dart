import 'package:flutter_test/flutter_test.dart';
import 'package:decibel/main.dart';

void main() {
  testWidgets('DecibelApp smoke test', (WidgetTester tester) async {
    expect(const DecibelApp(), isNotNull);
  });
}
