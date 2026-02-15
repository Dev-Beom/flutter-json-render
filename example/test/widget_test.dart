import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_json_render_example/main.dart';

void main() {
  testWidgets('showcase app renders scenario selector', (tester) async {
    await tester.pumpWidget(const ShowcaseApp());

    expect(find.text('flutter_json_render Showcase'), findsOneWidget);
    expect(find.text('Scenario'), findsOneWidget);
  });
}
