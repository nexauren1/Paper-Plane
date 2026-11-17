import 'package:flutter_test/flutter_test.dart';
import 'package:paper_plane/services/paper_plane_localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => PaperPlaneLocale.setLanguage('pt'));
  tearDown(() => PaperPlaneLocale.setLanguage('pt'));

  test('supports all five launch languages', () {
    const languages = ['pt', 'en', 'es', 'fr', 'de'];
    for (final language in languages) {
      PaperPlaneLocale.setLanguage(language);
      expect(PaperPlaneLocale.current.value.languageCode, language);
    }
  });

  test('translates shared interface text in English, Spanish, French and German', () {
    PaperPlaneLocale.setLanguage('en');
    expect(PaperPlaneLocale.translate('Ajuda e suporte'), 'Help and support');

    PaperPlaneLocale.setLanguage('es');
    expect(PaperPlaneLocale.translate('Ajuda e suporte'), 'Ayuda y soporte');

    PaperPlaneLocale.setLanguage('fr');
    expect(PaperPlaneLocale.translate('Ajuda e suporte'), 'Aide et assistance');

    PaperPlaneLocale.setLanguage('de');
    expect(PaperPlaneLocale.translate('Ajuda e suporte'), 'Hilfe und Support');
  });

  test('preserves Portuguese and translates dynamic flight counters', () {
    PaperPlaneLocale.setLanguage('pt');
    expect(PaperPlaneLocale.translate('Ajuda e suporte'), 'Ajuda e suporte');

    PaperPlaneLocale.setLanguage('en');
    expect(PaperPlaneLocale.translate('10 XP acumulados'), '10 XP earned');
  });

  test('translates generated math and geography questions', () {
    PaperPlaneLocale.setLanguage('en');
    expect(PaperPlaneLocale.translate('Quanto é 8 × 9?'), 'What is 8 × 9?');
    expect(PaperPlaneLocale.translate('5 multiplicado por 6 é igual a 30.'), '5 multiplied by 6 equals 30.');
    expect(PaperPlaneLocale.translate('Qual é a capital de Moçambique?'), 'What is the capital of Mozambique?');
  });

  test('translates category counters and country names while preserving flags', () {
    PaperPlaneLocale.setLanguage('en');
    expect(PaperPlaneLocale.translate('Matemática · 221'), 'Mathematics · 221');
    expect(PaperPlaneLocale.translate('🇲🇿 Moçambique'), '🇲🇿 Mozambique');

    PaperPlaneLocale.setLanguage('fr');
    expect(PaperPlaneLocale.translate('Geografia'), 'Géographie');
  });


  test('translates every primary tab and new reference-screen label', () {
    const translations = <String, List<String>>{
      'Início': ['Home', 'Inicio', 'Accueil', 'Startseite'],
      'Explorar': ['Explore', 'Explorar', 'Explorer', 'Entdecken'],
      'Amigos': ['Friends', 'Amigos', 'Amis', 'Freunde'],
      'Mais': ['More', 'Más', 'Plus', 'Mehr'],
      'Enviar mensagem': ['Send a Message', 'Enviar un mensaje', 'Envoyer un message', 'Nachricht senden'],
      'Caixa de entrada': ['Inbox', 'Bandeja de entrada', 'Boîte de réception', 'Posteingang'],
      'Definições': ['Settings', 'Ajustes', 'Paramètres', 'Einstellungen'],
      'Atlas mundial': ['World Atlas', 'Atlas mundial', 'Atlas du monde', 'Weltatlas'],
      'Quiz do mundo': ['Quiz World', 'Quiz del mundo', 'Quiz du monde', 'Welt-Quiz'],
      'Coleções de voos': ['Flight Collections', 'Colecciones de vuelos', 'Collections de vols', 'Flugsammlungen'],
    };

    for (final entry in translations.entries) {
      expect(PaperPlaneLocale.translate(entry.key, 'pt'), entry.key);
      for (var index = 0; index < 4; index++) {
        const languages = ['en', 'es', 'fr', 'de'];
        expect(
          PaperPlaneLocale.translate(entry.key, languages[index]),
          entry.value[index],
          reason: '${entry.key} should be translated in ${languages[index]}',
        );
      }
    }
  });

  test('translates the full Home and composer messaging in every supported language', () {
    const strings = [
      'O teu mundo, a uma mensagem de distância.',
      'Descobre pessoas, ideias e culturas em todo o mundo.',
      'Escreve uma mensagem e deixa-a voar pelo mundo.',
      'Ligações sem fronteiras',
      'Um avião pode aproximar pessoas de qualquer parte do mundo.',
      'Mensagens públicas',
      'Joga e ganha XP',
      'Voos em andamento',
      'Descobre mais do mundo',
      'Segurança e privacidade',
    ];
    for (final source in strings) {
      expect(PaperPlaneLocale.translate(source, 'pt'), source);
      for (final language in ['en', 'es', 'fr', 'de']) {
        expect(
          PaperPlaneLocale.translate(source, language),
          isNot(source),
          reason: '"$source" must not fall back to Portuguese in $language',
        );
      }
    }
  });

  test('translates the fallback pilot label before composing the greeting', () {
    expect(
      PaperPlaneLocale.translate('Olá, ', 'en') + PaperPlaneLocale.translate('Piloto', 'en'),
      'Hello, Pilot',
    );
    expect(
      PaperPlaneLocale.translate('Olá, ', 'de') + PaperPlaneLocale.translate('Piloto', 'de'),
      'Hallo, Pilot',
    );
  });


  test('resets a previous account language to the device default', () {
    PaperPlaneLocale.setLanguage('fr');
    PaperPlaneLocale.resetToDeviceLanguage();
    final deviceCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final expected = PaperPlaneLocale.supportedLanguages.contains(deviceCode)
        ? deviceCode
        : 'pt';
    expect(PaperPlaneLocale.current.value.languageCode, expected);
  });

  test('translates account-switch protection message', () {
    const message = 'A conta mudou durante a operação. Aguarda a atualização e tenta novamente.';
    expect(PaperPlaneLocale.translate(message, 'pt'), message);
    expect(
      PaperPlaneLocale.translate(message, 'en'),
      'The account changed during this operation. Wait for the refresh and try again.',
    );
    expect(
      PaperPlaneLocale.translate(message, 'fr'),
      'Le compte a changé pendant cette opération. Attends l’actualisation et réessaie.',
    );
  });

  test('normalizes region-specific language codes and falls back safely', () {
    PaperPlaneLocale.setLanguage('de-DE');
    expect(PaperPlaneLocale.current.value.languageCode, 'de');

    PaperPlaneLocale.setLanguage('ja');
    expect(PaperPlaneLocale.current.value.languageCode, 'pt');
  });
}
