import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caregiver_app/caregiver/caregiver.dart';

void main() {
  testWidgets('The caregiver app opens on the sign-in screen', (WidgetTester tester) async {
    // A phone-sized screen, so the sign-in page lays out like on a device.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CaregiverModule());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
