import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_plane/main.dart';
import 'package:paper_plane/services/paper_plane_localization.dart';

void main() {
  testWidgets('settings expose the preferred translation language', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pt'),
      supportedLocales: const [Locale('pt')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Idioma preferido dos aviões'), findsOneWidget);
  });

  testWidgets('welcome screen routes to the Firebase account gate', (tester) async {
    PaperPlaneLocale.setLanguage('pt');
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

    // In a widget-test environment Firebase is intentionally not initialised.
    // The app must stop at the real Firebase account gate instead of creating
    // an anonymous/offline pilot or showing demo account data.
    expect(find.text('Firebase ainda não está ativo'), findsOneWidget);
  });
}
