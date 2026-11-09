import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_runtime.dart';
import 'paper_plane_api.dart';

class PaperPlaneNotifications {
  PaperPlaneNotifications._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static VoidCallback? onOpenInbox;
  static ValueChanged<String>? onOpenPlane;
  static VoidCallback? onOpenChat;
  static VoidCallback? onOpenOpenSky;
  static bool _pendingInboxOpen = false;
  static bool _pendingChatOpen = false;
  static String? _pendingAirplaneId;
  static bool _handlersInitialized = false;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<String>? _tokenSubscription;

  /// Installs app-visible handlers once. Android displays notification payloads
  /// while the app is in the background; foreground messages use this in-app banner.
  static Future<void> initializeMessageHandlers() async {
    if (!FirebaseRuntime.isInitialized || _handlersInitialized) return;
    final messaging = FirebaseMessaging.instance;

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final title = notification?.title?.trim().isNotEmpty == true
          ? notification!.title!
          : 'Nova atividade no Paper Plane';
      final body = notification?.body?.trim().isNotEmpty == true
          ? notification!.body!
          : 'Tens uma atualização na tua caixa de entrada.';
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(body),
            ],
          ),
          action: SnackBarAction(
            label: message.data['type'] == 'CHAT_MESSAGE'
                ? 'Abrir Chama'
                : message.data['airplaneId']?.toString().isNotEmpty == true
                    ? 'Abrir carta'
                    : 'Abrir caixa',
            onPressed: () => _routeMessage(message),
          ),
        ),
      );
    });

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_routeMessage);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _rememberMessage(initialMessage);
    _handlersInitialized = true;
  }

  static void _rememberMessage(RemoteMessage message) {
    final airplaneId = message.data['airplaneId']?.toString().trim() ?? '';
    if (airplaneId.isNotEmpty) {
      _pendingAirplaneId = airplaneId;
    } else {
      _pendingInboxOpen = true;
    }
  }

  static void _routeMessage(RemoteMessage message) {
    if (message.data['type'] == 'CHAT_MESSAGE') {
      final callback = onOpenChat;
      if (callback == null) {
        _pendingChatOpen = true;
      } else {
        callback();
      }
      return;
    }
    final airplaneId = message.data['airplaneId']?.toString().trim() ?? '';
    if (airplaneId.isEmpty) {
      _requestInboxOpen();
      return;
    }
    final callback = onOpenPlane;
    if (callback == null) {
      _pendingAirplaneId = airplaneId;
    } else {
      callback(airplaneId);
    }
  }

  static bool consumePendingChatOpen() {
    final pending = _pendingChatOpen;
    _pendingChatOpen = false;
    return pending;
  }

  /// Returns a pending airplane ID once the authenticated shell is mounted.
  static String? consumePendingPlaneOpen() {
    final id = _pendingAirplaneId;
    _pendingAirplaneId = null;
    return id;
  }

  static void _requestInboxOpen() {
    final callback = onOpenInbox;
    if (callback == null) {
      _pendingInboxOpen = true;
    } else {
      callback();
    }
  }

  /// Called by the authenticated app shell after it is mounted.
  static bool consumePendingInboxOpen() {
    final pending = _pendingInboxOpen;
    _pendingInboxOpen = false;
    return pending;
  }

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
      unawaited(PaperPlaneApi.instance.registerDevice(newToken));
    });
  }

  /// Disabling notifications removes the server-side device registration first,
  /// then deletes the local FCM token. This prevents future pushes to this device.
  static Future<bool> disableAndUnregister() async {
    if (!FirebaseRuntime.isInitialized) return true;

    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;

    var serverUpdated = true;
    if (token != null && token.isNotEmpty && PaperPlaneApi.isConfigured) {
      try {
        await PaperPlaneApi.instance.unregisterDevice(token);
      } catch (_) {
        serverUpdated = false;
      }
    }

    await messaging.deleteToken();
    return serverUpdated;
  }

  static Future<void> disposeMessageHandlers() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _handlersInitialized = false;
  }
}
