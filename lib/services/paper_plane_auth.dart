import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_runtime.dart';
import 'paper_plane_analytics.dart';
import 'paper_plane_api.dart';

class PaperPlaneAuth {
  PaperPlaneAuth._();

  static bool _googleInitialized = false;

  static Future<User> ensureAnonymousPilot() async {
    if (!FirebaseRuntime.isInitialized) {
      throw const PaperPlaneApiException(
        'FIREBASE_NOT_CONFIGURED',
        'Configura o Firebase antes de utilizar os serviços online.',
      );
    }

    final auth = FirebaseAuth.instance;
    User? user = auth.currentUser;
    if (user == null) {
      final credential = await auth.signInAnonymously();
      user = credential.user;
    }
    if (user == null) {
      throw const PaperPlaneApiException('AUTH_FAILED', 'Não foi possível criar a identidade do piloto.');
    }

    await PaperPlaneApi.instance.bootstrapPilot();
    return user;
  }

  static Future<UserCredential> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    _requireFirebase();
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );

    final result = current?.isAnonymous == true
        ? await current!.linkWithCredential(credential)
        : await auth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

    await PaperPlaneAnalytics.logSignUp('email');
    return result;
  }

  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _requireFirebase();
    final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await PaperPlaneAnalytics.logLogin('email');
    return result;
  }

  static Future<UserCredential> signInWithGoogle() async {
    _requireFirebase();
    await _initializeGoogleSignIn();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const PaperPlaneApiException(
        'GOOGLE_SIGN_IN_UNSUPPORTED',
        'O início de sessão Google não está disponível nesta plataforma.',
      );
    }

    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const PaperPlaneApiException(
        'GOOGLE_ID_TOKEN_MISSING',
        'O Google não devolveu um token de autenticação. Confirma a configuração OAuth e a assinatura Android.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;

    UserCredential result;
    if (current?.isAnonymous == true) {
      try {
        result = await current!.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use' &&
            error.code != 'account-exists-with-different-credential') {
          rethrow;
        }
        result = await auth.signInWithCredential(credential);
      }
    } else {
      result = await auth.signInWithCredential(credential);
    }

    await PaperPlaneAnalytics.logLogin('google');
    return result;
  }

  static Future<void> sendPasswordReset(String email) async {
    _requireFirebase();
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() async {
    if (!FirebaseRuntime.isInitialized) return;
    await PaperPlaneAnalytics.logLogout();
    await FirebaseAuth.instance.signOut();
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Paper Plane: Google sign-out was skipped: $error');
      }
    }
  }

  static void _requireFirebase() {
    if (!FirebaseRuntime.isInitialized) {
      throw const PaperPlaneApiException(
        'FIREBASE_NOT_CONFIGURED',
        'Firebase ainda não está configurado nesta compilação.',
      );
    }
  }

  static Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) return;
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _googleInitialized = true;
  }
}
