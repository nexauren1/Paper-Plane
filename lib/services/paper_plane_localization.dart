import 'package:flutter/material.dart';

/// Locale used by the customer-facing Paper Plane application.
/// The Admin app remains independent and is intentionally not changed here.
class PaperPlaneLocale {
  PaperPlaneLocale._();

  static const supportedLanguages = <String>{'pt', 'en', 'es', 'fr', 'de'};

  static Locale _deviceLocale() {
    final language = WidgetsBinding.instance.platformDispatcher.locale.languageCode.toLowerCase();
    return Locale(supportedLanguages.contains(language) ? language : 'pt');
  }

  static final ValueNotifier<Locale> current = ValueNotifier<Locale>(_deviceLocale());

  static void setLanguage(String? language) {
    final code = (language ?? '').toLowerCase().split('-').first;
    current.value = Locale(supportedLanguages.contains(code) ? code : 'pt');
  }

  static String translate(String source, [String? language]) {
    final code = language ?? current.value.languageCode;
    final values = _translations[source];
    if (values != null) {
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      return index == null ? source : values[index];
    }

    // Preserve country flags while translating the country name beside them.
    final runes = source.runes.toList();
    if (runes.length > 2 &&
        runes[0] >= 127462 && runes[0] <= 127487 &&
        runes[1] >= 127462 && runes[1] <= 127487 &&
        runes[2] == 32) {
      final flag = String.fromCharCodes(runes.take(2));
      final country = source.substring(flag.length + 1);
      return flag + ' ' + translate(country, code);
    }

    // Preserve user-provided values while translating common dynamic prefixes.
    const prefixes = <String, List<String>>{
      'Olá, ': ['Hello, ', 'Hola, ', 'Bonjour, ', 'Hallo, '],
      'Idioma preferido alterado para ': [
        'Preferred language changed to ', 'Idioma preferido cambiado a ',
        'Langue préférée modifiée en ', 'Bevorzugte Sprache geändert zu ',
      ],
      'De: Alguém em ': ['From someone in ', 'De alguien en ', 'De quelqu’un à ', 'Von jemandem aus '],
    };
    for (final entry in prefixes.entries) {
      if (source.startsWith(entry.key)) {
        final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
        if (index != null) return entry.value[index] + source.substring(entry.key.length);
      }
    }
    final dynamicTranslations = <String, List<String>>{
      'Traduzir para ': ['Translate into ', 'Traducir al ', 'Traduire en ', 'Übersetzen nach '],
      'Idioma: ': ['Language: ', 'Idioma: ', 'Langue : ', 'Sprache: '],
      'Alguém em ': ['Someone in ', 'Alguien en ', 'Quelqu’un à ', 'Jemand aus '],
      'Responder · ': ['Reply · ', 'Responder · ', 'Répondre · ', 'Antworten · '],
      'Lançado ': ['Launched ', 'Lanzado ', 'Lancé ', 'Gestartet '],
      'Recebido · ': ['Received · ', 'Recibido · ', 'Reçu · ', 'Erhalten · '],
    };
    for (final entry in dynamicTranslations.entries) {
      if (source.startsWith(entry.key)) {
        final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
        if (index != null) return entry.value[index] + source.substring(entry.key.length);
      }
    }

    final categoryCount = RegExp(r'^(.+) · ([0-9]+)$').firstMatch(source);
    if (categoryCount != null) {
      final category = translate(categoryCount.group(1)!, code);
      if (category != categoryCount.group(1)) {
        return category + ' · ' + categoryCount.group(2)!;
      }
    }

    final streak = RegExp(r'^([0-9]+) seguidas$').firstMatch(source);
    if (streak != null) {
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const labels = ['in a row', 'seguidas', 'd’affilée', 'in Folge'];
      if (index != null) return streak.group(1)! + ' ' + labels[index];
    }

    final claimed = RegExp(r'^([0-9]+)/([0-9]+) resgatadas$').firstMatch(source);
    if (claimed != null) {
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const labels = ['claimed', 'reclamadas', 'récupérées', 'eingelöst'];
      if (index != null) return claimed.group(1)! + '/' + claimed.group(2)! + ' ' + labels[index];
    }

    final availableQuestions = RegExp(r'^([0-9]+) perguntas disponíveis nesta categoria$').firstMatch(source);
    if (availableQuestions != null) {
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const labels = [
        'questions available in this category',
        'preguntas disponibles en esta categoría',
        'questions disponibles dans cette catégorie',
        'Fragen in dieser Kategorie verfügbar',
      ];
      if (index != null) return availableQuestions.group(1)! + ' ' + labels[index];
    }

    final offlineQuestionCount = RegExp(r'^([0-9]+) perguntas offline, oito áreas de conhecimento e novas rondas aleatórias de dez perguntas\.$').firstMatch(source);
    if (offlineQuestionCount != null) {
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const labels = [
        'offline questions, eight knowledge areas and new random rounds of ten questions.',
        'preguntas sin conexión, ocho áreas de conocimiento y nuevas rondas aleatorias de diez preguntas.',
        'questions hors ligne, huit domaines de connaissance et de nouvelles manches aléatoires de dix questions.',
        'Offline-Fragen, acht Wissensbereiche und neue zufällige Runden mit zehn Fragen.',
      ];
      if (index != null) return offlineQuestionCount.group(1)! + ' ' + labels[index];
    }

    final multiplication = RegExp(r'^Quanto é ([0-9]+) × ([0-9]+)\?$').firstMatch(source);
    if (multiplication != null) {
      final a = multiplication.group(1)!;
      final b = multiplication.group(2)!;
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const labels = ['What is ', '¿Cuánto es ', 'Combien font ', 'Wie viel ist '];
      if (index != null) return labels[index] + a + ' × ' + b + '?';
    }

    final addition = RegExp(r'^Quanto é ([0-9]+) \+ ([0-9]+)\?$').firstMatch(source);
    if (addition != null) {
      final a = addition.group(1)!;
      final b = addition.group(2)!;
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const labels = ['What is ', '¿Cuánto es ', 'Combien font ', 'Wie viel ist '];
      if (index != null) return labels[index] + a + ' + ' + b + '?';
    }

    final multiplicationExplanation = RegExp(r'^([0-9]+) multiplicado por ([0-9]+) é igual a ([0-9]+)\.$').firstMatch(source);
    if (multiplicationExplanation != null) {
      final a = multiplicationExplanation.group(1)!;
      final b = multiplicationExplanation.group(2)!;
      final result = multiplicationExplanation.group(3)!;
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const starts = [' multiplied by ', ' multiplicado por ', ' multiplié par ', ' mal '];
      const joins = [' equals ', ' es igual a ', ' est égal à ', ' ergibt '];
      if (index != null) return a + starts[index] + b + joins[index] + result + '.';
    }

    final sumExplanation = RegExp(r'^A soma de ([0-9]+) com ([0-9]+) é ([0-9]+)\.$').firstMatch(source);
    if (sumExplanation != null) {
      final a = sumExplanation.group(1)!;
      final b = sumExplanation.group(2)!;
      final result = sumExplanation.group(3)!;
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const starts = ['The sum of ', 'La suma de ', 'La somme de ', 'Die Summe aus '];
      const middles = [' plus ', ' con ', ' et ', ' und '];
      const ends = [' is ', ' es ', ' est ', ' ist '];
      if (index != null) return starts[index] + a + middles[index] + b + ends[index] + result + '.';
    }

    final capitalQuestion = RegExp(r'^Qual é a capital de (.+)\?$').firstMatch(source);
    if (capitalQuestion != null) {
      final country = translate(capitalQuestion.group(1)!, code);
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const starts = ['What is the capital of ', '¿Cuál es la capital de ', 'Quelle est la capitale de ', 'Was ist die Hauptstadt von '];
      if (index != null) return starts[index] + country + '?';
    }

    final capitalExplanation = RegExp(r'^(.+) é a capital de (.+)\.$').firstMatch(source);
    if (capitalExplanation != null) {
      final capital = translate(capitalExplanation.group(1)!, code);
      final country = translate(capitalExplanation.group(2)!, code);
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const joins = [' is the capital of ', ' es la capital de ', ' est la capitale de ', ' ist die Hauptstadt von '];
      if (index != null) return capital + joins[index] + country + '.';
    }

    final numeric = RegExp(r'^([0-9]+) (XP acumulados|destinatário\(s\) elegível\(is\) neste momento|aviões nesta Chama)$').firstMatch(source);
    if (numeric != null) {
      final count = numeric.group(1)!;
      final phrase = numeric.group(2);
      final translated = switch (phrase) {
        'XP acumulados' => const ['XP earned', 'XP acumulados', 'XP gagnés', 'gesammelte XP'],
        'destinatário(s) elegível(is) neste momento' => const [
          'eligible recipient(s) right now', 'destinatario(s) elegible(s) ahora',
          'destinataire(s) admissible(s) actuellement', 'geeignete Empfänger derzeit',
        ],
        _ => const ['planes in this Chama', 'aviones en esta Chama', 'avions dans cette Chama', 'Papierflieger in dieser Chama'],
      };
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      if (index != null) return count + ' ' + translated[index];
    }

    final nextLevel = RegExp(r'^Próximo nível: ([0-9]+) XP$').firstMatch(source);
    if (nextLevel != null) {
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      const labels = ['Next level: ', 'Próximo nivel: ', 'Niveau suivant : ', 'Nächstes Level: '];
      if (index != null) return labels[index] + nextLevel.group(1)! + ' XP';
    }
    final gainedXp = RegExp(r'^\+?([0-9]+) XP$').firstMatch(source);
    if (gainedXp != null) {
      final prefix = source.startsWith('+') ? '+' : '';
      return prefix + gainedXp.group(1)! + ' XP';
    }

    final conversation = RegExp(r'^A conversa com (.+) será removida da tua lista\. A outra pessoa continuará a ter a sua cópia\.$').firstMatch(source);
    if (conversation != null) {
      const lead = ['The conversation with ', 'La conversación con ', 'La conversation avec ', 'Die Unterhaltung mit '];
      const tail = [
        ' will be removed from your list. The other person will keep their copy.',
        ' se quitará de tu lista. La otra persona conservará su copia.',
        ' sera retirée de ta liste. L’autre personne conservera sa copie.',
        ' wird aus deiner Liste entfernt. Die andere Person behält ihre Kopie.',
      ];
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      if (index != null) return lead[index] + conversation.group(1)! + tail[index];
    }

    final friend = RegExp(r'^Queres remover @(.+) da tua lista de amigos\? A conversa Chama não será apagada\.$').firstMatch(source);
    if (friend != null) {
      const lead = ['Do you want to remove @', '¿Quieres quitar a @', 'Veux-tu retirer @', 'Möchtest du @'];
      const tail = [
        ' from your friends list? The Chama conversation will not be deleted.',
        ' de tu lista de amigos? La conversación Chama no se eliminará.',
        ' de ta liste d’amis ? La conversation Chama ne sera pas supprimée.',
        ' aus deiner Freundesliste entfernen? Die Chama-Unterhaltung wird nicht gelöscht.',
      ];
      final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
      if (index != null) return lead[index] + friend.group(1)! + tail[index];
    }
    return source;
  }

