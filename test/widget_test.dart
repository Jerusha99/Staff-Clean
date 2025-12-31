// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staff_cleaning/main.dart';

void main() {
  testWidgets('App starts at Login Screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StaffCleaningApp());

    // Verify that the Login screen is shown.
    expect(find.text('Staff Cleaning Login'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
  });
}