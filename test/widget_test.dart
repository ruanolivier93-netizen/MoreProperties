import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:more_properties/screens/shell.dart';
import 'package:more_properties/theme.dart';

void main() {
  testWidgets(
    'More Properties shell renders the bottom navigation labels',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.build(),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Discover'), findsWidgets);
      expect(find.text('Search'), findsWidgets);
      expect(find.text('Tools'), findsWidgets);
      expect(find.text('Saved'), findsWidgets);
      expect(find.text('Account'), findsWidgets);
    },
  );
}
