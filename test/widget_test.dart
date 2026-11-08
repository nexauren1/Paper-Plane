import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_plane/main.dart';

void main() {
  testWidgets('welcome screen opens the Paper Plane home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PaperPlaneApp());
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('PAPER PLANE'), findsOneWidget);
    expect(find.text('Start Flying'), findsOneWidget);

    await tester.tap(find.text('Start Flying'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Home now loads the pilot profile and counts from the live Worker API.
    // Widget tests verify navigation only and must not expect demo/offline data.
    expect(find.byType(HomePage), findsOneWidget);
  });
}
