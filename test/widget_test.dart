import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_plane/main.dart';
import 'package:paper_plane/services/paper_plane_localization.dart';
import 'package:paper_plane/services/paper_plane_api.dart';

void main() {
  testWidgets('settings expose the application language', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pt'),
      supportedLocales: const [Locale('pt')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Idioma da aplicação'), findsOneWidget);
  });



  test('the five UI languages and public visibility normalizer are complete', () {
    expect(PaperPlaneLocale.supportedLanguages, {'pt', 'en', 'es', 'fr', 'de'});

    const expectedWelcome = {
      'pt': 'Um pensamento. Um avião. O mundo inteiro.',
      'en': 'One thought. One plane. The whole world.',
      'es': 'Una idea. Un avión. El mundo entero.',
      'fr': 'Une pensée. Un avion. Le monde entier.',
      'de': 'Ein Gedanke. Ein Flieger. Die ganze Welt.',
    };
    for (final entry in expectedWelcome.entries) {
      PaperPlaneLocale.setLanguage(entry.key);
      expect(PaperPlaneLocale.current.value.languageCode, entry.key);
      expect(
        PaperPlaneLocale.translate('Um pensamento. Um avião. O mundo inteiro.'),
        entry.value,
      );
    }
    PaperPlaneLocale.setLanguage('pt');

    expect(PaperPlaneApi.isPublicVisibility('Público'), isTrue);
    expect(PaperPlaneApi.isPublicVisibility('  PUBLIC  '), isTrue);
    expect(PaperPlaneApi.isPublicVisibility('Open Sky'), isTrue);
    expect(PaperPlaneApi.isPublicVisibility('Aleatório 1-para-1'), isFalse);
  });


  test('dynamic labels and API error messages follow the selected language', () {
    expect(
      PaperPlaneLocale.translate('Traduzir para Deutsch', 'en'),
      'Translate into Deutsch',
    );
    expect(
      PaperPlaneLocale.translate('Traduzir para Français', 'fr'),
      'Traduire en Français',
    );
    expect(
      PaperPlaneLocale.translate('Idioma: Português', 'de'),
      'Sprache: Português',
    );
    expect(
      PaperPlaneLocale.translate('12 XP acumulados', 'en'),
      '12 XP earned',
    );
    expect(
      PaperPlaneLocale.translate('Próximo nível: 80 XP', 'fr'),
      'Niveau suivant : 80 XP',
    );
    expect(
      PaperPlaneLocale.translate(
        'Completa a tua data de nascimento no perfil antes de enviar.',
        'es',
      ),
      'Completa tu fecha de nacimiento en el perfil antes de enviar.',
    );
    expect(
      PaperPlaneLocale.translate(
        'A mensagem ficou retida para revisão de segurança.',
        'de',
      ),
      'Die Nachricht wurde zur Sicherheitsprüfung zurückgehalten.',
    );
    expect(
      PaperPlaneLocale.translate('Abrir carta', 'fr'),
      'Ouvrir la lettre',
    );
    expect(
      PaperPlaneLocale.translate(
        'Tens uma atualização na tua caixa de entrada.',
        'de',
      ),
      'Du hast eine Aktualisierung in deinem Posteingang.',
    );
    expect(
      PaperPlaneLocale.translate(
        'Novos aviões, mensagens e avisos importantes',
        'es',
      ),
      'Nuevos aviones, mensajes y avisos importantes.',
    );
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
    expect(find.text('Começar a voar'), findsOneWidget);

    await tester.tap(find.text('Começar a voar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // In a widget-test environment Firebase is intentionally not initialised.
    // The app must stop at the real Firebase account gate instead of creating
    // an anonymous/offline pilot or showing demo account data.
    expect(find.text('Firebase ainda não está ativo'), findsOneWidget);
  });
}
