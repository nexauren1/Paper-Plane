import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'firebase_runtime.dart';

class PaperPlaneApiException implements Exception {
  const PaperPlaneApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PaperPlaneApi {
  PaperPlaneApi._();

  static final PaperPlaneApi instance = PaperPlaneApi._();
  static const String baseUrl = String.fromEnvironment(
    'PAPER_PLANE_API_BASE_URL',
    defaultValue: 'https://paper-plane.nexaurenstore.workers.dev',
  );
  static bool get isConfigured => baseUrl.startsWith('https://') || baseUrl.startsWith('http://');

  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (!FirebaseRuntime.isInitialized) {
      throw const PaperPlaneApiException('FIREBASE_NOT_CONFIGURED', 'Firebase ainda não está configurado.');
    }
    if (!isConfigured) {
      throw const PaperPlaneApiException('API_NOT_CONFIGURED', 'O endereço da API Cloudflare ainda não foi configurado.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PaperPlaneApiException('AUTH_REQUIRED', 'É necessário criar uma identidade de piloto.');
    }

    final uri = Uri.parse('$baseUrl$path');
    final baseHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    Future<http.Response> sendWithToken(String token) async {
      final headers = {...baseHeaders, 'Authorization': 'Bearer $token'};
      if (method == 'POST') {
        return _client.post(uri, headers: headers, body: jsonEncode(body ?? const {}));
      }
      return _client.get(uri, headers: headers);
    }

    var idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const PaperPlaneApiException('AUTH_TOKEN_UNAVAILABLE', 'Não foi possível confirmar a tua sessão Firebase. Entra novamente na conta.');
    }

    late http.Response response;
    try {
      response = await sendWithToken(idToken);
      if (response.statusCode == 401) {
        final refreshed = await user.getIdToken(true);
        if (refreshed != null && refreshed.isNotEmpty && refreshed != idToken) {
          idToken = refreshed;
          response = await sendWithToken(idToken);
        }
      }
    } catch (_) {
      throw const PaperPlaneApiException('NETWORK_ERROR', 'Não foi possível contactar o servidor. Verifica a ligação à internet.');
    }

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(response.body);
      payload = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      payload = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = payload['error']?.toString() ?? 'REQUEST_FAILED';
      final message = switch (code) {
        'AGE_DECLARATION_REQUIRED' => 'Completa a tua data de nascimento no perfil antes de enviar.',
        'INVALID_BIRTH_DATE' => 'Indica uma data de nascimento válida.',
        'INVALID_AVATAR_URL' => 'Usa um link HTTPS público para a tua foto ou perfil.',
        'PREVIEW_UNAVAILABLE' => 'Não foi possível carregar a pré-visualização deste link.',
        'CHAMA_USES_PLANES' => 'A Chama funciona através de aviões de resposta.',
        'CHAMA_ENDED' => 'Esta Chama foi encerrada.',

        'AGE_NOT_ELIGIBLE' => 'O Paper Plane está disponível a partir dos 13 anos.',
        'AUTH_TOKEN_UNAVAILABLE' => 'Não foi possível confirmar a tua sessão Firebase. Entra novamente na conta.',
        'DAILY_LIMIT_REACHED' => 'Já lançaste o teu avião original de hoje.',
        'MESSAGE_NOT_ALLOWED' => 'A mensagem contém conteúdo que não é permitido.',
        'HELD_FOR_REVIEW' => 'A mensagem ficou retida para revisão de segurança.',
        'DUPLICATE_MESSAGE' => 'Esta mensagem já foi enviada recentemente.',
        'RATE_LIMIT_EXCEEDED' => 'Atingiste o limite de mensagens por hora. Tenta novamente mais tarde.',
        'PROFILE_SETUP_REQUIRED' => 'Completa primeiro o perfil do piloto.',
        'PILOT_HANDLE_TAKEN' => 'Esse nome de copiloto já existe. Escolhe outro.',
        'PILOT_NOT_FOUND' => 'Não encontrámos um copiloto ativo com esse @nome.',
        'FRIEND_AGE_GROUP_MISMATCH' => 'Por segurança, só podes adicionar pessoas da mesma faixa etária declarada.',
        'CHAT_NOT_FOUND' => 'Esta Chama já não está disponível.',
        'CHAT_UNAVAILABLE' => 'Não é possível enviar mensagens nesta conversa.',
        'CHAT_RATE_LIMIT' => 'Atingiste o limite temporário de mensagens. Tenta novamente mais tarde.',
        'FRIENDSHIP_REQUIRED' => 'Aceitem primeiro o pedido de amizade para abrir um Chat privado.',
        'MISSION_NOT_READY' => 'Ainda falta cumprir esta missão.',
        'MISSION_ALREADY_CLAIMED' => 'Já resgataste esta recompensa.',
        'QUIZ_DAILY_LIMIT' => 'Já concluíste muitas rondas hoje. Volta amanhã para continuar.',
        'INVALID_PILOT_HANDLE' => 'Usa 4 a 28 caracteres: letras, números, _ e um sufixo como -07.',
        'INVALID_BIRTH_YEAR' => 'Indica um ano de nascimento válido.',
        'INVALID_COUNTRY' => 'Escolhe um país válido.',
        'INVALID_REPORT_CATEGORY' => 'Escolhe uma categoria de denúncia válida.',
        'REPORT_ALREADY_OPEN' => 'Já existe uma denúncia tua em análise para esta mensagem.',
        'REPORT_RATE_LIMIT' => 'Atingiste o limite diário de denúncias. Tenta novamente mais tarde.',
        'INVALID_SUPPORT_CATEGORY' => 'Escolhe uma categoria de suporte válida.',
        'SUPPORT_MESSAGE_TOO_SHORT' => 'Preenche o assunto e descreve o problema com mais detalhes.',
        'SUPPORT_RATE_LIMIT' => 'Atingiste o limite diário de pedidos de suporte.',

        _ => payload['message']?.toString() ?? 'O pedido não pôde ser concluído.',
      };
      throw PaperPlaneApiException(code, message, statusCode: response.statusCode);
    }

