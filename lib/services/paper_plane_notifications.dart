import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_runtime.dart';
import 'paper_plane_api.dart';

class PaperPlaneNotifications {
  PaperPlaneNotifications._();

  static StreamSubscription<String>? _tokenSubscription;

  /// Call only after the pilot has opted into notifications in Settings.
  static Future<void> enableAndRegister() async {
    if (!FirebaseRuntime.isInitialized) {
      throw const PaperPlaneApiException('FIREBASE_NOT_CONFIGURED', 'Firebase ainda não está configurado.');
    }

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw const PaperPlaneApiException('NOTIFICATIONS_DENIED', 'As notificações não foram autorizadas.');
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      throw const PaperPlaneApiException('FCM_TOKEN_UNAVAILABLE', 'Não foi possível registar este dispositivo.');
    }

    await PaperPlaneApi.instance.registerDevice(token);
    await _tokenSubscription?.cancel();
    _tokenSubscription = messaging.onTokenRefresh.listen((newToken) {
      PaperPlaneApi.instance.registerDevice(newToken);
    });
  }

  /// Disabling notifications removes the server-side device registration first,
  /// then deletes the local FCM token. This prevents future pushes to this device.
  static Future<void> disableAndUnregister() async {
    if (!FirebaseRuntime.isInitialized) return;

    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;

    if (token != null && token.isNotEmpty && PaperPlaneApi.isConfigured) {
      await PaperPlaneApi.instance.unregisterDevice(token);
    }

    await messaging.deleteToken();
  }
}
