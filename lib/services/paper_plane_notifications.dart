import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_runtime.dart';
import 'paper_plane_api.dart';

class PaperPlaneNotifications {
  PaperPlaneNotifications._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static VoidCallback? onOpenInbox;
  static ValueChanged<String>? onOpenPlane;
  static VoidCallback? onOpenChat;
  static VoidCallback? onOpenOpenSky;
  static bool _pendingInboxOpen = false;
  static bool _pendingChatOpen = false;
  static String? _pendingAirplaneId;
  static bool _handlersInitialized = false;
  static bool _localNotificationsInitialized = false;
  static Future<void>? _permissionRequest;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static StreamSubscription<String>? _tokenSubscription;

  /// Installs app-visible handlers once. Android displays notification payloads
  /// while the app is in the background; foreground messages use this in-app banner.
  static Future<void> initializeMessageHandlers() async {
    if (!FirebaseRuntime.isInitialized || _handlersInitialized) return;
    final messaging = FirebaseMessaging.instance;

    if (!_localNotificationsInitialized) {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _routeLocalPayload(data);
          } catch (_) {
            // Ignore old or malformed local notification payloads.
          }
        },
      );
      const channel = AndroidNotificationChannel(
        'paper_plane_updates',
        'Paper Plane',
        description: 'Novos aviões, mensagens e avisos importantes.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      final launchPayload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchPayload != null && launchPayload.isNotEmpty) {
        try {
          _routeLocalPayload(jsonDecode(launchPayload) as Map<String, dynamic>);
        } catch (_) {
          // Ignore malformed launch payloads.
        }
      }
      _localNotificationsInitialized = true;
    }

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      final title = notification?.title?.trim().isNotEmpty == true
          ? notification!.title!
          : 'Nova atividade no Paper Plane';
      final body = notification?.body?.trim().isNotEmpty == true
          ? notification!.body!
          : 'Tens uma atualização na tua caixa de entrada.';

      await _localNotifications.show(
        id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'paper_plane_updates',
            'Paper Plane',
            channelDescription: 'Novos aviões, mensagens e avisos importantes.',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            icon: 'ic_notification',
          ),
        ),
        payload: jsonEncode(Map<String, dynamic>.from(message.data)),
      );

      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          content: Text('$title  $body'),
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

  static void _routeLocalPayload(Map<String, dynamic> data) {
    if (data['type'] == 'CHAT_MESSAGE') {
      final callback = onOpenChat;
      if (callback == null) {
        _pendingChatOpen = true;
      } else {
        callback();
      }
      return;
    }
    final airplaneId = data['airplaneId']?.toString().trim() ?? '';
    if (airplaneId.isNotEmpty) {
      final callback = onOpenPlane;
      if (callback == null) {
        _pendingAirplaneId = airplaneId;
      } else {
        callback(airplaneId);
      }
      return;
    }
    _requestInboxOpen();
  }

  static void _rememberMessage(RemoteMessage message) {
    // Notification initialization now runs after runApp. The authenticated
    // shell may already be mounted when FCM returns the initial message, so
    // route immediately when callbacks exist and retain it only when they do not.
    _routeMessage(message);
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

  /// Requests the native operating-system permission when the app starts.
  /// Android decides whether a dialog can be shown again after a denial.
  static Future<void> requestSystemPermissionAtLaunch() {
    return _permissionRequest ??= _requestSystemPermission();
  }

  static Future<void> _requestSystemPermission() async {
    if (!FirebaseRuntime.isInitialized) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (error) {
      debugPrint('Paper Plane: Android notification permission request failed: $error');
    }
  }

  static void _watchTokenRefresh(FirebaseMessaging messaging) {
    if (_tokenSubscription != null) return;
    _tokenSubscription = messaging.onTokenRefresh.listen((newToken) {
      unawaited(() async {
        final settings = await messaging.getNotificationSettings();
        final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
        if (allowed) {
          await PaperPlaneApi.instance.registerDevice(newToken);
        } else {
          await PaperPlaneApi.instance.unregisterDevice(newToken);
        }
      }().catchError((Object error, StackTrace stack) {
        debugPrint('Paper Plane: could not synchronize the refreshed FCM token: $error');
      }));
    });
  }

  /// Registers the FCM token only when the operating system has granted
  /// notification permission. The Android system setting is the source of truth.
  static Future<void> registerDeviceIfAuthorized() async {
    if (!FirebaseRuntime.isInitialized || !PaperPlaneApi.isConfigured) return;
    try {
      await requestSystemPermissionAtLaunch();
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      final allowed = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        await PaperPlaneApi.instance.unregisterDevice(token);
        return;
      }

      await PaperPlaneApi.instance.registerDevice(token);
      _watchTokenRefresh(messaging);
    } catch (error) {
      debugPrint('Paper Plane: device notification registration could not be synchronized: $error');
    }
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
