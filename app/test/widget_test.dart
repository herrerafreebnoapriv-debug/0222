import 'package:flutter_test/flutter_test.dart';
import 'package:mop_app/main.dart';

void main() {
  testWidgets('登录页展示用户须知与登录按钮', (WidgetTester tester) async {
    await tester.pumpWidget(const MopApp());
    await tester.pumpAndSettle();
    expect(find.text('登录'), findsOneWidget);
  });
}
