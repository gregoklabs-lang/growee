import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/home/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // This test documents that each tap updates the selected index and page.
  testWidgets('tapping bottom navigation items updates the visible page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    final tabs = [
      ('Dashboard', 'Dashboard Principal'),
      ('Modify', 'Modify Page'),
      ('History', 'History Page'),
      ('Devices', 'No hay dispositivos añadidos'),
    ];

    for (var index = 0; index < tabs.length; index++) {
      final (label, expectedText) = tabs[index];

      if (index > 0) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      final navBar =
          tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));

      expect(navBar.currentIndex, index);
      expect(find.text(expectedText), findsOneWidget);
    }
  });
}