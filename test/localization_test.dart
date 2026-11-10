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

  test('normalizes region-specific language codes and falls back safely', () {
    PaperPlaneLocale.setLanguage('de-DE');
    expect(PaperPlaneLocale.current.value.languageCode, 'de');

    PaperPlaneLocale.setLanguage('ja');
    expect(PaperPlaneLocale.current.value.languageCode, 'pt');
  });
}
