# Paper Plane Admin

Aplicação Android separada para operações internas do Paper Plane.

## Segurança e acesso

- O login usa Firebase Authentication (email/palavra-passe).
- O Worker valida o Firebase ID token em todos os pedidos.
- O UID do operador tem de estar na variável secreta Cloudflare Worker `ADMIN_UIDS` (lista de UIDs separada por vírgulas).
- A interface não contém chaves privadas, tokens de serviço nem uma palavra-passe administrativa comum.
- As ações administrativas são registadas na tabela `audit_events`.

## Build

Gerar o projeto Android e compilar com os mesmos valores Firebase do projeto Paper Plane:

```bash
flutter create --platforms=android --project-name paper_plane_admin --org com.nexauren .
flutter pub get
flutter build apk --release \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=ADMIN_API_BASE_URL=https://paper-plane.nexaurenstore.workers.dev
```

A instalação da migração `0011_admin_console.sql` é necessária para histórico de avisos. O Worker também precisa de `AI`, `FCM_SERVICE_ACCOUNT_JSON` e `ADMIN_UIDS` configurados.
