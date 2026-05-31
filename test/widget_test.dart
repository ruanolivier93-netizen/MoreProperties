import 'package:flutter_test/flutter_test.dart';
import 'package:more_properties/main.dart';

void main() {
  testWidgets('More Properties renders the mobile marketplace shell', (
    tester,
  ) async {
    await tester.pumpWidget(const MorePropertiesApp());
    await tester.pumpAndSettle();

    expect(find.text('More Properties'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Studio'), findsOneWidget);
  });
}
