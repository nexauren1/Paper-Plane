import 'package:firebase_analytics/firebase_analytics.dart';

import 'firebase_runtime.dart';

class PaperPlaneAnalytics {
  PaperPlaneAnalytics._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> initialize() async {
    if (!FirebaseRuntime.isInitialized) return;
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
      await _analytics.logAppOpen();
    } catch (_) {
      // Analytics must never prevent the app from opening.
    }
  }

  static Future<void> logLogin(String method) async {
    if (!FirebaseRuntime.isInitialized) return;
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (_) {}
  }

  static Future<void> logSignUp(String method) async {
    if (!FirebaseRuntime.isInitialized) return;
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (_) {}
  }

  static Future<void> logLogout() async {
    if (!FirebaseRuntime.isInitialized) return;
    try {
      await _analytics.logEvent(name: 'logout');
    } catch (_) {}
  }
}
