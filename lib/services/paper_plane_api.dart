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

    final idToken = await user.getIdToken();
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };

    late http.Response response;
    try {
      if (method == 'POST') {
        response = await _client.post(uri, headers: headers, body: jsonEncode(body ?? const {}));
      } else {
        response = await _client.get(uri, headers: headers);
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
        'AGE_VERIFICATION_REQUIRED' => 'A entrega a desconhecidos está bloqueada até existir uma verificação de idade segura.',
        'DAILY_LIMIT_REACHED' => 'Já lançaste o teu avião original de hoje.',
        'MESSAGE_NOT_ALLOWED' => 'A mensagem não passou a verificação de segurança.',
        'HELD_FOR_REVIEW' => 'A mensagem ficou retida para revisão de segurança.',
        'DUPLICATE_MESSAGE' => 'Esta mensagem já foi enviada recentemente.',
        'RATE_LIMIT_EXCEEDED' => 'Atingiste o limite de mensagens por hora. Tenta novamente mais tarde.',
        'PROFILE_SETUP_REQUIRED' => 'Completa primeiro o perfil do piloto.',
        'PILOT_HANDLE_TAKEN' => 'Esse nome de copiloto já existe. Escolhe outro.',
        'INVALID_PILOT_HANDLE' => 'Usa 4 a 28 caracteres: letras, números, _ e um sufixo como -07.',
        'INVALID_BIRTH_YEAR' => 'Indica um ano de nascimento válido.',
        'INVALID_COUNTRY' => 'Escolhe um país válido.',
        _ => payload['message']?.toString() ?? 'O pedido não pôde ser concluído.',
      };
      throw PaperPlaneApiException(code, message, statusCode: response.statusCode);
    }

    return payload;
  }

  Future<Map<String, dynamic>> bootstrapPilot() =>
      _request('/v1/users/bootstrap', method: 'POST');

  Future<Map<String, dynamic>> getProfile() => _request('/v1/profile');

  Future<Map<String, dynamic>> getCountries() => _request('/v1/meta/countries');

  Future<Map<String, dynamic>> checkPilotHandle(String handle) =>
      _request('/v1/users/handle-availability?handle=${Uri.encodeQueryComponent(handle)}');

  Future<Map<String, dynamic>> savePilotProfile({
    required String pilotName,
    required String pilotHandle,
    required int birthYear,
    required String countryCode,
    required String language,
  }) =>
      _request('/v1/profile', method: 'POST', body: {
        'pilotName': pilotName,
        'pilotHandle': pilotHandle,
        'birthYear': birthYear,
        'countryCode': countryCode,
        'language': language,
      });

  Future<Map<String, dynamic>> getAirplaneFlight(String id) =>
      _request('/v1/airplanes/$id/flight');


  Future<Map<String, dynamic>> getInbox() => _request('/v1/inbox');

  Future<Map<String, dynamic>> getSentPlanes() => _request('/v1/airplanes/sent');

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
      },
    );
  }

  Future<Map<String, dynamic>> openIncomingPlane(String id) =>
      _request('/v1/inbox/$id');

  Future<Map<String, dynamic>> releasePlane(String id) =>
      _request('/v1/airplanes/$id/release', method: 'POST');

  Future<Map<String, dynamic>> translatePlane(String id, String language) =>
      _request('/v1/airplanes/$id/translation', method: 'POST', body: {'language': language});

  Future<Map<String, dynamic>> registerDevice(String token, {String platform = 'android'}) =>
      _request('/v1/devices/register', method: 'POST', body: {'token': token, 'platform': platform});

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