  static const Map<String, List<String>> _translations = {
    'Abrir Chat': ['Open Chat', 'Abrir Chat', 'Ouvrir le Chat', 'Chat öffnen'],
    'Ver voo': ['View flight', 'Ver vuelo', 'Voir le vol', 'Flug ansehen'],
    'Início': ['Home', 'Inicio', 'Accueil', 'Startseite'],
    'Começar a voar': [
      'Start Flying',
      'Empezar a volar',
      'Commencer à voler',
      'Jetzt losfliegen',
    ],
    'Envia uma mensagem e descobre o mundo.': [
      'Send a message and discover the world.',
      'Envía un mensaje y descubre el mundo.',
      'Envoie un message et découvre le monde.',
      'Sende eine Nachricht und entdecke die Welt.',
    ],
    'Idioma da aplicação': [
      'App language',
      'Idioma de la aplicación',
      'Langue de l’application',
      'App-Sprache',
    ],
    'A aplicação, os aviões recebidos e as notificações usam este idioma.': [
      'The app, incoming planes and notifications use this language.',
      'La aplicación, los aviones recibidos y las notificaciones usan este idioma.',
      'L’application, les avions reçus et les notifications utilisent cette langue.',
      'Die App, eingehende Papierflieger und Benachrichtigungen verwenden diese Sprache.',
    ],
    'O teu avião foi guardado e aguarda a verificação automática. Aparecerá no Open Sky se for aprovado.': [
      'Your plane has been saved and is waiting for the automatic safety check. It will appear in Open Sky if approved.',
      'Tu avión se ha guardado y espera la comprobación automática de seguridad. Aparecerá en Open Sky si se aprueba.',
      'Ton avion a été enregistré et attend la vérification automatique de sécurité. Il apparaîtra dans Open Sky s’il est approuvé.',
      'Dein Papierflieger wurde gespeichert und wartet auf die automatische Sicherheitsprüfung. Bei Freigabe erscheint er in Open Sky.',
    ],
    'A tua publicação foi retida para revisão da equipa. Só aparecerá no Open Sky se for aprovada.': [
      'Your post has been held for team review. It will appear in Open Sky only if approved.',
      'Tu publicación está retenida para que el equipo la revise. Solo aparecerá en Open Sky si se aprueba.',
      'Ta publication a été retenue pour examen par l’équipe. Elle apparaîtra dans Open Sky uniquement si elle est approuvée.',
      'Dein Beitrag wurde zur Prüfung durch das Team zurückgehalten. Er erscheint nur nach Freigabe in Open Sky.',
    ],
    'O servidor recebeu o pedido, mas ainda não confirmou a publicação. Atualiza o Open Sky mais tarde.': [
      'The server received the request, but publication is not confirmed yet. Refresh Open Sky later.',
      'El servidor recibió la solicitud, pero todavía no confirmó la publicación. Actualiza Open Sky más tarde.',
      'Le serveur a reçu la demande, mais la publication n’est pas encore confirmée. Actualise Open Sky plus tard.',
      'Der Server hat die Anfrage erhalten, die Veröffentlichung aber noch nicht bestätigt. Aktualisiere Open Sky später.',
    ],
    'Um pensamento. Um avião. O mundo inteiro.': [
      'One thought. One plane. The whole world.',
      'Una idea. Un avión. El mundo entero.',
      'Une pensée. Un avion. Le monde entier.',
      'Ein Gedanke. Ein Flieger. Die ganze Welt.',
    ],
    'O teu correio digital está ligado ao mundo.': [
      'Your digital mailbox is connected to the world.',
      'Tu correo digital está conectado con el mundo.',
      'Ta boîte aux lettres numérique est reliée au monde.',
      'Dein digitales Postfach ist mit der Welt verbunden.',
    ],
    'Tentar novamente': ['Try again', 'Intentar de nuevo', 'Réessayer', 'Erneut versuchen'],
    'Completa o teu perfil de copiloto': [
      'Complete your co-pilot profile', 'Completa tu perfil de copiloto',
      'Complète ton profil de copilote', 'Vervollständige dein Co-Pilot-Profil',
    ],
    'Escolhe o teu nome único, ano de nascimento e país para preparar a rota.': [
      'Choose your unique name, birth year and country to prepare your route.',
      'Elige tu nombre único, año de nacimiento y país para preparar la ruta.',
      'Choisis ton nom unique, ton année de naissance et ton pays pour préparer ton itinéraire.',
      'Wähle deinen eindeutigen Namen, dein Geburtsjahr und dein Land, um die Route vorzubereiten.',
    ],
    'O teu primeiro avião está pronto': [
      'Your first plane is ready', 'Tu primer avión está listo',
      'Ton premier avion est prêt', 'Dein erster Papierflieger ist bereit',
    ],
    'Não tens aviões em viagem neste momento.': [
      'You have no planes in flight right now.',
      'No tienes aviones en vuelo en este momento.',
      'Tu n’as aucun avion en vol pour le moment.',
      'Du hast derzeit keine Papierflieger unterwegs.',
    ],
    'Os totais e os estados acima são carregados da conta e do servidor.': [
      'The totals and statuses above are loaded from your account and the server.',
      'Los totales y estados anteriores se cargan desde tu cuenta y el servidor.',
      'Les totaux et les états ci-dessus proviennent de ton compte et du serveur.',
      'Die obigen Gesamtzahlen und Statusangaben stammen aus deinem Konto und vom Server.',
    ],
    'Escreve uma mensagem antes de lançar o avião.': [
      'Write a message before launching the plane.',
      'Escribe un mensaje antes de lanzar el avión.',
      'Écris un message avant de lancer l’avion.',
      'Schreibe eine Nachricht, bevor du den Papierflieger startest.',
    ],
    'Não foi possível iniciar: liga a configuração Firebase e o servidor Cloudflare.': [
      'Could not start: check the Firebase configuration and Cloudflare server.',
      'No se pudo iniciar: comprueba la configuración de Firebase y el servidor de Cloudflare.',
      'Impossible de démarrer : vérifie la configuration Firebase et le serveur Cloudflare.',
      'Start nicht möglich: Überprüfe die Firebase-Konfiguration und den Cloudflare-Server.',
    ],
    'Avião publicado no Open Sky.': [
      'Plane published on Open Sky.', 'Avión publicado en Open Sky.',
      'Avion publié sur Open Sky.', 'Papierflieger auf Open Sky veröffentlicht.',
    ],
    'Público': ['Public', 'Público', 'Public', 'Öffentlich'],
    'Aleatório': ['Random', 'Aleatorio', 'Aléatoire', 'Zufällig'],
    'Destino': ['Destination', 'Destino', 'Destination', 'Ziel'],
    'Permitir resposta': ['Allow replies', 'Permitir respuestas', 'Autoriser les réponses', 'Antworten erlauben'],
    'A pessoa poderá responder com outro avião.': [
      'The recipient can reply with another plane.',
      'La persona podrá responder con otro avión.',
      'La personne pourra répondre avec un autre avion.',
      'Die Person kann mit einem weiteren Papierflieger antworten.',
    ],
    'Escolher destino': ['Choose destination', 'Elegir destino', 'Choisir la destination', 'Ziel auswählen'],
    'Qualquer lugar do mundo': ['Anywhere in the world', 'Cualquier lugar del mundo', 'N’importe où dans le monde', 'Überall auf der Welt'],
    'Japão': ['Japan', 'Japón', 'Japon', 'Japan'],
    'Portugal': ['Portugal', 'Portugal', 'Portugal', 'Portugal'],
    'Brasil': ['Brazil', 'Brasil', 'Brésil', 'Brasilien'],
    'A preparar o teu avião...': [
      'Preparing your plane...', 'Preparando tu avión...',
      'Préparation de ton avion…', 'Dein Papierflieger wird vorbereitet…',
    ],
    'A dobrar a mensagem e preparar o voo.': [
      'Folding your message and preparing the flight.',
      'Doblamos tu mensaje y preparamos el vuelo.',
      'Nous plions ton message et préparons le vol.',
      'Deine Nachricht wird gefaltet und der Flug vorbereitet.',
    ],
    'Cancelar avião?': ['Cancel this plane?', '¿Cancelar el avión?', 'Annuler cet avion ?', 'Papierflieger abbrechen?'],
    'Cancelar voo': ['Cancel flight', 'Cancelar vuelo', 'Annuler le vol', 'Flug abbrechen'],
    'O avião foi cancelado.': ['The plane was cancelled.', 'El avión se canceló.', 'L’avion a été annulé.', 'Der Papierflieger wurde abgebrochen.'],
    'Eliminar do histórico?': ['Remove from history?', '¿Eliminar del historial?', 'Retirer de l’historique ?', 'Aus dem Verlauf entfernen?'],
    'Manter': ['Keep', 'Mantener', 'Garder', 'Behalten'],
    'Eliminar': ['Delete', 'Eliminar', 'Supprimer', 'Löschen'],
    'A tua carta está guardada em segurança.': [
      'Your letter is safely stored.', 'Tu carta está guardada de forma segura.',
      'Ta lettre est conservée en sécurité.', 'Dein Brief ist sicher gespeichert.',
    ],
    'O avião continua à procura de um destinatário elegível.': [
      'Your plane is still looking for an eligible recipient.',
      'Tu avión sigue buscando un destinatario apto.',
      'Ton avion cherche toujours un destinataire admissible.',
      'Dein Papierflieger sucht weiterhin nach einem geeigneten Empfänger.',
    ],
    'Percurso do avião': ['Flight route', 'Ruta del avión', 'Trajet de l’avion', 'Flugroute'],
    'A tua caixa': ['Your inbox', 'Tu bandeja de entrada', 'Ta boîte de réception', 'Dein Posteingang'],
    'Correio sincronizado com o servidor': [
      'Mailbox synced with the server', 'Correo sincronizado con el servidor',
      'Boîte synchronisée avec le serveur', 'Postfach mit dem Server synchronisiert',
    ],
    'Ainda não recebeste aviões. Quando uma carta chegar, aparecerá aqui.': [
      'You have not received any planes yet. New letters will appear here.',
      'Todavía no has recibido aviones. Cuando llegue una carta, aparecerá aquí.',
      'Tu n’as pas encore reçu d’avion. Une lettre apparaîtra ici à son arrivée.',
      'Du hast noch keine Papierflieger erhalten. Sobald ein Brief ankommt, erscheint er hier.',
    ],
    'Uma carta selada chegou até ti.': [
      'A sealed letter has reached you.', 'Una carta sellada ha llegado hasta ti.',
      'Une lettre scellée t’est parvenue.', 'Ein versiegelter Brief ist bei dir angekommen.',
    ],
    'Recebeste um novo avião': [
      'You received a new plane', 'Has recibido un nuevo avión',
      'Tu as reçu un nouvel avion', 'Du hast einen neuen Papierflieger erhalten',
    ],
    'Mensagem selada · Abre quando estiveres pronto.': [
      'Sealed message · Open when you are ready.',
      'Mensaje sellado · Ábrelo cuando estés listo.',
      'Message scellé · Ouvre-le quand tu es prêt.',
      'Versiegelte Nachricht · Öffne sie, wenn du bereit bist.',
    ],
    'Denunciar': ['Report', 'Denunciar', 'Signaler', 'Melden'],
    'Bloquear': ['Block', 'Bloquear', 'Bloquer', 'Blockieren'],
    'Coração enviado.': ['Heart sent.', 'Corazón enviado.', 'Cœur envoyé.', 'Herz gesendet.'],
    'Ver mensagem original': ['View original message', 'Ver mensaje original', 'Voir le message original', 'Originalnachricht anzeigen'],
    'Respostas públicas': ['Public replies', 'Respuestas públicas', 'Réponses publiques', 'Öffentliche Antworten'],
    'Ainda não há respostas.': ['There are no replies yet.', 'Todavía no hay respuestas.', 'Il n’y a pas encore de réponses.', 'Es gibt noch keine Antworten.'],
    'Enviar resposta': ['Send reply', 'Enviar respuesta', 'Envoyer une réponse', 'Antwort senden'],
    'Open Sky': ['Open Sky', 'Open Sky', 'Open Sky', 'Open Sky'],
    'Mensagens do mundo inteiro': [
      'Messages from around the world', 'Mensajes de todo el mundo',
      'Messages du monde entier', 'Nachrichten aus aller Welt',
    ],
    'Filtrar por país': ['Filter by country', 'Filtrar por país', 'Filtrer par pays', 'Nach Land filtern'],
    'Ainda não há aviões neste céu.': [
      'There are no planes in this sky yet.', 'Todavía no hay aviones en este cielo.',
      'Il n’y a pas encore d’avions dans ce ciel.', 'In diesem Himmel gibt es noch keine Papierflieger.',
    ],
    'Sê o primeiro a lançar uma mensagem pública para o mundo.': [
      'Be the first to launch a public message to the world.',
      'Sé la primera persona en lanzar un mensaje público al mundo.',
      'Sois le premier à envoyer un message public au monde.',
      'Sei die erste Person, die eine öffentliche Nachricht in die Welt schickt.',
    ],
    'Cancelar': ['Cancel', 'Cancelar', 'Annuler', 'Abbrechen'],
    'Remover': ['Remove', 'Quitar', 'Retirer', 'Entfernen'],
    'Guardar': ['Save', 'Guardar', 'Enregistrer', 'Speichern'],
    'Link de convite copiado.': [
      'Invitation link copied.', 'Enlace de invitación copiado.',
      'Lien d’invitation copié.', 'Einladungslink kopiert.',
    ],
    'Perfil & Convidar': ['Profile & Invite', 'Perfil e invitar', 'Profil et invitation', 'Profil und Einladung'],
    'Cada convite aproxima mais o mundo.': [
      'Every invitation brings the world closer.',
      'Cada invitación acerca un poco más al mundo.',
      'Chaque invitation rapproche le monde.',
      'Jede Einladung bringt die Welt näher zusammen.',
    ],
    'Copiar convite': ['Copy invite', 'Copiar invitación', 'Copier l’invitation', 'Einladung kopieren'],
    'Idioma preferido': ['Preferred language', 'Idioma preferido', 'Langue préférée', 'Bevorzugte Sprache'],
    'Idioma preferido dos aviões': [
      'App and message language', 'Idioma de la aplicación y los mensajes',
      'Langue de l’application et des messages', 'App- und Nachrichtensprache',
    ],
    'Notificações': ['Notifications', 'Notificaciones', 'Notifications', 'Benachrichtigungen'],
    'A permissão é controlada pelo Android. Podes alterá-la nas definições do dispositivo.': [
      'Permission is controlled by Android. You can change it in your device settings.',
      'Android controla este permiso. Puedes cambiarlo en los ajustes del dispositivo.',
      'L’autorisation est contrôlée par Android. Tu peux la modifier dans les paramètres de l’appareil.',
      'Die Berechtigung wird von Android gesteuert. Du kannst sie in den Geräteeinstellungen ändern.',
    ],
    'As notificações são sincronizadas com a conta e podem ser desativadas a qualquer momento.': [
      'Notifications are synced with your account and can be disabled at any time.',
      'Las notificaciones se sincronizan con tu cuenta y puedes desactivarlas en cualquier momento.',
      'Les notifications sont synchronisées avec ton compte et peuvent être désactivées à tout moment.',
      'Benachrichtigungen werden mit deinem Konto synchronisiert und können jederzeit deaktiviert werden.',
    ],
    'Configurações': ['Settings', 'Ajustes', 'Paramètres', 'Einstellungen'],
    'Preferências': ['Preferences', 'Preferencias', 'Préférences', 'Einstellungen'],
    'Conta': ['Account', 'Cuenta', 'Compte', 'Konto'],
    'Segurança e privacidade': ['Safety and privacy', 'Seguridad y privacidad', 'Sécurité et confidentialité', 'Sicherheit und Datenschutz'],
    'Ajuda e suporte': ['Help and support', 'Ayuda y soporte', 'Aide et assistance', 'Hilfe und Support'],
    'A tua conta': ['Your account', 'Tu cuenta', 'Ton compte', 'Dein Konto'],
    'Os teus dados': ['Your data', 'Tus datos', 'Tes données', 'Deine Daten'],
    'Copiar JSON': ['Copy JSON', 'Copiar JSON', 'Copier le JSON', 'JSON kopieren'],
    'Eliminar conta e dados?': ['Delete account and data?', '¿Eliminar la cuenta y los datos?', 'Supprimer le compte et les données ?', 'Konto und Daten löschen?'],
    'Eliminar permanentemente': ['Delete permanently', 'Eliminar permanentemente', 'Supprimer définitivement', 'Dauerhaft löschen'],
    'Conta e dados eliminados com sucesso.': [
      'Account and data deleted successfully.',
      'Cuenta y datos eliminados correctamente.',
      'Compte et données supprimés avec succès.',
      'Konto und Daten erfolgreich gelöscht.',
    ],
    'Sessão terminada.': ['Signed out.', 'Sesión cerrada.', 'Session terminée.', 'Abgemeldet.'],
    'Conta atual': ['Current account', 'Cuenta actual', 'Compte actuel', 'Aktuelles Konto'],
    'Terminar sessão': ['Sign out', 'Cerrar sesión', 'Se déconnecter', 'Abmelden'],
    'Zona de segurança': ['Security area', 'Zona de seguridad', 'Zone de sécurité', 'Sicherheitsbereich'],
    'Exportar os meus dados (JSON)': ['Export my data (JSON)', 'Exportar mis datos (JSON)', 'Exporter mes données (JSON)', 'Meine Daten exportieren (JSON)'],
    'Eliminar conta e todos os dados': ['Delete account and all data', 'Eliminar la cuenta y todos los datos', 'Supprimer le compte et toutes les données', 'Konto und alle Daten löschen'],
    'Esqueci-me da palavra-passe': ['I forgot my password', 'Olvidé mi contraseña', 'Mot de passe oublié', 'Passwort vergessen'],
    'Continuar com Google': ['Continue with Google', 'Continuar con Google', 'Continuer avec Google', 'Mit Google fortfahren'],
    'A autenticar a tua conta…': ['Signing in to your account…', 'Iniciando sesión en tu cuenta…', 'Connexion à ton compte…', 'Anmeldung bei deinem Konto…'],
    'Criar perfil de copiloto': ['Create co-pilot profile', 'Crear perfil de copiloto', 'Créer un profil de copilote', 'Co-Pilot-Profil erstellen'],
    'Escolhe a tua identidade': ['Choose your identity', 'Elige tu identidad', 'Choisis ton identité', 'Wähle deine Identität'],
    'Foto de perfil': ['Profile photo', 'Foto de perfil', 'Photo de profil', 'Profilbild'],
    'Constrói o teu primeiro avião': ['Build your first plane', 'Construye tu primer avión', 'Construis ton premier avion', 'Baue deinen ersten Papierflieger'],
    'Toda a viagem começa com uma dobra.': [
      'Every journey starts with a fold.', 'Cada viaje empieza con un pliegue.',
      'Chaque voyage commence par un pli.', 'Jede Reise beginnt mit einem Falz.',
    ],
    'Escolhe o desenho, escreve a tua primeira carta e vê o papel ganhar asas.': [
      'Choose a design, write your first letter and watch the paper take flight.',
      'Elige un diseño, escribe tu primera carta y mira cómo el papel cobra alas.',
      'Choisis un modèle, écris ta première lettre et regarde le papier prendre son envol.',
      'Wähle ein Design, schreibe deinen ersten Brief und sieh zu, wie das Papier Flügel bekommt.',
    ],
    'Estamos aqui para ajudar': ['We are here to help', 'Estamos aquí para ayudarte', 'Nous sommes là pour t’aider', 'Wir helfen dir gerne'],
    'Novo pedido': ['New request', 'Nueva solicitud', 'Nouvelle demande', 'Neue Anfrage'],
    'Os teus pedidos': ['Your requests', 'Tus solicitudes', 'Tes demandes', 'Deine Anfragen'],
    'Send a message to a stranger': ['Send a message to a stranger', 'Envía un mensaje a alguien', 'Envoie un message à quelqu’un', 'Sende eine Nachricht an eine fremde Person'],
    'Uma ideia. Um voo. Outro mundo.': ['One idea. One flight. Another world.', 'Una idea. Un vuelo. Otro mundo.', 'Une idée. Un vol. Un autre monde.', 'Eine Idee. Ein Flug. Eine andere Welt.'],
    'Expressa-te com um símbolo': ['Express yourself with a symbol', 'Exprésate con un símbolo', 'Exprime-toi avec un symbole', 'Drücke dich mit einem Symbol aus'],
    'Adicionar ✨': ['Add ✨', 'Añadir ✨', 'Ajouter ✨', '✨ Hinzufügen'],
    'Máximo de 200 caracteres. O servidor gere a procura de destinatário, a rota e a entrega.': [
      'Maximum 200 characters. The server handles recipient matching, routing and delivery.',
      'Máximo de 200 caracteres. El servidor gestiona la búsqueda de destinatario, la ruta y la entrega.',
      '200 caractères maximum. Le serveur gère la recherche du destinataire, l’itinéraire et la livraison.',
      'Maximal 200 Zeichen. Der Server übernimmt Empfängersuche, Route und Zustellung.',
    ],
    'Avião recebido e colocado em revisão de segurança. Só será mostrado no Open Sky depois de aprovado.': [
      'Plane received and placed under safety review. It will appear on Open Sky only after approval.',
      'Avión recibido y puesto en revisión de seguridad. Solo aparecerá en Open Sky después de su aprobación.',
      'Avion reçu et placé en vérification de sécurité. Il n’apparaîtra sur Open Sky qu’après approbation.',
      'Papierflieger empfangen und zur Sicherheitsprüfung vorgemerkt. Er erscheint erst nach Freigabe auf Open Sky.',
    ],
    'PREPARA A TUA MENSAGEM': ['PREPARE YOUR MESSAGE', 'PREPARA TU MENSAJE', 'PRÉPARE TON MESSAGE', 'BEREITE DEINE NACHRICHT VOR'],
    'O serviço de segurança está a recuperar. O servidor vai tentar novamente automaticamente; não precisas de escrever outra mensagem nem repetir o envio.': [
      'The safety service is recovering. The server will retry automatically; you do not need to rewrite or resend your message.',
      'El servicio de seguridad se está recuperando. El servidor volverá a intentarlo automáticamente; no necesitas escribir ni enviar el mensaje otra vez.',
      'Le service de sécurité reprend. Le serveur réessaiera automatiquement ; tu n’as pas besoin de réécrire ni de renvoyer ton message.',
      'Der Sicherheitsdienst erholt sich. Der Server versucht es automatisch erneut; du musst deine Nachricht weder neu schreiben noch erneut senden.',
    ],
    'A mensagem está retida para revisão de segurança. Não será entregue até a revisão terminar.': [
      'The message is held for safety review. It will not be delivered until the review is complete.',
      'El mensaje está retenido para una revisión de seguridad. No se entregará hasta que termine la revisión.',
      'Le message est retenu pour vérification de sécurité. Il ne sera pas livré avant la fin de cette vérification.',
      'Die Nachricht wird zur Sicherheitsprüfung zurückgehalten. Sie wird erst nach Abschluss der Prüfung zugestellt.',
    ],
    'Entrega registada no servidor. O estado da carta será atualizado quando o destinatário a abrir ou responder.': [
      'Delivery has been recorded on the server. The letter status will update when the recipient opens or replies.',
      'La entrega quedó registrada en el servidor. El estado de la carta se actualizará cuando el destinatario la abra o responda.',
      'La livraison a été enregistrée sur le serveur. Le statut de la lettre sera mis à jour lorsque le destinataire l’ouvrira ou répondra.',
      'Die Zustellung wurde auf dem Server registriert. Der Status wird aktualisiert, sobald der Empfänger den Brief öffnet oder antwortet.',
    ],
    'O globo mostra uma rota digital estimada entre os centros geográficos dos países. O avião acompanha o progresso guardado pelo servidor; não usa GPS nem representa a posição de uma aeronave física.': [
      'The globe shows an estimated digital route between country geographic centres. Flight progress comes from the server; it does not use GPS or represent a real aircraft location.',
      'El globo muestra una ruta digital estimada entre los centros geográficos de los países. El progreso se obtiene del servidor; no usa GPS ni representa la ubicación de una aeronave real.',
      'Le globe affiche un itinéraire numérique estimé entre les centres géographiques des pays. La progression vient du serveur ; elle n’utilise pas le GPS et ne représente pas un avion réel.',
      'Der Globus zeigt eine geschätzte digitale Route zwischen den geografischen Zentren der Länder. Der Flugfortschritt stammt vom Server; er verwendet kein GPS und zeigt keine Position eines echten Flugzeugs.',
    ],
    'PARTIDA': ['DEPARTURE', 'SALIDA', 'DÉPART', 'START'],
    'DESTINO LOCALIZADO': ['DESTINATION FOUND', 'DESTINO ENCONTRADO', 'DESTINATION TROUVÉE', 'ZIEL GEFUNDEN'],
    'Ainda não lançaste nenhum avião.': ['You have not launched any planes yet.', 'Todavía no has lanzado ningún avión.', 'Tu n’as encore lancé aucun avion.', 'Du hast noch keine Papierflieger gestartet.'],
    'Lançado': ['Launched', 'Lanzado', 'Lancé', 'Gestartet'],
    'Puxa para baixo para sincronizar os aviões e os seus estados.': [
      'Pull down to sync your planes and their statuses.',
      'Desliza hacia abajo para sincronizar tus aviones y sus estados.',
      'Fais glisser vers le bas pour synchroniser tes avions et leurs statuts.',
      'Ziehe nach unten, um deine Papierflieger und ihren Status zu synchronisieren.',
    ],
    'O avião foi libertado.': ['The plane has been released.', 'El avión ha sido liberado.', 'L’avion a été libéré.', 'Der Papierflieger wurde freigegeben.'],
    'Eliminar este avião?': ['Delete this plane?', '¿Eliminar este avión?', 'Supprimer cet avion ?', 'Diesen Papierflieger löschen?'],
    'A carta será removida apenas da tua Caixa.': [
      'The letter will be removed only from your inbox.',
      'La carta solo se eliminará de tu bandeja de entrada.',
      'La lettre sera retirée uniquement de ta boîte de réception.',
      'Der Brief wird nur aus deinem Posteingang entfernt.',
    ],
    'Remetente bloqueado. Não receberás novas correspondências desta conta.': [
      'Sender blocked. You will not receive further mail from this account.',
      'Remitente bloqueado. No recibirás más mensajes de esta cuenta.',
      'Expéditeur bloqué. Tu ne recevras plus de courrier de ce compte.',
      'Absender blockiert. Du erhältst keine weiteren Nachrichten von diesem Konto.',
    ],
    'Uma carta encontrou o caminho até ti.': [
      'A letter found its way to you.', 'Una carta encontró el camino hasta ti.',
      'Une lettre a trouvé son chemin jusqu’à toi.', 'Ein Brief hat seinen Weg zu dir gefunden.',
    ],
    'O avião pousou à tua porta.': [
      'The plane has landed at your door.', 'El avión ha aterrizado en tu puerta.',
      'L’avion a atterri devant ta porte.', 'Der Papierflieger ist vor deiner Tür gelandet.',
    ],
    'Abre a tua carta e descobre quem te encontrou no mundo.': [
      'Open your letter and discover who found you in the world.',
      'Abre tu carta y descubre quién te encontró en el mundo.',
      'Ouvre ta lettre et découvre qui t’a trouvé dans le monde.',
      'Öffne deinen Brief und entdecke, wer dich auf der Welt gefunden hat.',
    ],
    'TRADUÇÃO AUTOMÁTICA · CLOUDFLARE AI': [
      'AUTOMATIC TRANSLATION · CLOUDFLARE AI',
      'TRADUCCIÓN AUTOMÁTICA · CLOUDFLARE AI',
      'TRADUCTION AUTOMATIQUE · CLOUDFLARE AI',
      'AUTOMATISCHE ÜBERSETZUNG · CLOUDFLARE AI',
    ],
    'Recebido ·': ['Received ·', 'Recibido ·', 'Reçu ·', 'Erhalten ·'],
    'Quando a resposta passar na segurança, a Chama acende e a conversa abre automaticamente.': [
      'When the reply passes safety checks, the Chama lights up and the conversation opens automatically.',
      'Cuando la respuesta supere la revisión de seguridad, se encenderá la Chama y la conversación se abrirá automáticamente.',
      'Lorsque la réponse aura passé les contrôles de sécurité, la Chama s’allumera et la conversation s’ouvrira automatiquement.',
      'Sobald die Antwort die Sicherheitsprüfung bestanden hat, wird die Chama aktiviert und die Unterhaltung automatisch geöffnet.',
    ],
    'O remetente desativou as respostas para esta carta.': [
      'The sender disabled replies to this letter.',
      'El remitente desactivó las respuestas a esta carta.',
      'L’expéditeur a désactivé les réponses à cette lettre.',
      'Der Absender hat Antworten auf diesen Brief deaktiviert.',
    ],
    'Denunciar mensagem': ['Report message', 'Denunciar mensaje', 'Signaler le message', 'Nachricht melden'],
    'A tua resposta está a voar pela rota da Chama — 3× mais rápida.': [
      'Your reply is travelling along the Chama route — 3× faster.',
      'Tu respuesta viaja por la ruta Chama: 3 veces más rápido.',
      'Ta réponse emprunte la route Chama — 3 fois plus rapide.',
      'Deine Antwort fliegt über die Chama-Route — 3-mal schneller.',
    ],
    'Ainda não há aviões nesta Chama para denunciar.': [
      'There are no planes in this Chama to report yet.',
      'Todavía no hay aviones en esta Chama que denunciar.',
      'Il n’y a pas encore d’avions à signaler dans cette Chama.',
      'In dieser Chama gibt es noch keine Papierflieger zum Melden.',
    ],
    'Encerrar esta Chama?': ['End this Chama?', '¿Cerrar esta Chama?', 'Terminer cette Chama ?', 'Diese Chama beenden?'],
    'Continuar Chama': ['Continue Chama', 'Continuar Chama', 'Continuer Chama', 'Chama fortsetzen'],
    'Encerrar rota': ['End route', 'Cerrar ruta', 'Terminer l’itinéraire', 'Route beenden'],
    'Rota encerrada. O histórico continua disponível.': [
      'Route ended. The history is still available.',
      'Ruta cerrada. El historial sigue disponible.',
      'Itinéraire terminé. L’historique reste disponible.',
      'Route beendet. Der Verlauf bleibt verfügbar.',
    ],
    'Bloquear copiloto?': ['Block co-pilot?', '¿Bloquear copiloto?', 'Bloquer ce copilote ?', 'Co-Pilot blockieren?'],
    'Deixarás de receber aviões e mensagens desta conta.': [
      'You will no longer receive planes or messages from this account.',
      'Dejarás de recibir aviones y mensajes de esta cuenta.',
      'Tu ne recevras plus d’avions ni de messages de ce compte.',
      'Du erhältst keine Papierflieger oder Nachrichten mehr von diesem Konto.',
    ],
    'Copiloto bloqueado.': ['Co-pilot blocked.', 'Copiloto bloqueado.', 'Copilote bloqué.', 'Co-Pilot blockiert.'],
    'Chat privado: esta conversa é independente da troca de aviões.': [
      'Private chat: this conversation is separate from exchanging planes.',
      'Chat privado: esta conversación es independiente del intercambio de aviones.',
      'Chat privé : cette conversation est indépendante de l’échange d’avions.',
      'Privater Chat: Dieses Gespräch ist unabhängig vom Austausch von Papierfliegern.',
    ],
    'INÍCIO DA CHAMA': ['CHAMA START', 'INICIO DE CHAMA', 'DÉBUT DE CHAMA', 'CHAMA-BEGINN'],
    'Ver original': ['View original', 'Ver original', 'Voir l’original', 'Original anzeigen'],
    'Mensagem copiada.': ['Message copied.', 'Mensaje copiado.', 'Message copié.', 'Nachricht kopiert.'],
    'Chat & Amigos': ['Chat & Friends', 'Chat y amigos', 'Chat et amis', 'Chat & Freunde'],
    'Liga-te a copilotos de todo o mundo': [
      'Connect with co-pilots around the world.',
      'Conéctate con copilotos de todo el mundo.',
      'Connecte-toi avec des copilotes du monde entier.',
      'Vernetze dich mit Co-Piloten auf der ganzen Welt.',
    ],
    'Explorar amigos do mundo': ['Explore friends around the world', 'Explorar amigos del mundo', 'Découvrir des amis dans le monde', 'Freunde auf der ganzen Welt entdecken'],
    'Encontrar amigos': ['Find friends', 'Encontrar amigos', 'Trouver des amis', 'Freunde finden'],
    'Copiar o meu link de convite': ['Copy my invitation link', 'Copiar mi enlace de invitación', 'Copier mon lien d’invitation', 'Meinen Einladungslink kopieren'],
    'Eliminar conversa': ['Delete conversation', 'Eliminar conversación', 'Supprimer la conversation', 'Unterhaltung löschen'],
    'A Chama do Deserto': ['The Desert Chama', 'La Chama del Desierto', 'La Chama du désert', 'Die Wüsten-Chama'],
    'Histórico dos aviões': ['Plane history', 'Historial de aviones', 'Historique des avions', 'Papierflieger-Verlauf'],
    'Joga, cumpre missões e sobe de nível': ['Play, complete missions and level up', 'Juega, completa misiones y sube de nivel', 'Joue, accomplis des missions et monte de niveau', 'Spiele, erfülle Missionen und steige im Level auf'],
    'NÍVEL': ['LEVEL', 'NIVEL', 'NIVEAU', 'LEVEL'],
    'O mundo é o teu campo de jogo': ['The world is your playground', 'El mundo es tu campo de juego', 'Le monde est ton terrain de jeu', 'Die Welt ist dein Spielfeld'],
    'Escolhe o teu desafio': ['Choose your challenge', 'Elige tu desafío', 'Choisis ton défi', 'Wähle deine Herausforderung'],
    'Começar ronda · 10 perguntas': ['Start round · 10 questions', 'Comenzar ronda · 10 preguntas', 'Commencer la manche · 10 questions', 'Runde starten · 10 Fragen'],
    'As perguntas funcionam sem Internet. O teu XP e as conquistas sincronizam quando estiveres ligado.': [
      'Questions work offline. Your XP and achievements sync when you are online.',
      'Las preguntas funcionan sin Internet. Tu XP y tus logros se sincronizan cuando estés conectado.',
      'Les questions fonctionnent hors ligne. Tes XP et tes succès se synchronisent lorsque tu es connecté.',
      'Die Fragen funktionieren offline. Deine XP und Erfolge werden synchronisiert, sobald du online bist.',
    ],
    'A tua ronda terminou. Cada resposta é mais uma descoberta.': [
      'Your round is over. Every answer is another discovery.',
      'Tu ronda ha terminado. Cada respuesta es un nuevo descubrimiento.',
      'Ta manche est terminée. Chaque réponse est une nouvelle découverte.',
      'Deine Runde ist vorbei. Jede Antwort ist eine neue Entdeckung.',
    ],
    'respostas certas': ['correct answers', 'respuestas correctas', 'bonnes réponses', 'richtige Antworten'],
    'A guardar os pontos…': ['Saving your points…', 'Guardando tus puntos…', 'Enregistrement de tes points…', 'Deine Punkte werden gespeichert…'],
    'Os pontos foram guardados na tua conta.': ['Your points were saved to your account.', 'Tus puntos se guardaron en tu cuenta.', 'Tes points ont été enregistrés sur ton compte.', 'Deine Punkte wurden in deinem Konto gespeichert.'],
    'Jogar outra ronda': ['Play another round', 'Jugar otra ronda', 'Jouer une autre manche', 'Noch eine Runde spielen'],
    'Ver as minhas missões': ['View my missions', 'Ver mis misiones', 'Voir mes missions', 'Meine Missionen ansehen'],
    'Missões do piloto': ['Pilot missions', 'Misiones del piloto', 'Missions du pilote', 'Pilotenmissionen'],
    'Cumpre objectivos reais no Paper Plane. Cada recompensa só pode ser resgatada uma vez.': [
      'Complete real objectives in Paper Plane. Each reward can only be claimed once.',
      'Completa objetivos reales en Paper Plane. Cada recompensa solo se puede reclamar una vez.',
      'Accomplis de vrais objectifs dans Paper Plane. Chaque récompense ne peut être récupérée qu’une fois.',
      'Erfülle echte Ziele in Paper Plane. Jede Belohnung kann nur einmal eingelöst werden.',
    ],
    'Recompensa resgatada': ['Reward claimed', 'Recompensa reclamada', 'Récompense récupérée', 'Belohnung eingelöst'],
    'Resgatar XP': ['Claim XP', 'Canjear XP', 'Récupérer les XP', 'XP einlösen'],
    'Continua a jogar para desbloquear.': ['Keep playing to unlock.', 'Sigue jugando para desbloquear.', 'Continue à jouer pour débloquer.', 'Spiele weiter, um es freizuschalten.'],
    'A tua colecção': ['Your collection', 'Tu colección', 'Ta collection', 'Deine Sammlung'],
    'Os crachás são atribuídos por acções reais na aplicação.': [
      'Badges are awarded for real actions in the app.',
      'Las insignias se conceden por acciones reales en la aplicación.',
      'Les badges sont attribués pour des actions réelles dans l’application.',
      'Abzeichen werden für echte Aktionen in der App vergeben.',
    ],
    'Escreve algo gentil...': ['Write something kind...', 'Escribe algo amable...', 'Écris quelque chose de gentil…', 'Schreibe etwas Freundliches…'],
    'Escreve uma resposta gentil…': ['Write a kind reply…', 'Escribe una respuesta amable…', 'Écris une réponse gentille…', 'Schreibe eine freundliche Antwort…'],
    'Escreve uma resposta…': ['Write a reply…', 'Escribe una respuesta…', 'Écris une réponse…', 'Schreibe eine Antwort…'],
    'Link da foto ou perfil público': ['Photo or public profile link', 'Enlace de foto o perfil público', 'Lien vers une photo ou un profil public', 'Link zum Foto oder öffentlichen Profil'],
    'Enviar mensagem em papel...': ['Send a paper message...', 'Enviar mensaje en papel...', 'Envoyer un message papier…', 'Papiernachricht senden…'],
    'Palavra-passe atual': ['Current password', 'Contraseña actual', 'Mot de passe actuel', 'Aktuelles Passwort'],
    'Pesquisar @nome_de_copiloto': ['Search @co-pilot-name', 'Buscar @nombre-de-copiloto', 'Rechercher @nom-de-copilote', '@Co-Pilot-Name suchen'],
    'Chama encerrada': ['Chama ended', 'Chama finalizada', 'Chama terminée', 'Chama beendet'],
    'Enviar próximo avião…': ['Send next plane…', 'Enviar el próximo avión…', 'Envoyer le prochain avion…', 'Nächsten Papierflieger senden…'],
    'Mensagem instantânea…': ['Instant message…', 'Mensaje instantáneo…', 'Message instantané…', 'Sofortnachricht…'],
    'Copiar link de convite': ['Copy invitation link', 'Copiar enlace de invitación', 'Copier le lien d’invitation', 'Einladungslink kopieren'],
    'Atualizar voo': ['Refresh flight', 'Actualizar vuelo', 'Actualiser le vol', 'Flug aktualisieren'],
    'Mais opções': ['More options', 'Más opciones', 'Plus d’options', 'Weitere Optionen'],
    'Atualizar atlas': ['Refresh atlas', 'Actualizar atlas', 'Actualiser l’atlas', 'Atlas aktualisieren'],
    'Atualizar coleção': ['Refresh collection', 'Actualizar colección', 'Actualiser la collection', 'Sammlung aktualisieren'],
    'Copiar mensagem': ['Copy message', 'Copiar mensaje', 'Copier le message', 'Nachricht kopieren'],
    'Aceitar': ['Accept', 'Aceptar', 'Accepter', 'Annehmen'],
    'Recusar': ['Decline', 'Rechazar', 'Refuser', 'Ablehnen'],
    'Adicionar emoji': ['Add emoji', 'Añadir emoji', 'Ajouter un emoji', 'Emoji hinzufügen'],
    'Categoria': ['Category', 'Categoría', 'Catégorie', 'Kategorie'],
    'Assunto': ['Subject', 'Asunto', 'Sujet', 'Betreff'],
    'Descreve o problema': ['Describe the issue', 'Describe el problema', 'Décris le problème', 'Beschreibe das Problem'],
    'O que aconteceu? Em que ecrã? O que esperavas que acontecesse?': [
      'What happened? Which screen? What did you expect to happen?',
      '¿Qué pasó? ¿En qué pantalla? ¿Qué esperabas que ocurriera?',
      'Que s’est-il passé ? Sur quel écran ? Que pensais-tu voir se produire ?',
      'Was ist passiert? Auf welchem Bildschirm? Was hast du erwartet?',
    ],
    'A ler o link…': ['Reading link…', 'Leyendo el enlace…', 'Lecture du lien…', 'Link wird gelesen…'],
    'Denunciar avião': ['Report plane', 'Denunciar avión', 'Signaler un avion', 'Papierflieger melden'],
    'Escolhe o motivo que melhor descreve o problema. A denúncia será enviada para análise.': [
      'Choose the reason that best describes the issue. Your report will be sent for review.',
      'Elige el motivo que mejor describe el problema. Tu denuncia se enviará para su revisión.',
      'Choisis le motif qui décrit le mieux le problème. Ton signalement sera envoyé pour examen.',
      'Wähle den Grund, der das Problem am besten beschreibt. Deine Meldung wird zur Prüfung gesendet.',
    ],
    'Denúncia enviada para análise. Obrigado por ajudares a manter o céu seguro.': [
      'Report sent for review. Thank you for helping keep the sky safe.',
      'Denuncia enviada para revisión. Gracias por ayudar a mantener el cielo seguro.',
      'Signalement envoyé pour examen. Merci de contribuer à la sécurité du ciel.',
      'Meldung zur Prüfung gesendet. Danke, dass du hilfst, den Himmel sicher zu halten.',
    ],
    'Introduz primeiro o teu endereço de email.': ['Enter your email address first.', 'Introduce primero tu dirección de correo electrónico.', 'Saisis d’abord ton adresse e-mail.', 'Gib zuerst deine E-Mail-Adresse ein.'],
    'Fechar': ['Close', 'Cerrar', 'Fermer', 'Schließen'],
    'Dados copiados. Guarda-os num local seguro.': ['Data copied. Keep it somewhere safe.', 'Datos copiados. Guárdalos en un lugar seguro.', 'Données copiées. Conserve-les en lieu sûr.', 'Daten kopiert. Bewahre sie sicher auf.'],
    'Será pedida uma nova confirmação pela tua conta Google.': [
      'You will be asked to confirm again through your Google account.',
      'Se te pedirá una nueva confirmación mediante tu cuenta de Google.',
      'Une nouvelle confirmation via ton compte Google sera demandée.',
      'Du wirst gebeten, die Aktion über dein Google-Konto erneut zu bestätigen.',
    ],
    'Podes solicitar a eliminação da tua conta e dos dados associados. A confirmação exige voltar a autenticar.': [
      'You can request deletion of your account and associated data. Confirmation requires signing in again.',
      'Puedes solicitar la eliminación de tu cuenta y los datos asociados. La confirmación requiere volver a iniciar sesión.',
      'Tu peux demander la suppression de ton compte et des données associées. Une nouvelle authentification est nécessaire.',
      'Du kannst die Löschung deines Kontos und der zugehörigen Daten beantragen. Zur Bestätigung musst du dich erneut anmelden.',
    ],
    'Ao criar uma conta, não partilhes a tua palavra-passe com ninguém. O Paper Plane nunca a pede por mensagem.': [
      'When creating an account, never share your password. Paper Plane will never ask for it in a message.',
      'Al crear una cuenta, no compartas tu contraseña. Paper Plane nunca te la pedirá por mensaje.',
      'Lors de la création d’un compte, ne partage jamais ton mot de passe. Paper Plane ne te le demandera jamais par message.',
      'Gib bei der Kontoerstellung niemals dein Passwort weiter. Paper Plane wird dich niemals per Nachricht danach fragen.',
    ],
    'Escolhe um nome de copiloto disponível.': ['Choose an available co-pilot name.', 'Elige un nombre de copiloto disponible.', 'Choisis un nom de copilote disponible.', 'Wähle einen verfügbaren Co-Pilot-Namen.'],
    'O teu nome de copiloto será único e aparecerá com @. A tua data de nascimento é declarada por ti. O servidor calcula a faixa etária, mas não verifica a tua identidade.': [
      'Your co-pilot name will be unique and displayed with @. You declare your date of birth. The server calculates an age group but does not verify your identity.',
      'Tu nombre de copiloto será único y aparecerá con @. Tú declaras tu fecha de nacimiento. El servidor calcula un grupo de edad, pero no verifica tu identidad.',
      'Ton nom de copilote sera unique et affiché avec @. Tu déclares ta date de naissance. Le serveur calcule une tranche d’âge, mais ne vérifie pas ton identité.',
      'Dein Co-Pilot-Name ist eindeutig und wird mit @ angezeigt. Dein Geburtsdatum gibst du selbst an. Der Server berechnet eine Altersgruppe, überprüft aber nicht deine Identität.',
    ],
    'Cria o teu próprio @nome. Não precisas de números aleatórios no fim.': [
      'Create your own @name. You do not need random numbers at the end.',
      'Crea tu propio @nombre. No necesitas números aleatorios al final.',
      'Crée ton propre @nom. Tu n’as pas besoin d’ajouter des chiffres au hasard.',
      'Erstelle deinen eigenen @Namen. Du brauchst keine zufälligen Zahlen am Ende.',
    ],
    'Cola um link HTTPS de uma imagem ou de um perfil público. Tentaremos encontrar a foto automaticamente. Não precisas de carregar ficheiros.': [
      'Paste an HTTPS link to an image or public profile. We will try to find the photo automatically. No file upload is needed.',
      'Pega un enlace HTTPS a una imagen o perfil público. Intentaremos encontrar la foto automáticamente. No necesitas subir archivos.',
      'Colle un lien HTTPS vers une image ou un profil public. Nous essaierons de trouver la photo automatiquement. Aucun fichier à téléverser.',
      'Füge einen HTTPS-Link zu einem Bild oder öffentlichen Profil ein. Wir versuchen, das Foto automatisch zu finden. Du musst keine Dateien hochladen.',
    ],
    'Usamos a data para calcular a faixa etária. O dia e o mês não ficam guardados; o servidor conserva apenas o ano e a faixa declarada.': [
      'We use the date to calculate your age group. The day and month are not stored; the server keeps only the year and declared age group.',
      'Usamos la fecha para calcular el grupo de edad. No guardamos el día ni el mes; el servidor conserva solo el año y el grupo declarado.',
      'Nous utilisons la date pour calculer ta tranche d’âge. Le jour et le mois ne sont pas conservés ; le serveur ne garde que l’année et la tranche déclarée.',
      'Wir verwenden das Datum zur Berechnung deiner Altersgruppe. Tag und Monat werden nicht gespeichert; der Server speichert nur das Jahr und die angegebene Altersgruppe.',
    ],
    'O teu primeiro avião está guardado no servidor e pronto para a viagem. Retoma a oficina para rever o desenho e lança-o quando estiveres preparado.': [
      'Your first plane is saved on the server and ready for its journey. Return to the workshop to review the design and launch it when you are ready.',
      'Tu primer avión está guardado en el servidor y listo para viajar. Vuelve al taller para revisar el diseño y lánzalo cuando estés listo.',
      'Ton premier avion est enregistré sur le serveur et prêt à partir. Retourne à l’atelier pour revoir le modèle et le lancer lorsque tu seras prêt.',
      'Dein erster Papierflieger ist auf dem Server gespeichert und startklar. Kehre zur Werkstatt zurück, überprüfe das Design und starte ihn, wenn du bereit bist.',
    ],
    'Escolhe o formato do avião': ['Choose your plane design', 'Elige el diseño del avión', 'Choisis le modèle de ton avion', 'Wähle das Design deines Papierfliegers'],
    'A tua primeira carta': ['Your first letter', 'Tu primera carta', 'Ta première lettre', 'Dein erster Brief'],
    'O avião e o texto são guardados online. Não há envio fictício nem destinatário inventado.': [
      'The plane and text are saved online. No fake delivery or invented recipient.',
      'El avión y el texto se guardan en línea. No hay entregas ficticias ni destinatarios inventados.',
      'L’avion et le texte sont enregistrés en ligne. Aucune livraison fictive ni aucun destinataire inventé.',
      'Der Papierflieger und der Text werden online gespeichert. Es gibt keine fingierte Zustellung und keinen erfundenen Empfänger.',
    ],
    'Os aviões recebidos podem ser apresentados automaticamente neste idioma. A mensagem original continua disponível.': [
      'Incoming planes can be displayed automatically in this language. The original message remains available.',
      'Los aviones recibidos pueden mostrarse automáticamente en este idioma. El mensaje original sigue disponible.',
      'Les avions reçus peuvent être affichés automatiquement dans cette langue. Le message original reste disponible.',
      'Eingehende Papierflieger können automatisch in dieser Sprache angezeigt werden. Die Originalnachricht bleibt verfügbar.',
    ],
    'Eliminar conversa?': ['Delete conversation?', '¿Eliminar conversación?', 'Supprimer la conversation ?', 'Unterhaltung löschen?'],
    'Remover amigo?': ['Remove friend?', '¿Eliminar amigo?', 'Retirer cet ami ?', 'Freund entfernen?'],
    'Os aviões recebidos serão traduzidos para este idioma.': [
      'Incoming planes will be translated into this language.',
      'Los aviones recibidos se traducirán a este idioma.',
      'Les avions reçus seront traduits dans cette langue.',
      'Eingehende Papierflieger werden in diese Sprache übersetzt.',
    ],
    'A troca de aviões nesta rota será encerrada. O histórico ficará guardado para consulta.': [
      'The exchange of planes on this route will end. The history will remain available.',
      'El intercambio de aviones en esta ruta finalizará. El historial seguirá disponible.',
      'L’échange d’avions sur cet itinéraire prendra fin. L’historique restera disponible.',
      'Der Austausch von Papierfliegern auf dieser Route wird beendet. Der Verlauf bleibt verfügbar.',
    ],
    'Bloquear copiloto': ['Block co-pilot', 'Bloquear copiloto', 'Bloquer ce copilote', 'Co-Pilot blockieren'],
    'OU': ['OR', 'O', 'OU', 'ODER'],
    'Esta ação elimina o perfil, aviões enviados e recebidos, respostas, chats, amizades, denúncias associadas e dispositivos registados. Não pode ser desfeita.': [
      'This action deletes your profile, sent and received planes, replies, chats, friendships, related reports and registered devices. It cannot be undone.',
      'Esta acción elimina tu perfil, aviones enviados y recibidos, respuestas, chats, amistades, denuncias asociadas y dispositivos registrados. No se puede deshacer.',
      'Cette action supprime ton profil, les avions envoyés et reçus, les réponses, les discussions, les amitiés, les signalements associés et les appareils enregistrés. Elle est irréversible.',
      'Diese Aktion löscht dein Profil, gesendete und empfangene Papierflieger, Antworten, Chats, Freundschaften, zugehörige Meldungen und registrierte Geräte. Sie kann nicht rückgängig gemacht werden.',
    ],
    'Comunica falhas, dificuldades com a conta ou entrega, questões de segurança e sugestões. Não incluas palavras-passe nem documentos pessoais.': [
      'Report bugs, account or delivery issues, safety concerns and suggestions. Do not include passwords or personal documents.',
      'Comunica errores, problemas de cuenta o entrega, cuestiones de seguridad y sugerencias. No incluyas contraseñas ni documentos personales.',
      'Signale les bugs, les problèmes de compte ou de livraison, les questions de sécurité et les suggestions. N’inclus pas de mots de passe ni de documents personnels.',
      'Melde Fehler, Konto- oder Zustellungsprobleme, Sicherheitsbedenken und Vorschläge. Gib keine Passwörter oder persönlichen Dokumente an.',
    ],
    'Preenche o assunto e descreve o problema com pelo menos 10 caracteres.': [
      'Enter a subject and describe the issue using at least 10 characters.',
      'Escribe un asunto y describe el problema con al menos 10 caracteres.',
      'Indique un sujet et décris le problème en au moins 10 caractères.',
      'Gib einen Betreff ein und beschreibe das Problem mit mindestens 10 Zeichen.',
    ],
    'Pedido enviado. Podes acompanhar o estado nesta página.': [
      'Request sent. You can track its status on this page.',
      'Solicitud enviada. Puedes consultar su estado en esta página.',
      'Demande envoyée. Tu peux suivre son état sur cette page.',
      'Anfrage gesendet. Du kannst den Status auf dieser Seite verfolgen.',
    ],
    'Clube do Céu': ['Sky Club', 'Club del Cielo', 'Club du Ciel', 'Himmelsclub'],
    'Tentar sincronizar': ['Try to sync', 'Intentar sincronizar', 'Réessayer la synchronisation', 'Synchronisierung versuchen'],
    'Não foi possível abrir a página.': [
      'Could not open the page.', 'No se pudo abrir la página.',
      'Impossible d’ouvrir la page.', 'Die Seite konnte nicht geöffnet werden.',
    ],

    'Acompanhar voos': ['Track flights', 'Seguir vuelos', 'Suivre les vols', 'Flüge verfolgen'],
    'Escolhe o sentimento': ['Choose a feeling', 'Elige un sentimiento', 'Choisis une émotion', 'Wähle ein Gefühl'],
    'Visibilidade': ['Visibility', 'Visibilidad', 'Visibilité', 'Sichtbarkeit'],
    'Recebidos': ['Received', 'Recibidos', 'Reçus', 'Empfangen'],
    'A sair': ['Outgoing', 'Enviados', 'Envoyés', 'Ausgehend'],
    'Responder com outro avião': ['Reply with another plane', 'Responder con otro avión', 'Répondre avec un autre avion', 'Mit einem weiteren Flieger antworten'],
    'Resumo da conta': ['Account overview', 'Resumen de la cuenta', 'Aperçu du compte', 'Kontoübersicht'],
    'Convida amigos para o Paper Plane': ['Invite friends to Paper Plane', 'Invita a tus amigos a Paper Plane', 'Invite tes amis sur Paper Plane', 'Freunde zu Paper Plane einladen'],
    'Explorar o teu percurso': ['Explore your journey', 'Explora tu recorrido', 'Explorer ton parcours', 'Deine Reise erkunden'],
    'Conta e preferências': ['Account and preferences', 'Cuenta y preferencias', 'Compte et préférences', 'Konto und Einstellungen'],
    'Países ligados': ['Connected countries', 'Países conectados', 'Pays connectés', 'Verbundene Länder'],
    'Aviões do teu hangar': ['Planes in your hangar', 'Aviones en tu hangar', 'Avions dans ton hangar', 'Flieger in deinem Hangar'],
    'Emblemas conquistados': ['Badges earned', 'Insignias obtenidas', 'Badges obtenus', 'Verdiente Abzeichen'],
    'Países visitados': ['Countries visited', 'Países visitados', 'Pays visités', 'Besuchte Länder'],
    'Controlos reais': ['Account controls', 'Controles de cuenta', 'Contrôles du compte', 'Kontoeinstellungen'],
    'Mensagens do país': ['Messages from your country', 'Mensajes de tu país', 'Messages de ton pays', 'Nachrichten aus deinem Land'],
    'Start Flying': ['Start flying', 'Empezar a volar', 'Commencer à voler', 'Losfliegen'],
    'Completar perfil': ['Complete profile', 'Completar perfil', 'Compléter le profil', 'Profil vervollständigen'],
    'Lançar o primeiro avião': ['Launch your first plane', 'Lanza tu primer avión', 'Lance ton premier avion', 'Starte deinen ersten Papierflieger'],
    'Escrever Avião': ['Write a plane', 'Escribir un avión', 'Écrire un avion', 'Einen Papierflieger schreiben'],
    'Lançar avião': ['Launch plane', 'Lanzar avión', 'Lancer l’avion', 'Papierflieger starten'],
    'O teu avião está a voar': ['Your plane is flying', 'Tu avión está volando', 'Ton avion est en vol', 'Dein Papierflieger ist unterwegs'],
    'Eliminar do meu histórico': ['Remove from my history', 'Eliminar de mi historial', 'Retirer de mon historique', 'Aus meinem Verlauf entfernen'],
    'Voltar ao início': ['Back to home', 'Volver al inicio', 'Retour à l’accueil', 'Zur Startseite'],
    'Avião recebido': ['Plane received', 'Avión recibido', 'Avion reçu', 'Papierflieger erhalten'],
    'Libertar avião': ['Release plane', 'Liberar avión', 'Libérer l’avion', 'Papierflieger freigeben'],
    'O avião chegou': ['The plane has arrived', 'El avión ha llegado', 'L’avion est arrivé', 'Der Papierflieger ist angekommen'],
    'Mensagem': ['Message', 'Mensaje', 'Message', 'Nachricht'],
    'Completar perfil de copiloto': ['Complete co-pilot profile', 'Completar el perfil de copiloto', 'Compléter le profil de copilote', 'Co-Pilot-Profil vervollständigen'],
    'A minha conta': ['My account', 'Mi cuenta', 'Mon compte', 'Mein Konto'],
    'Google · Email e palavra-passe': ['Google · Email and password', 'Google · Correo y contraseña', 'Google · E-mail et mot de passe', 'Google · E-Mail und Passwort'],
    'Tradução de aviões e mensagens': ['Plane and message translation', 'Traducción de aviones y mensajes', 'Traduction des avions et messages', 'Übersetzung von Fliegern und Nachrichten'],
    'Bloqueios, denúncias e controlos': ['Blocks, reports and controls', 'Bloqueos, denuncias y controles', 'Blocages, signalements et contrôles', 'Blockierungen, Meldungen und Kontrollen'],
    'Informações sobre o Paper Plane': ['Information about Paper Plane', 'Información sobre Paper Plane', 'Informations sur Paper Plane', 'Informationen zu Paper Plane'],
    'Partilhar convite': ['Share invitation', 'Compartir invitación', 'Partager l’invitation', 'Einladung teilen'],
    'Copiar link': ['Copy link', 'Copiar enlace', 'Copier le lien', 'Link kopieren'],
    'Voos totais': ['Total flights', 'Vuelos totales', 'Vols au total', 'Flüge insgesamt'],
    'Primeiro voo': ['First flight', 'Primer vuelo', 'Premier vol', 'Erster Flug'],
    'Viajante do mundo': ['World traveller', 'Viajero del mundo', 'Voyageur du monde', 'Weltreisender'],
    'Voo concluído': ['Flight completed', 'Vuelo completado', 'Vol terminé', 'Flug abgeschlossen'],
    'Comunicar problemas e acompanhar pedidos': ['Report issues and track requests', 'Informar de problemas y seguir solicitudes', 'Signaler des problèmes et suivre les demandes', 'Probleme melden und Anfragen verfolgen'],
    'Conhece o projeto e acompanha as novidades': ['Learn about the project and follow updates', 'Conoce el proyecto y sigue las novedades', 'Découvre le projet et ses nouveautés', 'Lerne das Projekt kennen und verfolge Neuigkeiten'],
    'A ideia e os princípios do aplicativo': ['The idea and principles behind the app', 'La idea y los principios de la aplicación', 'L’idée et les principes de l’application', 'Die Idee und die Grundsätze der App'],
    'Notas de versão e melhorias': ['Release notes and improvements', 'Notas de versión y mejoras', 'Notes de version et améliorations', 'Versionshinweise und Verbesserungen'],
    'Como os teus dados são tratados': ['How your data is handled', 'Cómo se tratan tus datos', 'Comment tes données sont traitées', 'Wie deine Daten verarbeitet werden'],
    'Regras de utilização': ['Usage rules', 'Reglas de uso', 'Règles d’utilisation', 'Nutzungsbedingungen'],
    'Respostas sobre voos, notificações e segurança': ['Answers about flights, notifications and safety', 'Respuestas sobre vuelos, notificaciones y seguridad', 'Réponses sur les vols, les notifications et la sécurité', 'Antworten zu Flügen, Benachrichtigungen und Sicherheit'],
    'Informação para resolver problemas': ['Information to help solve issues', 'Información para resolver problemas', 'Informations pour résoudre les problèmes', 'Informationen zur Problemlösung'],
    'País da semana': ['Country of the week', 'País de la semana', 'Pays de la semaine', 'Land der Woche'],
    'Ainda não tens uma Chama acesa': ['You do not have an active Chama yet', 'Todavía no tienes una Chama activa', 'Tu n’as pas encore de Chama active', 'Du hast noch keine aktive Chama'],
    'Amigos pelo mundo': ['Friends around the world', 'Amigos por el mundo', 'Des amis dans le monde', 'Freunde auf der ganzen Welt'],
    'Chat privado': ['Private chat', 'Chat privado', 'Chat privé', 'Privater Chat'],
    'Ainda não tens Chats': ['You have no chats yet', 'Todavía no tienes chats', 'Tu n’as pas encore de discussions', 'Du hast noch keine Chats'],
    'A tua rede mundial': ['Your global network', 'Tu red mundial', 'Ton réseau mondial', 'Dein globales Netzwerk'],
    'Sem pedidos pendentes': ['No pending requests', 'No hay solicitudes pendientes', 'Aucune demande en attente', 'Keine offenen Anfragen'],
    'A tua lista está vazia': ['Your list is empty', 'Tu lista está vacía', 'Ta liste est vide', 'Deine Liste ist leer'],
    'A Chama só acende quando a resposta em avião chega ao remetente original. Os dois aviões ficam no início da conversa e o Chat permanece separado.': [
      'The Chama lights up only when a plane reply reaches the original sender. Both planes appear at the start of the conversation, while Chat remains separate.',
      'La Chama solo se enciende cuando la respuesta en avión llega al remitente original. Los dos aviones aparecen al inicio de la conversación y el Chat sigue separado.',
      'La Chama ne s’allume que lorsque la réponse en avion atteint l’expéditeur initial. Les deux avions apparaissent au début de la conversation et le Chat reste séparé.',
      'Die Chama wird erst aktiviert, wenn die Papierflieger-Antwort den ursprünglichen Absender erreicht. Beide Flieger stehen am Anfang der Unterhaltung; der Chat bleibt getrennt.',
    ],
    'Quando alguém te responde com um avião e essa resposta é entregue, a Chama abre automaticamente. Não é preciso adicionar a pessoa primeiro.': [
      'When someone replies with a plane and that reply is delivered, the Chama opens automatically. You do not need to add the person first.',
      'Cuando alguien responde con un avión y esa respuesta se entrega, la Chama se abre automáticamente. No hace falta añadir primero a la persona.',
      'Lorsqu’une personne répond avec un avion et que cette réponse est livrée, la Chama s’ouvre automatiquement. Il n’est pas nécessaire de l’ajouter d’abord.',
      'Wenn dir jemand mit einem Papierflieger antwortet und dieser zugestellt wird, öffnet sich die Chama automatisch. Du musst die Person nicht zuerst hinzufügen.',
    ],
    'Esta área é independente das Chamas. Abre um Chat com um amigo aceite, mesmo antes de trocarem aviões.': [
      'This area is separate from Chamas. Start a chat with an accepted friend, even before exchanging planes.',
      'Esta sección es independiente de las Chamas. Abre un chat con un amigo aceptado, incluso antes de intercambiar aviones.',
      'Cette section est indépendante des Chamas. Ouvre une discussion avec un ami accepté, même avant d’échanger des avions.',
      'Dieser Bereich ist unabhängig von Chamas. Starte einen Chat mit einem bestätigten Freund, auch bevor ihr Papierflieger austauscht.',
    ],
    'Vai a Amigos, procura um copiloto e abre um Chat depois de aceitarem o pedido de amizade.': [
      'Go to Friends, find a co-pilot and open a chat after the friend request is accepted.',
      'Ve a Amigos, busca un copiloto y abre un chat después de que acepten la solicitud de amistad.',
      'Va dans Amis, trouve un copilote et ouvre une discussion après l’acceptation de la demande d’amitié.',
      'Gehe zu Freunde, suche einen Co-Piloten und öffne einen Chat, nachdem die Freundschaftsanfrage angenommen wurde.',
    ],
    'Procura pelo nome de copiloto que começa com @. As amizades respeitam a faixa etária declarada e os bloqueios de segurança.': [
      'Search for a co-pilot name beginning with @. Friend connections respect declared age groups and safety blocks.',
      'Busca un nombre de copiloto que empiece por @. Las amistades respetan los grupos de edad declarados y los bloqueos de seguridad.',
      'Recherche un nom de copilote commençant par @. Les amitiés respectent les tranches d’âge déclarées et les blocages de sécurité.',
      'Suche nach einem Co-Pilot-Namen, der mit @ beginnt. Freundschaften berücksichtigen angegebene Altersgruppen und Sicherheitsblockierungen.',
    ],
    'Quando alguém te convidar, o pedido aparece aqui.': ['When someone invites you, the request appears here.', 'Cuando alguien te invite, la solicitud aparecerá aquí.', 'Lorsqu’une personne t’invite, sa demande apparaît ici.', 'Wenn dich jemand einlädt, erscheint die Anfrage hier.'],
    'Procura um @nome ou copia o teu link de convite para começar.': ['Search for an @name or copy your invitation link to get started.', 'Busca un @nombre o copia tu enlace de invitación para empezar.', 'Recherche un @nom ou copie ton lien d’invitation pour commencer.', 'Suche nach einem @Namen oder kopiere deinen Einladungslink, um loszulegen.'],
    'Chamas': ['Chamas', 'Chamas', 'Chamas', 'Chamas'],
    'Chat': ['Chat', 'Chat', 'Chat', 'Chat'],
    'Amigos': ['Friends', 'Amigos', 'Amis', 'Freunde'],
    'As tuas Chamas': ['Your Chamas', 'Tus Chamas', 'Tes Chamas', 'Deine Chamas'],
    'As tuas conversas': ['Your conversations', 'Tus conversaciones', 'Tes conversations', 'Deine Unterhaltungen'],
    'Resultados': ['Results', 'Resultados', 'Résultats', 'Ergebnisse'],
    'Pedidos recebidos': ['Received requests', 'Solicitudes recibidas', 'Demandes reçues', 'Erhaltene Anfragen'],
    'Pedidos enviados': ['Sent requests', 'Solicitudes enviadas', 'Demandes envoyées', 'Gesendete Anfragen'],
    'Adicionar': ['Add', 'Añadir', 'Ajouter', 'Hinzufügen'],
    'Pendente': ['Pending', 'Pendiente', 'En attente', 'Ausstehend'],
    'Todas': ['All', 'Todas', 'Toutes', 'Alle'],
    'Jogar': ['Play', 'Jugar', 'Jouer', 'Spielen'],
    'Missões': ['Missions', 'Misiones', 'Missions', 'Missionen'],
    'Crachás': ['Badges', 'Insignias', 'Badges', 'Abzeichen'],
    'Sequências': ['Streaks', 'Rachas', 'Séries', 'Serien'],
    'Excelente! +1 ponto': ['Excellent! +1 point', '¡Excelente! +1 punto', 'Excellent ! +1 point', 'Ausgezeichnet! +1 Punkt'],
    'Aprender também é ganhar': ['Learning is winning too', 'Aprender también es ganar', 'Apprendre, c’est aussi gagner', 'Lernen ist auch ein Gewinn'],
    'Ver resultado': ['See results', 'Ver resultado', 'Voir les résultats', 'Ergebnis ansehen'],
    'Próxima pergunta': ['Next question', 'Siguiente pregunta', 'Question suivante', 'Nächste Frage'],
    'Lenda do conhecimento!': ['Knowledge legend!', '¡Leyenda del conocimiento!', 'Légende du savoir !', 'Wissenslegende!'],
    'Excelente piloto!': ['Excellent pilot!', '¡Excelente piloto!', 'Excellent pilote !', 'Ausgezeichneter Pilot!'],
    'Boa viagem!': ['Good flight!', '¡Buen viaje!', 'Bon voyage !', 'Guten Flug!'],
    'Continua a explorar!': ['Keep exploring!', '¡Sigue explorando!', 'Continue à explorer !', 'Erkunde weiter!'],
    'XP a sincronizar': ['XP syncing', 'XP sincronizando', 'Synchronisation des XP', 'XP werden synchronisiert'],
    'A dobrar e lançar…': ['Folding and launching…', 'Doblándolo y lanzándolo…', 'Pliage et lancement…', 'Falten und starten…'],
    'Lançar o meu primeiro avião': ['Launch my first plane', 'Lanzar mi primer avión', 'Lancer mon premier avion', 'Meinen ersten Papierflieger starten'],
    'Rápido e direto': ['Fast and direct', 'Rápido y directo', 'Rapide et direct', 'Schnell und direkt'],
    'Asas largas': ['Wide wings', 'Alas anchas', 'Ailes larges', 'Breite Flügel'],
    'Leve e elegante': ['Light and elegant', 'Ligero y elegante', 'Léger et élégant', 'Leicht und elegant'],
    'Escreve algo gentil para o mundo…': ['Write something kind to the world…', 'Escribe algo amable para el mundo…', 'Écris quelque chose de gentil au monde…', 'Schreibe etwas Freundliches an die Welt…'],
    'Detalhes (opcional)': ['Details (optional)', 'Detalles (opcional)', 'Détails (facultatif)', 'Details (optional)'],
    'Conta-nos o que aconteceu…': ['Tell us what happened…', 'Cuéntanos qué pasó…', 'Raconte-nous ce qui s’est passé…', 'Erzähl uns, was passiert ist…'],
    'Assédio ou perseguição': ['Harassment or stalking', 'Acoso o persecución', 'Harcèlement ou traque', 'Belästigung oder Nachstellung'],
    'Ameaças ou violência': ['Threats or violence', 'Amenazas o violencia', 'Menaces ou violence', 'Drohungen oder Gewalt'],
    'Conteúdo sexual impróprio': ['Inappropriate sexual content', 'Contenido sexual inapropiado', 'Contenu sexuel inapproprié', 'Unangemessene sexuelle Inhalte'],
    'Abordagem suspeita ou aliciamento': ['Suspicious approach or grooming', 'Acercamiento sospechoso o captación', 'Approche suspecte ou manipulation', 'Verdächtige Kontaktaufnahme oder Grooming'],
    'Spam ou mensagens repetidas': ['Spam or repeated messages', 'Spam o mensajes repetidos', 'Spam ou messages répétitifs', 'Spam oder wiederholte Nachrichten'],
    'Exposição de dados pessoais': ['Exposure of personal information', 'Exposición de datos personales', 'Divulgation de données personnelles', 'Offenlegung persönlicher Daten'],
    'Falsificação de identidade': ['Impersonation', 'Suplantación de identidad', 'Usurpation d’identité', 'Identitätsbetrug'],
    'Outro motivo': ['Other reason', 'Otro motivo', 'Autre raison', 'Anderer Grund'],
    'Quilómetros': ['Kilometres', 'Kilómetros', 'Kilomètres', 'Kilometer'],
    'Voos concluídos': ['Completed flights', 'Vuelos completados', 'Vols terminés', 'Abgeschlossene Flüge'],
    'Em curso': ['In progress', 'En curso', 'En cours', 'In Bearbeitung'],
    'Dardo': ['Dart', 'Dardo', 'Fléchette', 'Pfeil'],
    'Planador': ['Glider', 'Planeador', 'Planeur', 'Segelflieger'],
    'Andorinha': ['Swallow', 'Golondrina', 'Hirondelle', 'Schwalbe'],
    'Os dados serão acrescentados quando o servidor registar os teus voos.': [
      'Data will be added when the server records your flights.',
      'Los datos se añadirán cuando el servidor registre tus vuelos.',
      'Les données seront ajoutées lorsque le serveur enregistrera tes vols.',
      'Die Daten werden ergänzt, sobald der Server deine Flüge registriert.',
    ],
    'Ainda não tens países registados nos teus voos. Quando uma rota real for concluída, os países aparecem aqui.': [
      'No countries are recorded for your flights yet. Countries will appear here when a real route is completed.',
      'Todavía no hay países registrados en tus vuelos. Los países aparecerán aquí cuando se complete una ruta real.',
      'Aucun pays n’est encore enregistré pour tes vols. Ils apparaîtront ici lorsqu’un itinéraire réel sera terminé.',
      'Für deine Flüge sind noch keine Länder gespeichert. Sie erscheinen hier, sobald eine echte Route abgeschlossen ist.',
    ],
    'Uma viagem de palavras até ao Japão': ['A journey of words to Japan', 'Un viaje de palabras hasta Japón', 'Un voyage de mots jusqu’au Japon', 'Eine Reise der Worte nach Japan'],
    'Bónus especial': ['Special bonus', 'Bono especial', 'Bonus spécial', 'Sonderbonus'],
    'Recompensas temáticas serão ativadas numa fase futura.': [
      'Themed rewards will be enabled in a future phase.',
      'Las recompensas temáticas se habilitarán en una fase futura.',
      'Les récompenses thématiques seront activées dans une prochaine phase.',
      'Thematische Belohnungen werden in einer späteren Phase aktiviert.',
    ],
    'Não foi possível abrir o Chat.': ['Could not open the chat.', 'No se pudo abrir el chat.', 'Impossible d’ouvrir le chat.', 'Der Chat konnte nicht geöffnet werden.'],
    'Completa primeiro o teu perfil de copiloto.': ['Complete your co-pilot profile first.', 'Completa primero tu perfil de copiloto.', 'Complète d’abord ton profil de copilote.', 'Vervollständige zuerst dein Co-Pilot-Profil.'],
    'Não encontrámos copilotos com esse nome.': ['We could not find co-pilots with that name.', 'No encontramos copilotos con ese nombre.', 'Aucun copilote trouvé avec ce nom.', 'Wir konnten keine Co-Piloten mit diesem Namen finden.'],
    'Escreve pelo menos duas letras do nome de copiloto.': ['Enter at least two letters of the co-pilot name.', 'Escribe al menos dos letras del nombre de copiloto.', 'Saisis au moins deux lettres du nom du copilote.', 'Gib mindestens zwei Buchstaben des Co-Pilot-Namens ein.'],
    'Amizade confirmada. A Chama acende quando trocarem aviões.': ['Friendship confirmed. The Chama lights up when you exchange planes.', 'Amistad confirmada. La Chama se enciende cuando intercambiéis aviones.', 'Amitié confirmée. La Chama s’allume lorsque vous échangez des avions.', 'Freundschaft bestätigt. Die Chama leuchtet auf, wenn ihr Papierflieger austauscht.'],
    'Pedido enviado. O outro copiloto pode aceitar no Chat.': ['Request sent. The other co-pilot can accept it in Chat.', 'Solicitud enviada. El otro copiloto puede aceptarla en Chat.', 'Demande envoyée. L’autre copilote peut l’accepter dans le Chat.', 'Anfrage gesendet. Der andere Co-Pilot kann sie im Chat annehmen.'],
    'Pedido aceite. Já fazem parte da lista de amigos.': ['Request accepted. You are now on each other’s friends list.', 'Solicitud aceptada. Ya estáis en la lista de amigos.', 'Demande acceptée. Vous figurez maintenant dans vos listes d’amis respectives.', 'Anfrage angenommen. Ihr steht nun gegenseitig auf euren Freundeslisten.'],
    'Pedido recusado.': ['Request declined.', 'Solicitud rechazada.', 'Demande refusée.', 'Anfrage abgelehnt.'],
    'Link de convite copiado. Partilha-o com quem quiseres adicionar.': ['Invitation link copied. Share it with anyone you want to add.', 'Enlace de invitación copiado. Compártelo con quien quieras añadir.', 'Lien d’invitation copié. Partage-le avec les personnes que tu souhaites ajouter.', 'Einladungslink kopiert. Teile ihn mit Personen, die du hinzufügen möchtest.'],
    'Não foi possível enviar o pedido.': ['Could not send the request.', 'No se pudo enviar la solicitud.', 'Impossible d’envoyer la demande.', 'Die Anfrage konnte nicht gesendet werden.'],
    'Não foi possível atualizar o pedido.': ['Could not update the request.', 'No se pudo actualizar la solicitud.', 'Impossible de mettre à jour la demande.', 'Die Anfrage konnte nicht aktualisiert werden.'],
    'Não foi possível alterar o idioma.': ['Could not change the language.', 'No se pudo cambiar el idioma.', 'Impossible de changer la langue.', 'Die Sprache konnte nicht geändert werden.'],
    'Idioma alterado para ': ['Language changed to ', 'Idioma cambiado a ', 'Langue modifiée en ', 'Sprache geändert zu '],
    'Não foi possível atualizar as tuas amizades e Chamas.': ['Could not update your friends and Chamas.', 'No se pudieron actualizar tus amigos y Chamas.', 'Impossible de mettre à jour tes amis et tes Chamas.', 'Deine Freunde und Chamas konnten nicht aktualisiert werden.'],
    'A pesquisa falhou. Tenta novamente.': ['Search failed. Try again.', 'La búsqueda falló. Inténtalo de nuevo.', 'La recherche a échoué. Réessaie.', 'Suche fehlgeschlagen. Versuche es erneut.'],
    'País': ['Country', 'País', 'Pays', 'Land'],
    'Mundo': ['World', 'Mundo', 'Monde', 'Welt'],
    'Moçambique': ['Mozambique', 'Mozambique', 'Mozambique', 'Mosambik'],
    'África do Sul': ['South Africa', 'Sudáfrica', 'Afrique du Sud', 'Südafrika'],
    'Angola': ['Angola', 'Angola', 'Angola', 'Angola'],
    'Índia': ['India', 'India', 'Inde', 'Indien'],
    'EUA': ['USA', 'EE. UU.', 'États-Unis', 'USA'],
    'Reino Unido': ['United Kingdom', 'Reino Unido', 'Royaume-Uni', 'Vereinigtes Königreich'],
    'França': ['France', 'Francia', 'France', 'Frankreich'],
    'Alemanha': ['Germany', 'Alemania', 'Allemagne', 'Deutschland'],
    'Nigéria': ['Nigeria', 'Nigeria', 'Nigéria', 'Nigeria'],
    'Egipto': ['Egypt', 'Egipto', 'Égypte', 'Ägypten'],
    'Espanha': ['Spain', 'España', 'Espagne', 'Spanien'],
    'Itália': ['Italy', 'Italia', 'Italie', 'Italien'],
    'China': ['China', 'China', 'Chine', 'China'],
    'Coreia do Sul': ['South Korea', 'Corea del Sur', 'Corée du Sud', 'Südkorea'],
    'Austrália': ['Australia', 'Australia', 'Australie', 'Australien'],
    'Canadá': ['Canada', 'Canadá', 'Canada', 'Kanada'],
    'Estados Unidos': ['United States', 'Estados Unidos', 'États-Unis', 'Vereinigte Staaten'],
    'Países Baixos': ['Netherlands', 'Países Bajos', 'Pays-Bas', 'Niederlande'],
    'Suíça': ['Switzerland', 'Suiza', 'Suisse', 'Schweiz'],
    'Áustria': ['Austria', 'Austria', 'Autriche', 'Österreich'],
    'Grécia': ['Greece', 'Grecia', 'Grèce', 'Griechenland'],
    'Turquia': ['Turkey', 'Turquía', 'Turquie', 'Türkei'],
    'Zimbabwe': ['Zimbabwe', 'Zimbabue', 'Zimbabwe', 'Simbabwe'],
    'Zâmbia': ['Zambia', 'Zambia', 'Zambie', 'Sambia'],
    'Botswana': ['Botswana', 'Botsuana', 'Botswana', 'Botswana'],
    'Namíbia': ['Namibia', 'Namibia', 'Namibie', 'Namibia'],
    'Quénia': ['Kenya', 'Kenia', 'Kenya', 'Kenia'],
    'Etiópia': ['Ethiopia', 'Etiopía', 'Éthiopie', 'Äthiopien'],
    'Uganda': ['Uganda', 'Uganda', 'Ouganda', 'Uganda'],
    'Ruanda': ['Rwanda', 'Ruanda', 'Rwanda', 'Ruanda'],
    'Burundi': ['Burundi', 'Burundi', 'Burundi', 'Burundi'],
    'Madagáscar': ['Madagascar', 'Madagascar', 'Madagascar', 'Madagaskar'],
    'Maurícia': ['Mauritius', 'Mauricio', 'Maurice', 'Mauritius'],
    'Gana': ['Ghana', 'Ghana', 'Ghana', 'Ghana'],
    'Senegal': ['Senegal', 'Senegal', 'Sénégal', 'Senegal'],
    'Marrocos': ['Morocco', 'Marruecos', 'Maroc', 'Marokko'],
    'Tunísia': ['Tunisia', 'Túnez', 'Tunisie', 'Tunesien'],
    'Argélia': ['Algeria', 'Argelia', 'Algérie', 'Algerien'],
    'Noruega': ['Norway', 'Noruega', 'Norvège', 'Norwegen'],
    'Suécia': ['Sweden', 'Suecia', 'Suède', 'Schweden'],
    'Finlândia': ['Finland', 'Finlandia', 'Finlande', 'Finnland'],
    'Dinamarca': ['Denmark', 'Dinamarca', 'Danemark', 'Dänemark'],
    'Islândia': ['Iceland', 'Islandia', 'Islande', 'Island'],
    'Polónia': ['Poland', 'Polonia', 'Pologne', 'Polen'],
    'Chéquia': ['Czechia', 'Chequia', 'Tchéquie', 'Tschechien'],
    'Rússia': ['Russia', 'Rusia', 'Russie', 'Russland'],
    'Irlanda': ['Ireland', 'Irlanda', 'Irlande', 'Irland'],
    'Croácia': ['Croatia', 'Croacia', 'Croatie', 'Kroatien'],
    'Sérvia': ['Serbia', 'Serbia', 'Serbie', 'Serbien'],
    'Roménia': ['Romania', 'Rumanía', 'Roumanie', 'Rumänien'],
    'Bulgária': ['Bulgaria', 'Bulgaria', 'Bulgarie', 'Bulgarien'],
    'Ucrânia': ['Ukraine', 'Ucrania', 'Ukraine', 'Ukraine'],

    'O servidor vai parar a procura ou o voo antes da entrega.': [
      'The server will stop the search or flight before delivery.',
      'El servidor detendrá la búsqueda o el vuelo antes de la entrega.',
      'Le serveur arrêtera la recherche ou le vol avant la livraison.',
      'Der Server stoppt die Suche oder den Flug vor der Zustellung.',
    ],
    'Continuar voo': ['Continue flight', 'Continuar vuelo', 'Continuer le vol', 'Flug fortsetzen'],
    'O avião deixa de aparecer no teu histórico. A cópia já entregue à outra pessoa mantém-se.': [
      'The plane will disappear from your history. A copy already delivered to the other person will remain.',
      'El avión dejará de aparecer en tu historial. La copia ya entregada a la otra persona se conservará.',
      'L’avion disparaîtra de ton historique. La copie déjà remise à l’autre personne sera conservée.',
      'Der Papierflieger verschwindet aus deinem Verlauf. Eine bereits zugestellte Kopie bleibt erhalten.',
    ],
    'Eliminar da minha Caixa': ['Remove from my inbox', 'Eliminar de mi bandeja', 'Retirer de ma boîte de réception', 'Aus meinem Posteingang entfernen'],
    'Remetente bloqueado.': ['Sender blocked.', 'Remitente bloqueado.', 'Expéditeur bloqué.', 'Absender blockiert.'],
    'Bloquear remetente': ['Block sender', 'Bloquear remitente', 'Bloquer l’expéditeur', 'Absender blockieren'],
    'A tua foto de perfil': ['Your profile photo', 'Tu foto de perfil', 'Ta photo de profil', 'Dein Profilbild'],
    'Podes usar um link de imagem ou de uma página pública. O Paper Plane tenta encontrar a fotografia automaticamente.': [
      'You can use an image link or a public page. Paper Plane will try to find the photo automatically.',
      'Puedes usar un enlace a una imagen o a una página pública. Paper Plane intentará encontrar la foto automáticamente.',
      'Tu peux utiliser un lien vers une image ou une page publique. Paper Plane essaiera de trouver la photo automatiquement.',
      'Du kannst einen Bildlink oder eine öffentliche Seite verwenden. Paper Plane versucht, das Foto automatisch zu finden.',
    ],
    'Partilha o teu link para que outros copilotos possam encontrar-te e começar a trocar aviões.': [
      'Share your link so other co-pilots can find you and start exchanging planes.',
      'Comparte tu enlace para que otros copilotos puedan encontrarte y empezar a intercambiar aviones.',
      'Partage ton lien pour que d’autres copilotes puissent te trouver et commencer à échanger des avions.',
      'Teile deinen Link, damit andere Co-Piloten dich finden und Papierflieger austauschen können.',
    ],
    'O teu link de convite pessoal': ['Your personal invitation link', 'Tu enlace de invitación personal', 'Ton lien d’invitation personnel', 'Dein persönlicher Einladungslink'],
    'Os dados do perfil e os totais são obtidos no servidor Paper Plane.': [
      'Profile data and totals are retrieved from the Paper Plane server.',
      'Los datos del perfil y los totales se obtienen del servidor de Paper Plane.',
      'Les données du profil et les totaux proviennent du serveur Paper Plane.',
      'Profildaten und Gesamtwerte werden vom Paper-Plane-Server abgerufen.',
    ],
    'Piloto associado': ['Linked pilot', 'Piloto asociado', 'Pilote associé', 'Verbundener Pilot'],
    'Ligação privada de demonstração': ['Private demo link', 'Enlace privado de demostración', 'Lien privé de démonstration', 'Privater Demo-Link'],
    'Uma chama precisa de respeito, cuidado e consentimento dos dois pilotos.': [
      'A Chama requires respect, care and consent from both pilots.',
      'Una Chama necesita respeto, cuidado y consentimiento de ambos pilotos.',
      'Une Chama exige du respect, de l’attention et le consentement des deux pilotes.',
      'Eine Chama braucht Respekt, Sorgfalt und die Zustimmung beider Piloten.',
    ],
    'A conversa só continua com a escolha livre dos dois.': [
      'The conversation continues only if both people freely choose to continue.',
      'La conversación continúa solo si ambas personas eligen libremente continuar.',
      'La conversation ne continue que si les deux personnes le choisissent librement.',
      'Das Gespräch wird nur fortgesetzt, wenn beide Personen freiwillig zustimmen.',
    ],
    'Pré-visualização — mensagens privadas ainda desativadas.': [
      'Preview — private messages are not enabled yet.',
      'Vista previa: los mensajes privados aún no están habilitados.',
      'Aperçu — les messages privés ne sont pas encore activés.',
      'Vorschau — private Nachrichten sind noch nicht aktiviert.',
    ],
    'Comunicar problema': ['Report a problem', 'Comunicar un problema', 'Signaler un problème', 'Problem melden'],
    'Sair': ['Exit', 'Salir', 'Quitter', 'Beenden'],
    'Convida amigos para voar': ['Invite friends to fly', 'Invita a tus amigos a volar', 'Invite tes amis à voler', 'Lade Freunde zum Fliegen ein'],
    'Partilha o teu convite e espalha palavras gentis.': [
      'Share your invitation and spread kind words.',
      'Comparte tu invitación y difunde palabras amables.',
      'Partage ton invitation et fais circuler des mots gentils.',
      'Teile deine Einladung und verbreite freundliche Worte.',
    ],
    'O teu link de convite': ['Your invitation link', 'Tu enlace de invitación', 'Ton lien d’invitation', 'Dein Einladungslink'],
    'O link será disponibilizado após configurar os convites.': [
      'The link will be available once invitations are configured.',
      'El enlace estará disponible cuando se configuren las invitaciones.',
      'Le lien sera disponible une fois les invitations configurées.',
      'Der Link wird verfügbar sein, sobald Einladungen eingerichtet sind.',
    ],
    'Código QR de convite (pré-visualização)': [
      'Invitation QR code (preview)', 'Código QR de invitación (vista previa)',
      'Code QR d’invitation (aperçu)', 'Einladungs-QR-Code (Vorschau)',
    ],
    'A partilha será ligada quando o link estiver ativo.': [
      'Sharing will be enabled when the link is active.',
      'La función de compartir se activará cuando el enlace esté disponible.',
      'Le partage sera activé lorsque le lien sera disponible.',
      'Teilen wird aktiviert, sobald der Link aktiv ist.',
    ],
    'Link de demonstração — ainda não ativo.': [
      'Demo link — not active yet.', 'Enlace de demostración: aún no está activo.',
      'Lien de démonstration — pas encore actif.', 'Demo-Link — noch nicht aktiv.',
    ],
    'Os convites e recompensas serão ativados após a configuração da conta e do servidor.': [
      'Invitations and rewards will be enabled after account and server setup.',
      'Las invitaciones y recompensas se activarán después de configurar la cuenta y el servidor.',
      'Les invitations et les récompenses seront activées après la configuration du compte et du serveur.',
      'Einladungen und Belohnungen werden nach der Einrichtung von Konto und Server aktiviert.',
    ],
    'Proteção antes da entrega': ['Protection before delivery', 'Protección antes de la entrega', 'Protection avant la livraison', 'Schutz vor der Zustellung'],
    'A correspondência aleatória usa a faixa etária declarada no perfil para separar grupos. É uma declaração do próprio utilizador, não uma verificação de identidade nem uma prova de idade.': [
      'Random mail uses the age group declared in the profile to separate groups. This is user-declared information, not identity or age verification.',
      'El correo aleatorio utiliza el grupo de edad declarado en el perfil para separar grupos. Es una declaración del usuario, no una verificación de identidad ni de edad.',
      'Le courrier aléatoire utilise la tranche d’âge déclarée dans le profil pour séparer les groupes. Il s’agit d’une déclaration de l’utilisateur, pas d’une vérification d’identité ou d’âge.',
      'Zufällige Post verwendet die im Profil angegebene Altersgruppe zur Trennung der Gruppen. Dies ist eine Selbstauskunft und keine Identitäts- oder Altersprüfung.',
    ],
    'Denunciar uma carta': ['Report a letter', 'Denunciar una carta', 'Signaler une lettre', 'Brief melden'],
    'Abre o avião recebido e escolhe Denunciar. A denúncia é enviada ao servidor para revisão.': [
      'Open the received plane and choose Report. The report is sent to the server for review.',
      'Abre el avión recibido y elige Denunciar. El informe se envía al servidor para su revisión.',
      'Ouvre l’avion reçu et choisis Signaler. Le signalement est envoyé au serveur pour examen.',
      'Öffne den empfangenen Papierflieger und wähle Melden. Der Bericht wird zur Prüfung an den Server gesendet.',
    ],
    'Bloquear um remetente': ['Block a sender', 'Bloquear a un remitente', 'Bloquer un expéditeur', 'Einen Absender blockieren'],
    'Abre o avião recebido e escolhe Bloquear. O servidor impede novas correspondências entre as duas contas.': [
      'Open the received plane and choose Block. The server prevents further mail between the two accounts.',
      'Abre el avión recibido y elige Bloquear. El servidor impide nuevos mensajes entre las dos cuentas.',
      'Ouvre l’avion reçu et choisis Bloquer. Le serveur empêche tout nouvel échange entre les deux comptes.',
      'Öffne den empfangenen Papierflieger und wähle Blockieren. Der Server verhindert weitere Nachrichten zwischen den beiden Konten.',
    ],
    'Identidade protegida': ['Identity protected', 'Identidad protegida', 'Identité protégée', 'Identität geschützt'],
    'Nas cartas aleatórias, o remetente não recebe o teu nome de conta nem o teu identificador Firebase. O país é a única referência geográfica mostrada nesta versão.': [
      'For random letters, the sender does not receive your account name or Firebase identifier. Your country is the only geographic reference shown in this version.',
      'En las cartas aleatorias, el remitente no recibe tu nombre de cuenta ni tu identificador de Firebase. El país es la única referencia geográfica que se muestra en esta versión.',
      'Pour les lettres aléatoires, l’expéditeur ne reçoit ni ton nom de compte ni ton identifiant Firebase. Le pays est la seule référence géographique affichée dans cette version.',
      'Bei zufälligen Briefen erhält der Absender weder deinen Kontonamen noch deine Firebase-Kennung. Das Land ist in dieser Version die einzige angezeigte geografische Angabe.',
    ],
    'Não partilhes morada, contactos, palavras-passe, escola ou outros dados pessoais com desconhecidos. Se uma carta te fizer sentir desconfortável, não respondas: denuncia e bloqueia.': [
      'Do not share your address, contacts, passwords, school or other personal information with strangers. If a letter makes you uncomfortable, do not reply: report and block.',
      'No compartas tu dirección, contactos, contraseñas, escuela ni otros datos personales con desconocidos. Si una carta te incomoda, no respondas: denúnciala y bloquea.',
      'Ne partage pas ton adresse, tes contacts, mots de passe, école ou autres données personnelles avec des inconnus. Si une lettre te met mal à l’aise, ne réponds pas : signale-la et bloque son auteur.',
      'Teile deine Adresse, Kontakte, Passwörter, Schule oder andere persönliche Daten nicht mit Fremden. Wenn dich ein Brief beunruhigt, antworte nicht: Melde und blockiere den Absender.',
    ],

    'Matemática': ['Mathematics', 'Matemáticas', 'Mathématiques', 'Mathematik'],
    'Geografia': ['Geography', 'Geografía', 'Géographie', 'Geografie'],
    'Natureza': ['Nature', 'Naturaleza', 'Nature', 'Natur'],
    'Ciência': ['Science', 'Ciencia', 'Sciences', 'Wissenschaft'],
    'Tecnologia': ['Technology', 'Tecnología', 'Technologie', 'Technologie'],
    'Cultura': ['Culture', 'Cultura', 'Culture', 'Kultur'],
    'Desporto': ['Sports', 'Deportes', 'Sport', 'Sport'],
    'Entretenimento': ['Entertainment', 'Entretenimiento', 'Divertissement', 'Unterhaltung'],
    'África do Sul (capital administrativa)': ['South Africa (administrative capital)', 'Sudáfrica (capital administrativa)', 'Afrique du Sud (capitale administrative)', 'Südafrika (Verwaltungshauptstadt)'],
    'Tanzânia': ['Tanzania', 'Tanzania', 'Tanzanie', 'Tansania'],
    'Egito': ['Egypt', 'Egipto', 'Égypte', 'Ägypten'],
    'Tailândia': ['Thailand', 'Tailandia', 'Thaïlande', 'Thailand'],
    'Vietname': ['Vietnam', 'Vietnam', 'Vietnam', 'Vietnam'],
    'Filipinas': ['Philippines', 'Filipinas', 'Philippines', 'Philippinen'],
    'Paquistão': ['Pakistan', 'Pakistán', 'Pakistan', 'Pakistan'],
    'Nepal': ['Nepal', 'Nepal', 'Népal', 'Nepal'],
    'Bangladesh': ['Bangladesh', 'Bangladés', 'Bangladesh', 'Bangladesch'],
    'Nova Zelândia': ['New Zealand', 'Nueva Zelanda', 'Nouvelle-Zélande', 'Neuseeland'],
    'México': ['Mexico', 'México', 'Mexique', 'Mexiko'],
    'Argentina': ['Argentina', 'Argentina', 'Argentine', 'Argentinien'],
    'Chile': ['Chile', 'Chile', 'Chili', 'Chile'],
    'Peru': ['Peru', 'Perú', 'Pérou', 'Peru'],
    'Colômbia': ['Colombia', 'Colombia', 'Colombie', 'Kolumbien'],
    'Venezuela': ['Venezuela', 'Venezuela', 'Venezuela', 'Venezuela'],
    'Cuba': ['Cuba', 'Cuba', 'Cuba', 'Kuba'],
    'Pretória': ['Pretoria', 'Pretoria', 'Pretoria', 'Pretoria'],
    'Adis Abeba': ['Addis Ababa', 'Adís Abeba', 'Addis-Abeba', 'Addis Abeba'],
    'Campala': ['Kampala', 'Kampala', 'Kampala', 'Kampala'],
    'Antananarivo': ['Antananarivo', 'Antananarivo', 'Antananarivo', 'Antananarivo'],
    'Banguecoque': ['Bangkok', 'Bangkok', 'Bangkok', 'Bangkok'],
    'Hanói': ['Hanoi', 'Hanói', 'Hanoï', 'Hanoi'],
    'Nova Deli': ['New Delhi', 'Nueva Delhi', 'New Delhi', 'Neu-Delhi'],
    'Catmandu': ['Kathmandu', 'Katmandú', 'Katmandou', 'Kathmandu'],
    'Daca': ['Dhaka', 'Daca', 'Dacca', 'Dhaka'],
    'Camberra': ['Canberra', 'Canberra', 'Canberra', 'Canberra'],
    'Otava': ['Ottawa', 'Ottawa', 'Ottawa', 'Ottawa'],
    'Cidade do México': ['Mexico City', 'Ciudad de México', 'Mexico', 'Mexiko-Stadt'],
    'Brasília': ['Brasilia', 'Brasilia', 'Brasilia', 'Brasília'],
    'Buenos Aires': ['Buenos Aires', 'Buenos Aires', 'Buenos Aires', 'Buenos Aires'],
    'Bogotá': ['Bogota', 'Bogotá', 'Bogota', 'Bogotá'],
    'Havana': ['Havana', 'La Habana', 'La Havane', 'Havanna'],
    'Dublim': ['Dublin', 'Dublín', 'Dublin', 'Dublin'],
    'Amesterdão': ['Amsterdam', 'Ámsterdam', 'Amsterdam', 'Amsterdam'],
    'Quieve': ['Kyiv', 'Kiev', 'Kyiv', 'Kyjiw'],
    'Moscovo': ['Moscow', 'Moscú', 'Moscou', 'Moskau'],

    'O mundo que as tuas cartas estão a ligar.': [
      'The world your letters are connecting.',
      'El mundo que conectan tus cartas.',
      'Le monde que tes lettres relient.',
      'Die Welt, die deine Briefe verbinden.',
    ],
    'PAÍSES LIGADOS ÀS TUAS CARTAS': ['COUNTRIES CONNECTED BY YOUR LETTERS', 'PAÍSES CONECTADOS POR TUS CARTAS', 'PAYS RELIÉS PAR TES LETTRES', 'LÄNDER, DIE DEINE BRIEFE VERBINDEN'],
    'O teu atlas está à espera da primeira rota.': [
      'Your atlas is waiting for its first route.', 'Tu atlas espera su primera ruta.',
      'Ton atlas attend son premier itinéraire.', 'Dein Atlas wartet auf seine erste Route.',
    ],
    'Quando uma carta encontrar um destinatário e tiver uma rota registada, os países ligados aparecerão aqui.': [
      'When a letter finds a recipient and has a recorded route, the connected countries will appear here.',
      'Cuando una carta encuentre un destinatario y tenga una ruta registrada, los países conectados aparecerán aquí.',
      'Lorsqu’une lettre trouvera un destinataire et qu’un itinéraire sera enregistré, les pays reliés apparaîtront ici.',
      'Sobald ein Brief einen Empfänger findet und eine Route gespeichert ist, erscheinen die verbundenen Länder hier.',
    ],
    'Ainda não há países registados nos teus voos. Quando uma rota real for concluída, os países aparecem aqui.': [
      'No countries are recorded for your flights yet. Countries will appear here when a real route is completed.',
      'Todavía no hay países registrados en tus vuelos. Aparecerán aquí cuando se complete una ruta real.',
      'Aucun pays n’est encore enregistré pour tes vols. Ils apparaîtront ici lorsqu’un itinéraire réel sera terminé.',
      'Für deine Flüge sind noch keine Länder gespeichert. Sie erscheinen hier, sobald eine echte Route abgeschlossen ist.',
    ],
    'Os aviões recebidos, a aplicação e as traduções usam este idioma.': [
      'Incoming planes, the app and translations use this language.',
      'Los aviones recibidos, la aplicación y las traducciones usan este idioma.',
      'Les avions reçus, l’application et les traductions utilisent cette langue.',
      'Eingehende Papierflieger, die App und Übersetzungen verwenden diese Sprache.',
    ],
    'Olá,': ['Hello,', 'Hola,', 'Bonjour,', 'Hallo,'],
    '🇯🇵': ['🇯🇵', '🇯🇵', '🇯🇵', '🇯🇵'],

    "Completa a tua data de nascimento no perfil antes de enviar.": ["Complete your date of birth in your profile before sending.","Completa tu fecha de nacimiento en el perfil antes de enviar.","Renseigne ta date de naissance dans ton profil avant d’envoyer.","Ergänze vor dem Senden dein Geburtsdatum in deinem Profil."],
    "Indica uma data de nascimento válida.": ["Enter a valid date of birth.","Introduce una fecha de nacimiento válida.","Saisis une date de naissance valide.","Gib ein gültiges Geburtsdatum ein."],
    "Usa um link HTTPS público para a tua foto ou perfil.": ["Use a public HTTPS link for your photo or profile.","Usa un enlace HTTPS público para tu foto o perfil.","Utilise un lien HTTPS public pour ta photo ou ton profil.","Verwende einen öffentlichen HTTPS-Link für dein Foto oder Profil."],
    "Não foi possível carregar a pré-visualização deste link.": ["This link preview could not be loaded.","No se pudo cargar la vista previa de este enlace.","Impossible de charger l’aperçu de ce lien.","Die Linkvorschau konnte nicht geladen werden."],
    "A Chama funciona através de aviões de resposta.": ["Chama works through reply planes.","Chama funciona mediante aviones de respuesta.","Chama fonctionne grâce aux avions-réponses.","Chama funktioniert über Antwort-Papierflieger."],
    "Esta Chama foi encerrada.": ["This Chama has ended.","Esta Chama ha terminado.","Cette Chama est terminée.","Diese Chama wurde beendet."],
    "O Paper Plane está disponível a partir dos 13 anos.": ["Paper Plane is available from age 13.","Paper Plane está disponible a partir de los 13 años.","Paper Plane est disponible à partir de 13 ans.","Paper Plane ist ab 13 Jahren verfügbar."],
    "Não foi possível confirmar a tua sessão Firebase. Entra novamente na conta.": ["Your Firebase session could not be confirmed. Sign in again.","No se pudo confirmar tu sesión de Firebase. Inicia sesión de nuevo.","Impossible de confirmer ta session Firebase. Reconnecte-toi.","Deine Firebase-Sitzung konnte nicht bestätigt werden. Melde dich erneut an."],
    "Já lançaste o teu avião original de hoje.": ["You have already launched your original plane for today.","Ya has lanzado tu avión original de hoy.","Tu as déjà lancé ton avion original aujourd’hui.","Du hast deinen heutigen ursprünglichen Papierflieger bereits gestartet."],
    "A mensagem contém conteúdo que não é permitido.": ["The message contains content that is not allowed.","El mensaje contiene contenido no permitido.","Le message contient du contenu interdit.","Die Nachricht enthält unzulässige Inhalte."],
    "A mensagem ficou retida para revisão de segurança.": ["The message was held for a safety review.","El mensaje se ha retenido para una revisión de seguridad.","Le message a été retenu pour un examen de sécurité.","Die Nachricht wurde zur Sicherheitsprüfung zurückgehalten."],
    "A verificação de segurança está temporariamente indisponível. A resposta não foi publicada; tenta novamente mais tarde.": ["The safety check is temporarily unavailable. The reply was not published; try again later.","La verificación de seguridad no está disponible temporalmente. La respuesta no se publicó; inténtalo más tarde.","La vérification de sécurité est temporairement indisponible. La réponse n’a pas été publiée ; réessaie plus tard.","Die Sicherheitsprüfung ist vorübergehend nicht verfügbar. Die Antwort wurde nicht veröffentlicht. Versuche es später erneut."],
    "Esta mensagem não passou na verificação de segurança. Reformula o texto e tenta novamente.": ["This message did not pass the safety check. Reword it and try again.","Este mensaje no superó la verificación de seguridad. Reformúlalo e inténtalo de nuevo.","Ce message n’a pas passé le contrôle de sécurité. Reformule-le et réessaie.","Diese Nachricht hat die Sicherheitsprüfung nicht bestanden. Formuliere sie um und versuche es erneut."],
    "Este avião já atingiu o limite de cinco respostas públicas.": ["This plane has reached the limit of five public replies.","Este avión ha alcanzado el límite de cinco respuestas públicas.","Cet avion a atteint la limite de cinq réponses publiques.","Dieser Papierflieger hat die Grenze von fünf öffentlichen Antworten erreicht."],
    "Esta mensagem já foi enviada recentemente.": ["This message was sent recently.","Este mensaje ya se ha enviado recientemente.","Ce message a déjà été envoyé récemment.","Diese Nachricht wurde vor Kurzem bereits gesendet."],
    "Atingiste o limite de mensagens por hora. Tenta novamente mais tarde.": ["You have reached the hourly message limit. Try again later.","Has alcanzado el límite de mensajes por hora. Inténtalo más tarde.","Tu as atteint la limite de messages par heure. Réessaie plus tard.","Du hast das Nachrichtenlimit pro Stunde erreicht. Versuche es später erneut."],
    "Completa primeiro o perfil do piloto.": ["Complete the pilot profile first.","Completa primero el perfil del piloto.","Complète d’abord le profil du pilote.","Vervollständige zuerst das Pilotenprofil."],
    "Esse nome de copiloto já existe. Escolhe outro.": ["That co-pilot name is already taken. Choose another.","Ese nombre de copiloto ya existe. Elige otro.","Ce nom de copilote est déjà utilisé. Choisis-en un autre.","Dieser Copilot-Name ist bereits vergeben. Wähle einen anderen."],
    "Não encontrámos um copiloto ativo com esse @nome.": ["We could not find an active co-pilot with that @name.","No encontramos un copiloto activo con ese @nombre.","Aucun copilote actif ne correspond à ce @nom.","Wir haben keinen aktiven Copiloten mit diesem @Namen gefunden."],
    "Por segurança, só podes adicionar pessoas da mesma faixa etária declarada.": ["For safety, you can only add people in the same declared age group.","Por seguridad, solo puedes añadir personas del mismo grupo de edad declarado.","Pour des raisons de sécurité, tu ne peux ajouter que des personnes de la même tranche d’âge déclarée.","Aus Sicherheitsgründen kannst du nur Personen aus derselben angegebenen Altersgruppe hinzufügen."],
    "Esta conversa já não está disponível.": ["This conversation is no longer available.","Esta conversación ya no está disponible.","Cette conversation n’est plus disponible.","Diese Unterhaltung ist nicht mehr verfügbar."],
    "Este avião já não está disponível.": ["This plane is no longer available.","Este avión ya no está disponible.","Cet avion n’est plus disponible.","Dieser Papierflieger ist nicht mehr verfügbar."],
    "Este voo já chegou ou não pode ser cancelado.": ["This flight has already arrived or cannot be cancelled.","Este vuelo ya ha llegado o no se puede cancelar.","Ce vol est déjà arrivé ou ne peut pas être annulé.","Dieser Flug ist bereits angekommen oder kann nicht storniert werden."],
    "Não é possível enviar mensagens nesta conversa.": ["Messages cannot be sent in this conversation.","No se pueden enviar mensajes en esta conversación.","L’envoi de messages est impossible dans cette conversation.","In dieser Unterhaltung können keine Nachrichten gesendet werden."],
    "Atingiste o limite temporário de mensagens. Tenta novamente mais tarde.": ["You have reached the temporary message limit. Try again later.","Has alcanzado el límite temporal de mensajes. Inténtalo más tarde.","Tu as atteint la limite temporaire de messages. Réessaie plus tard.","Du hast das vorübergehende Nachrichtenlimit erreicht. Versuche es später erneut."],
    "Aceitem primeiro o pedido de amizade para abrir um Chat privado.": ["Accept the friend request first to open a private Chat.","Aceptad primero la solicitud de amistad para abrir un Chat privado.","Acceptez d’abord la demande d’ami pour ouvrir un Chat privé.","Nehmt zuerst die Freundschaftsanfrage an, um einen privaten Chat zu öffnen."],
    "Ainda falta cumprir esta missão.": ["This mission has not been completed yet.","Todavía tienes que completar esta misión.","Cette mission n’est pas encore accomplie.","Diese Mission muss noch abgeschlossen werden."],
    "Já resgataste esta recompensa.": ["You have already claimed this reward.","Ya has canjeado esta recompensa.","Tu as déjà récupéré cette récompense.","Du hast diese Belohnung bereits eingelöst."],
    "Já concluíste muitas rondas hoje. Volta amanhã para continuar.": ["You have completed many rounds today. Come back tomorrow to continue.","Hoy ya has completado muchas rondas. Vuelve mañana para continuar.","Tu as déjà terminé beaucoup de manches aujourd’hui. Reviens demain pour continuer.","Du hast heute bereits viele Runden abgeschlossen. Komm morgen wieder, um weiterzuspielen."],
    "Usa 4 a 28 caracteres: letras, números, _ e um sufixo como -07.": ["Use 4 to 28 characters: letters, numbers, _ and a suffix such as -07.","Usa de 4 a 28 caracteres: letras, números, _ y un sufijo como -07.","Utilise de 4 à 28 caractères : lettres, chiffres, _ et un suffixe comme -07.","Verwende 4 bis 28 Zeichen: Buchstaben, Zahlen, _ und ein Suffix wie -07."],
    "Indica um ano de nascimento válido.": ["Enter a valid birth year.","Introduce un año de nacimiento válido.","Saisis une année de naissance valide.","Gib ein gültiges Geburtsjahr ein."],
    "Escolhe um país válido.": ["Choose a valid country.","Elige un país válido.","Choisis un pays valide.","Wähle ein gültiges Land aus."],
    "Escolhe uma categoria de denúncia válida.": ["Choose a valid report category.","Elige una categoría de denuncia válida.","Choisis une catégorie de signalement valide.","Wähle eine gültige Meldekategorie aus."],
    "Já existe uma denúncia tua em análise para esta mensagem.": ["You already have a report under review for this message.","Ya tienes una denuncia en revisión para este mensaje.","Un signalement de ta part concernant ce message est déjà en cours d’examen.","Für diese Nachricht wird bereits eine Meldung von dir geprüft."],
    "Atingiste o limite diário de denúncias. Tenta novamente mais tarde.": ["You have reached the daily report limit. Try again later.","Has alcanzado el límite diario de denuncias. Inténtalo más tarde.","Tu as atteint la limite quotidienne de signalements. Réessaie plus tard.","Du hast das tägliche Meldelimit erreicht. Versuche es später erneut."],
    "Este avião público já não está disponível para responder.": ["This public plane is no longer available for replies.","Este avión público ya no está disponible para responder.","Il n’est plus possible de répondre à cet avion public.","Auf diesen öffentlichen Papierflieger kann nicht mehr geantwortet werden."],
    "Escolhe uma categoria de suporte válida.": ["Choose a valid support category.","Elige una categoría de soporte válida.","Choisis une catégorie d’assistance valide.","Wähle eine gültige Supportkategorie aus."],
    "Preenche o assunto e descreve o problema com mais detalhes.": ["Enter a subject and describe the issue in more detail.","Escribe el asunto y describe el problema con más detalle.","Indique un sujet et décris le problème plus précisément.","Gib einen Betreff ein und beschreibe das Problem genauer."],
    "Atingiste o limite diário de pedidos de suporte.": ["You have reached the daily support request limit.","Has alcanzado el límite diario de solicitudes de soporte.","Tu as atteint la limite quotidienne de demandes d’assistance.","Du hast das tägliche Limit für Supportanfragen erreicht."],
    "Atualizar": ["Refresh","Actualizar","Actualiser","Aktualisieren"],
    "Opções da conversa": ["Conversation options","Opciones de la conversación","Options de la conversation","Unterhaltungsoptionen"],
    "Nova atividade no Paper Plane": ["New activity on Paper Plane","Nueva actividad en Paper Plane","Nouvelle activité sur Paper Plane","Neue Aktivität bei Paper Plane"],
    "Tens uma atualização na tua caixa de entrada.": ["You have an update in your inbox.","Tienes una actualización en tu bandeja de entrada.","Tu as une mise à jour dans ta boîte de réception.","Du hast eine Aktualisierung in deinem Posteingang."],
    "Novos aviões, mensagens e avisos importantes.": ["New planes, messages and important alerts.","Nuevos aviones, mensajes y avisos importantes.","Nouveaux avions, messages et alertes importantes.","Neue Papierflieger, Nachrichten und wichtige Hinweise."],
    "Abrir carta": ["Open letter","Abrir carta","Ouvrir la lettre","Brief öffnen"],
    "Abrir caixa": ["Open inbox","Abrir bandeja","Ouvrir la boîte de réception","Posteingang öffnen"],
  };
}

/// Drop-in text widget so existing screens can use the selected app language
/// without changing user-generated message content.
class PlaneText extends StatelessWidget {
  const PlaneText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const PlaneText.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final TextSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  TextSpan _translateSpan(TextSpan span, String language) {
    return TextSpan(
        text: span.text == null ? null : PaperPlaneLocale.translate(span.text!, language),
        children: span.children?.map((child) => child is TextSpan ? _translateSpan(child, language) : child).toList(),
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    if (textSpan != null) {
      return Text.rich(
        _translateSpan(textSpan!, language),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return Text(
      PaperPlaneLocale.translate(data ?? '', language),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
