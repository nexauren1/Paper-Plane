import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_runtime.dart';
import 'paper_plane_api.dart';

class PaperPlaneAuth {
  PaperPlaneAuth._();

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
}
