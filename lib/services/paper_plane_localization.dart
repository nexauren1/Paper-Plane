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
    'Ajuda e suporte': ['Help and support', 'Ayuda y soporte', 'Aide et assistance', 'Hilfe und Support'],
    'Estamos aqui para ajudar': ['We are here to help', 'Estamos aquí para ayudarte', 'Nous sommes là pour t’aider', 'Wir helfen dir gerne'],
    'Novo pedido': ['New request', 'Nueva solicitud', 'Nouvelle demande', 'Neue Anfrage'],
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
