import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:srishty/main.dart';

void main() {
  testWidgets('Login screen shows branding and credentials fields', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // ProviderScope is required for Riverpod
    await tester.pumpWidget(
      const ProviderScope(
        child: SrishtyApp(),
      ),
    );

    // Verify that the title "Srishty" is present.
    expect(find.text('Srishty'), findsOneWidget);
    
    // Verify that the tagline is present.
    expect(find.text('Your Stories, Amplified.'), findsOneWidget);

    // Verify fields are present.
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify Login button text is present.
    expect(find.text('Login'), findsOneWidget);
  });
}
