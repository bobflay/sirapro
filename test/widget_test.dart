// Basic Flutter widget tests for SiraPro app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirapro/main.dart';

void main() {
  testWidgets('MyApp builds without error', (WidgetTester tester) async {
    // Build the app widget
    await tester.pumpWidget(const MyApp());

    // Verify the app builds and shows a MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('AuthChecker shows loading indicator initially',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthChecker()));

    // Initially should show a loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
