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
      'Olá, ': ['Hello, ', 'Hola, ', 'Bonjour, ', 'Hallo, '],
      'Idioma: ': ['Language: ', 'Idioma: ', 'Langue : ', 'Sprache: '],
      'Alguém em ': ['Someone in ', 'Alguien en ', 'Quelqu’un à ', 'Jemand aus '],
      'Responder · ': ['Reply · ', 'Responder · ', 'Répondre · ', 'Antworten · '],
    };
    for (final entry in dynamicTranslations.entries) {
      if (source.startsWith(entry.key)) {
        final index = const {'en': 0, 'es': 1, 'fr': 2, 'de': 3}[code];
        if (index != null) return entry.value[index] + source.substring(entry.key.length);
      }
    }
    return source;
  }

  static const Map<String, List<String>> _translations = {
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
    'Send a message to a stranger': ['Send a message to a stranger', 'Envía un mensaje a alguien', 'Envoie un message à quelqu’un', 'Sende eine Nachricht an eine fremde Person'],
    'Olá,': ['Hello,', 'Hola,', 'Bonjour,', 'Hallo,'],
    'O teu primeiro avião está guardado no servidor e pronto para a viagem. Retoma a oficina para rever o desenho e lança-o quando estiveres preparado.': [
      'Your first plane is saved on the server and ready for its journey. Return to the workshop to review the design and launch it when you are ready.',
      'Tu primer avión está guardado en el servidor y listo para viajar. Vuelve al taller para revisar el diseño y lánzalo cuando estés listo.',
      'Ton premier avion est enregistré sur le serveur et prêt à partir. Retourne à l’atelier pour revoir le modèle et le lancer lorsque tu seras prêt.',
      'Dein erster Papierflieger ist auf dem Server gespeichert und startklar. Kehre zur Werkstatt zurück, überprüfe das Design und starte ihn, wenn du bereit bist.',
    ],
    'Uma ideia. Um voo. Outro mundo.': ['One idea. One flight. Another world.', 'Una idea. Un vuelo. Otro mundo.', 'Une idée. Un vol. Un autre monde.', 'Eine Idee. Ein Flug. Eine andere Welt.'],
    'Expressa-te com um símbolo': ['Express yourself with a symbol', 'Exprésate con un símbolo', 'Exprime-toi avec un symbole', 'Drücke dich mit einem Symbol aus'],
    'Adicionar ✨': ['Add ✨', 'Añadir ✨', 'Ajouter ✨', '✨ Hinzufügen'],
    'Máximo de 200 caracteres. O servidor gere a procura de destinatário, a rota e a entrega.': [
      'Maximum 200 characters. The server handles recipient matching, routing and delivery.',
      'Máximo de 200 caracteres. El servidor gestiona la búsqueda de destinatario, la ruta y la entrega.',
      '200 caractères maximum. Le serveur gère la recherche du destinataire, l’itinéraire et la livraison.',
      'Maximal 200 Zeichen. Der Server übernimmt Empfängersuche, Route und Zustellung.',
    ],
    'O avião recebido e colocado em revisão de segurança. Só será mostrado no Open Sky depois de aprovado.': [
      'The plane was received and placed in safety review. It will appear on Open Sky only after approval.',
      'El avión se recibió y pasó a revisión de seguridad. Solo aparecerá en Open Sky después de su aprobación.',
      'L’avion a été reçu et placé en vérification de sécurité. Il ne sera affiché sur Open Sky qu’après approbation.',
      'Der Papierflieger wurde empfangen und wird sicherheitsgeprüft. Er erscheint erst nach Freigabe auf Open Sky.',
    ],
    'Continuar voo': ['Continue flight', 'Continuar vuelo', 'Continuer le vol', 'Flug fortsetzen'],
    'O servidor vai parar a procura ou o voo antes da entrega.': [
      'The server will stop the search or flight before delivery.',
      'El servidor detendrá la búsqueda o el vuelo antes de la entrega.',
      'Le serveur arrêtera la recherche ou le vol avant la livraison.',
      'Der Server stoppt die Suche oder den Flug vor der Zustellung.',
    ],
    'O avião deixa de aparecer no teu histórico. A cópia já entregue à outra pessoa mantém-se.': [
      'The plane will disappear from your history. A copy already delivered to the other person will remain.',
      'El avión dejará de aparecer en tu historial. La copia ya entregada a la otra persona se conservará.',
      'L’avion disparaîtra de ton historique. La copie déjà remise à l’autre personne sera conservée.',
      'Der Papierflieger verschwindet aus deinem Verlauf. Eine bereits zugestellte Kopie bleibt erhalten.',
    ],
    'PARTIDA': ['DEPARTURE', 'SALIDA', 'DÉPART', 'START'],
    'DESTINO LOCALIZADO': ['DESTINATION FOUND', 'DESTINO ENCONTRADO', 'DESTINATION TROUVÉE', 'ZIEL GEFUNDEN'],
    'A tua caixa': ['Your inbox', 'Tu bandeja de entrada', 'Ta boîte de réception', 'Dein Posteingang'],
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
    'De: Alguém em': ['From: Someone in', 'De: Alguien en', 'De : Quelqu’un à', 'Von: Jemand aus'],
    'Alguém em': ['Someone in', 'Alguien en', 'Quelqu’un à', 'Jemand aus'],
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
    'Eliminar da minha Caixa': ['Remove from my inbox', 'Eliminar de mi bandeja', 'Retirer de ma boîte de réception', 'Aus meinem Posteingang entfernen'],
    'Quando a resposta passar na segurança, a Chama acende e a conversa abre automaticamente.': [
      'When the reply passes safety checks, the Chama lights up and the conversation opens automatically.',
      'Cuando la respuesta supere la revisión de seguridad, se encenderá la Chama y la conversación se abrirá automáticamente.',
      'Lorsque la réponse aura passé les contrôles de sécurité, la Chama s’allumera et la conversation s’ouvrira automatiquement.',
      'Sobald die Antwort die Sicherheitsprüfung bestanden hat, wird die Chama aktiviert und die Unterhaltung automatisch geöffnet.',
    ],
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
    'O mundo que as tuas cartas estão a ligar.': [
      'The world your letters are connecting.', 'El mundo que conectan tus cartas.',
      'Le monde que tes lettres relient.', 'Die Welt, die deine Briefe verbinden.',
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
      'Sobald ein Brief einen Empfänger gefunden hat und eine Route gespeichert wurde, erscheinen die verbundenen Länder hier.',
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
      'Teilen wird aktiviert, sobald der Link verfügbar ist.',
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
    'Ainda não há países registados nos teus voos. Quando uma rota real for concluída, os países aparecem aqui.': [
      'No countries are recorded for your flights yet. Countries will appear here when a real route is completed.',
      'Todavía no hay países registrados en tus vuelos. Los países aparecerán aquí cuando se complete una ruta real.',
      'Aucun pays n’est encore enregistré pour tes vols. Ils apparaîtront ici lorsqu’un itinéraire réel sera terminé.',
      'Für deine Flüge sind noch keine Länder gespeichert. Sie erscheinen hier, sobald eine echte Route abgeschlossen ist.',
    ],
    'Os aviões recebidos, a aplicação e as traduções usam este idioma.': [
      'Incoming planes, the app and translations use this language.',
      'Los aviones recibidos, la aplicación y las traducciones usan este idioma.',
      'Les avions reçus, l’application et les traductions utilisent cette langue.',
      'Eingehende Papierflieger, die App und Übersetzungen verwenden diese Sprache.',
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
    'Uma viagem de palavras até ao Japão': [
      'A journey of words to Japan', 'Un viaje de palabras hasta Japón',
      'Un voyage de mots jusqu’au Japon', 'Eine Reise der Worte nach Japan',
    ],
    'Bónus especial': ['Special bonus', 'Bono especial', 'Bonus spécial', 'Sonderbonus'],
    'Recompensas temáticas serão ativadas numa fase futura.': [
      'Themed rewards will be enabled in a future phase.',
      'Las recompensas temáticas se habilitarán en una fase futura.',
      'Les récompenses thématiques seront activées dans une prochaine phase.',
      'Thematische Belohnungen werden in einer späteren Phase aktiviert.',
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
    'A conversa com $name será removida da tua lista. A outra pessoa continuará a ter a sua cópia.': [
      'The conversation with $name will be removed from your list. The other person will keep their copy.',
      'La conversación con $name se quitará de tu lista. La otra persona conservará su copia.',
      'La conversation avec $name sera retirée de ta liste. L’autre personne conservera sa copie.',
      'Die Unterhaltung mit $name wird aus deiner Liste entfernt. Die andere Person behält ihre Kopie.',
    ],
    'Remover amigo?': ['Remove friend?', '¿Eliminar amigo?', 'Retirer cet ami ?', 'Freund entfernen?'],
    'Queres remover @$handle da tua lista de amigos? A conversa Chama não será apagada.': [
      'Do you want to remove @$handle from your friends list? The Chama conversation will not be deleted.',
      '¿Quieres quitar a @$handle de tu lista de amigos? La conversación Chama no se eliminará.',
      'Veux-tu retirer @$handle de ta liste d’amis ? La conversation Chama ne sera pas supprimée.',
      'Möchtest du @$handle aus deiner Freundesliste entfernen? Die Chama-Unterhaltung wird nicht gelöscht.',
    ],
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
    'Os teus pedidos': ['Your requests', 'Tus solicitudes', 'Tes demandes', 'Deine Anfragen'],

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
  final InlineSpan? textSpan;
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

  InlineSpan _translateSpan(InlineSpan span, String language) {
    if (span is TextSpan) {
      return TextSpan(
        text: span.text == null ? null : PaperPlaneLocale.translate(span.text!, language),
        children: span.children?.map((child) => _translateSpan(child, language)).toList(),
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
    return span;
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