    return payload;
  }

  Future<Map<String, dynamic>> bootstrapPilot() =>
      _request('/v1/users/bootstrap', method: 'POST');

  Future<Map<String, dynamic>> getProfile() => _request('/v1/profile');

  Future<Map<String, dynamic>> saveFirstFlight({
    required String message,
    required String planeModel,
  }) =>
      _request('/v1/onboarding/first-flight', method: 'POST', body: {
        'message': message,
        'planeModel': planeModel,
      });

  Future<Map<String, dynamic>> getCountries() => _request('/v1/meta/countries');

  Future<Map<String, dynamic>> checkPilotHandle(String handle) =>
      _request('/v1/users/handle-availability?handle=${Uri.encodeQueryComponent(handle)}');

  Future<Map<String, dynamic>> savePilotProfile({
    required String pilotName,
    required String pilotHandle,
    required DateTime birthDate,
    required String countryCode,
    required String language,
    String? avatarUrl,
  }) =>
      _request('/v1/profile', method: 'POST', body: {
        'pilotName': pilotName,
        'pilotHandle': pilotHandle,
        'avatarUrl': avatarUrl,
        'birthDate': '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
        'countryCode': countryCode,
        'language': language,
      });

  Future<Map<String, dynamic>> updateAvatarUrl(String? avatarUrl) =>
      _request('/v1/profile/avatar', method: 'POST', body: {'avatarUrl': avatarUrl});

  Future<Map<String, dynamic>> getLinkPreview(String url) =>
      _request('/v1/link-preview?url=${Uri.encodeQueryComponent(url)}');

  Future<Map<String, dynamic>> getAirplaneFlight(String id) =>
      _request('/v1/airplanes/$id/flight');

  Future<Map<String, dynamic>> getSkyAtlas() => _request('/v1/atlas');



  Future<Map<String, dynamic>> getInbox() => _request('/v1/inbox');

  Future<Map<String, dynamic>> getSentPlanes() => _request('/v1/airplanes/sent');

  Future<Map<String, dynamic>> getFriends() => _request('/v1/friends');

  Future<Map<String, dynamic>> getFriendRequests() =>
      _request('/v1/friends/requests');

  Future<Map<String, dynamic>> searchFriends(String query) =>
      _request('/v1/friends/search?q=${Uri.encodeQueryComponent(query)}');

  Future<Map<String, dynamic>> requestFriend(String handle) =>
      _request('/v1/friends/requests', method: 'POST', body: {'handle': handle});

  Future<Map<String, dynamic>> respondFriendRequest(
    String requestId, {
    required bool accept,
  }) =>
      _request('/v1/friends/requests/$requestId', method: 'POST', body: {
        'action': accept ? 'accept' : 'decline',
      });

  Future<Map<String, dynamic>> removeFriend(String uid) =>
      _request('/v1/friends/remove', method: 'POST', body: {'uid': uid});

  Future<Map<String, dynamic>> getChats() => _request('/v1/chats');

  Future<Map<String, dynamic>> getChamas() => _request('/v1/chamas');

  Future<Map<String, dynamic>> endChama(String conversationId) =>
      _request('/v1/chamas/$conversationId/end', method: 'POST');

  Future<Map<String, dynamic>> createChat(String friendUid) =>
      _request('/v1/chats', method: 'POST', body: {'uid': friendUid});

  Future<Map<String, dynamic>> getGamification() => _request('/v1/gamification');

  Future<Map<String, dynamic>> claimMission(String missionKey) =>
      _request('/v1/gamification/claim', method: 'POST', body: {'missionKey': missionKey});

  Future<Map<String, dynamic>> recordQuizAttempt({
    required String category,
    required int questionCount,
    required int correctCount,
  }) =>
      _request('/v1/quiz/attempts', method: 'POST', body: {
        'category': category,
        'questionCount': questionCount,
        'correctCount': correctCount,
      });

  Future<Map<String, dynamic>> getChat(String conversationId) =>
      _request('/v1/chats/$conversationId');

  Future<Map<String, dynamic>> sendChatMessage(
    String conversationId,
    String message,
  ) =>
      _request('/v1/chats/$conversationId/messages', method: 'POST', body: {
        'message': message,
      });

  String buildFriendInviteLink(String pilotHandle) =>
      'https://paper-plane.nexaurenstore.workers.dev/invite?handle=${Uri.encodeQueryComponent(pilotHandle.replaceFirst(RegExp(r'^@'), ''))}';

  Future<Map<String, dynamic>> getOpenSky({String? country, String? language}) {
    final query = <String, String>{
      if (country != null && country.isNotEmpty) 'country': country.toUpperCase(),
      if (language == 'pt' || language == 'en') 'language': language!,
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return _request('/v1/open-sky$suffix');
  }

  Future<Map<String, dynamic>> sendPlane({
    required String message,
    required String language,
    required String mood,
    required String visibility,
    required String? destinationCountry,
    required bool allowReply,
    String planeModel = 'DART',
    bool firstFlight = false,
  }) {
    return _request(
      '/v1/airplanes',
      method: 'POST',
      body: {
        'message': message,
        'language': language,
        'mood': mood,
        'visibility': visibility == 'Público' ? 'PUBLIC' : 'RANDOM',
        'destinationCountry': destinationCountry,
        'allowReply': allowReply,
        'planeModel': planeModel,
        'firstFlight': firstFlight,
      },
    );
  }

  Future<Map<String, dynamic>> openIncomingPlane(String id) =>
      _request('/v1/inbox/$id');

  Future<Map<String, dynamic>> releasePlane(String id) =>
      _request('/v1/airplanes/$id/release', method: 'POST');

  Future<Map<String, dynamic>> sendHeart(String id) =>
      _request('/v1/airplanes/$id/heart', method: 'POST');

  Future<Map<String, dynamic>> translatePlane(String id, String language) =>
      _request('/v1/airplanes/$id/translation', method: 'POST', body: {'language': language});

  Future<Map<String, dynamic>> registerDevice(String token, {String platform = 'android'}) =>
      _request('/v1/devices/register', method: 'POST', body: {'token': token, 'platform': platform});

  Future<Map<String, dynamic>> getDeviceNotificationState(String token) =>
      _request('/v1/devices/state', method: 'POST', body: {'token': token});

  Future<Map<String, dynamic>> unregisterDevice(String token) =>
      _request('/v1/devices/unregister', method: 'POST', body: {'token': token});

  Future<Map<String, dynamic>> reportPlane(
    String airplaneId, {
    required String reason,
    String? details,
  }) =>
      _request(
        '/v1/airplanes/$airplaneId/report',
        method: 'POST',
        body: {'reason': reason, if (details != null) 'details': details},
      );

  Future<Map<String, dynamic>> getSupportTickets() =>
      _request('/v1/support/tickets');

  Future<Map<String, dynamic>> createSupportTicket({
    required String category,
    required String subject,
    required String details,
  }) =>
      _request('/v1/support/tickets', method: 'POST', body: {
        'category': category,
        'subject': subject,
        'details': details,
      });

  Future<Map<String, dynamic>> blockPilot(String uid) =>
      _request('/v1/users/block', method: 'POST', body: {'uid': uid});

  Future<Map<String, dynamic>> blockSenderOfPlane(String airplaneId) =>
      _request('/v1/airplanes/$airplaneId/block-sender', method: 'POST');

  Future<Map<String, dynamic>> likeOpenSkyMessage(String airplaneId) =>
      _request('/v1/open-sky/$airplaneId/like', method: 'POST');

  Future<Map<String, dynamic>> getPublicReplies(String airplaneId) =>
      _request('/v1/open-sky/$airplaneId/replies');

  Future<Map<String, dynamic>> addPublicReply(String airplaneId, String message) =>
      _request('/v1/open-sky/$airplaneId/replies', method: 'POST', body: {'message': message});

  Future<Map<String, dynamic>> replyToPlane(
    String airplaneId, {
    required String message,
    required String language,
    required bool allowReply,
  }) =>
      _request(
        '/v1/airplanes/$airplaneId/reply',
        method: 'POST',
        body: {'message': message, 'language': language, 'allowReply': allowReply},
      );

  void close() => _client.close();
}
