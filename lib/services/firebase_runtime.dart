import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration is supplied at build time. No service credentials
/// or private keys belong in the Flutter application.
class FirebaseRuntime {
  FirebaseRuntime._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;
  static Future<void>? _initialization;

  /// Shares one initialization future so the app shell and launch router never
  /// race to initialize the default Firebase app twice.
  static Future<void> initialize() =>
      _initialization ??= _initializeOnce();

  static Future<void> _initializeOnce() async {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

    if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty || projectId.isEmpty) {
      debugPrint('Paper Plane: Firebase is not configured; running UI preview mode.');
      return;
    }

    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
        ),
      );
      _initialized = true;
    } catch (error) {
      // Keep the interface usable in preview mode, but network features remain disabled.
      debugPrint('Paper Plane: Firebase initialization failed: $error');
      _initialized = false;
    }
  }
}
