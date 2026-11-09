import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const ink = Color(0xFF071225);
const panel = Color(0xFF10213A);
const gold = Color(0xFFF0CE7C);
const goldLight = Color(0xFFFFE7A8);
const danger = Color(0xFFFF7373);
const apiBase = String.fromEnvironment('ADMIN_API_BASE_URL',
  defaultValue: 'https://paper-plane.nexaurenstore.workers.dev');

Map<String, dynamic> mapOf(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> itemsOf(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
String show(dynamic v, [String fallback = '—']) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? fallback : s;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const key = String.fromEnvironment('FIREBASE_API_KEY');
  const app = String.fromEnvironment('FIREBASE_APP_ID');
  const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  if (key.isNotEmpty && app.isNotEmpty && sender.isNotEmpty && project.isNotEmpty) {
    await Firebase.initializeApp(options: const FirebaseOptions(
      apiKey: key, appId: app, messagingSenderId: sender, projectId: project));
  }
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Paper Plane Admin',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.dark),
      cardColor: panel,
    ),
    home: const AuthGate(),
  );
}

class AdminApiException implements Exception {
  const AdminApiException(this.message, this.status);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class AdminApi {
  AdminApi._();
  static final instance = AdminApi._();

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body);

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const AdminApiException('Sessão terminada.', 401);
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) throw const AdminApiException('Não foi possível validar a sessão.', 401);
    final request = http.Request(method, Uri.parse(apiBase + path));
    request.headers.addAll({'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await request.send());
    final data = response.body.isEmpty ? <String, dynamic>{} : mapOf(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = data['error']?.toString();
      final message = data['message']?.toString() ??
          (error == 'FORBIDDEN'
              ? 'Este UID não está autorizado. Confirma a variável ADMIN_UIDS no Worker.'
              : error == 'PUSH_PROVIDER_UNAVAILABLE'
                  ? 'O FCM não está configurado ou está indisponível.'
                  : 'O servidor recusou o pedido (' + response.statusCode.toString() + ').');
      throw AdminApiException(message, response.statusCode);
    }
    return data;
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const MessagePage(
        title: 'Admin não configurado',
        detail: 'Compila com os valores Firebase do projeto Paper Plane.',
        icon: Icons.cloud_off);
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LoadingPage();
        final user = snapshot.data;
        return user == null || user.isAnonymous ? const LoginPage() : const AdminShell();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  bool showPassword = false;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  Future<void> enter() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Preenche o email e a palavra-passe.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(), password: password.text);
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.code == 'invalid-credential' || e.code == 'wrong-password'
          ? 'Credenciais inválidas.' : 'Não foi possível entrar (' + e.code + ').');
    } catch (_) {
      setState(() => error = 'Não foi possível iniciar sessão.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF16375C), ink, Color(0xFF030812)])),
      child: SafeArea(child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              color: panel,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.admin_panel_settings_rounded, size: 58, color: goldLight),
                  const SizedBox(height: 12),
                  const Text('PAPER PLANE', textAlign: TextAlign.center,
                    style: TextStyle(color: goldLight, letterSpacing: 3, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('ADMIN CONSOLE', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Acesso reservado a operadores autorizados.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 24),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: !showPassword,
                    onSubmitted: (_) => enter(),
                    decoration: InputDecoration(labelText: 'Palavra-passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => showPassword = !showPassword),
                        icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility)))),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: danger)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: busy ? null : enter,
                    icon: busy ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                    label: Text(busy ? 'A autenticar…' : 'Entrar na consola')),
                  const SizedBox(height: 14),
                  const Text('O servidor confirma o UID em ADMIN_UIDS. O login Firebase, sozinho, não dá acesso administrativo.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4)),
                ]),
              ),
            ),
          ),
        ),
      )),
    ),
  );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int selected = 0;
  late Future<Map<String, dynamic>> permission;
  @override
  void initState() { super.initState(); permission = AdminApi.instance.get('/v1/admin/dashboard'); }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: permission,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const LoadingPage();
      if (snapshot.hasError) return MessagePage(
        title: 'Acesso administrativo recusado',
        detail: snapshot.error.toString(),
        icon: Icons.gpp_bad_outlined,
        action: FilledButton.tonalIcon(
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout), label: const Text('Terminar sessão')));
      final pages = [
        DashboardPage(api: AdminApi.instance),
        AccountsPage(api: AdminApi.instance),
        SafetyPage(api: AdminApi.instance),
        SupportPage(api: AdminApi.instance),
        AnnouncementsPage(api: AdminApi.instance),
      ];
      const destinations = [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Painel'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Contas'),
        NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: 'Segurança'),
        NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent), label: 'Suporte'),
        NavigationDestination(icon: Icon(Icons.notifications_active_outlined), selectedIcon: Icon(Icons.notifications_active), label: 'Avisos'),
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text('Paper Plane Admin', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(onPressed: () => setState(() => permission = AdminApi.instance.get('/v1/admin/dashboard')),
              icon: const Icon(Icons.refresh)),
            IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout)),
          ]),
        body: IndexedStack(index: selected, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (v) => setState(() => selected = v),
          destinations: destinations),
      );
    },
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() { super.initState(); future = widget.api.get('/v1/admin/dashboard'); }
  Future<void> reload() async => setState(() => future = widget.api.get('/v1/admin/dashboard'));

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const LoadingPage();
      if (snapshot.hasError) return ErrorPanel(error: snapshot.error.toString(), onRetry: reload);
      final data = snapshot.data ?? {};
      final users = mapOf(data['users']);
      final planes = mapOf(data['planes']);
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const SectionTitle('Centro de operações', 'Indicadores em tempo real do servidor.'),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.45,
            children: [
              Metric(label: 'Contas ativas', value: show(users['active'], '0'), icon: Icons.people),
              Metric(label: 'Suspensas', value: show(users['suspended'], '0'), icon: Icons.person_off),
              Metric(label: 'Aviões entregues', value: show(planes['delivered'], '0'), icon: Icons.mark_email_read),
              Metric(label: 'Em voo / fila', value: show(planes['in_flight'], '0'), icon: Icons.flight),
              Metric(label: 'Denúncias abertas', value: show(mapOf(data['openReports'])['total'], '0'), icon: Icons.flag),
              Metric(label: 'Em revisão', value: show(mapOf(data['pendingReview'])['total'], '0'), icon: Icons.fact_check),
              Metric(label: 'Suporte aberto', value: show(mapOf(data['openSupport'])['total'], '0'), icon: Icons.support_agent),
              Metric(label: 'Dispositivos ativos', value: show(mapOf(data['activeDevices'])['total'], '0'), icon: Icons.phone_android),
            ]),
          const SizedBox(height: 16),
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('Nota de segurança', style: TextStyle(color: goldLight, fontWeight: FontWeight.w900)),
              SizedBox(height: 7),
              Text('A IA faz triagem inicial. Conteúdo ambíguo fica retido para revisão humana; isto não substitui equipa de moderação, resposta a denúncias e salvaguardas de menores.',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
            ]))),
        ]),
      );
    },
  );
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final search = TextEditingController();
  String status = 'ALL';
  List<Map<String, dynamic>> users = [];
  bool loading = false;
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  void toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final params = <String>[];
      if (search.text.trim().isNotEmpty) params.add('q=' + Uri.encodeQueryComponent(search.text.trim()));
      if (status != 'ALL') params.add('status=' + status);
      final suffix = params.isEmpty ? '' : '?' + params.join('&');
      final result = await widget.api.get('/v1/admin/users' + suffix);
      if (mounted) setState(() => users = itemsOf(result['items']));
    } catch (e) { if (mounted) toast(e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> action(String uid, String name) async {
    try {
      await widget.api.post('/v1/admin/users/' + Uri.encodeComponent(uid), {'action': name});
      toast('Ação aplicada.');
      await load();
    } catch (e) { toast(e.toString()); }
  }

  Future<void> detail(String uid) async {
    try {
      final data = await widget.api.get('/v1/admin/users/' + Uri.encodeComponent(uid));
      final user = mapOf(data['user']);
      if (!mounted) return;
      final active = user['status'] == 'ACTIVE';
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(show(user['pilot_name'], 'Conta')),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailLine('UID', show(user['uid'])),
            DetailLine('Handle', '@' + show(user['pilot_handle'], 'sem handle')),
            DetailLine('País', show(user['country_code'])),
            DetailLine('Grupo declarado', show(user['declared_age_band'])),
            DetailLine('Estado', show(user['status'])),
            DetailLine('Enviados', show(mapOf(data['sent'])['total'], '0')),
            DetailLine('Recebidos', show(mapOf(data['received'])['total'], '0')),
            DetailLine('Denúncias abertas', show(mapOf(data['openReports'])['total'], '0')),
            DetailLine('Dispositivos', show(mapOf(data['deviceCount'])['total'], '0')),
            const SizedBox(height: 10),
            const Text('Suspender bloqueia o acesso; desativar aleatório retira a conta da correspondência.', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          TextButton(onPressed: () { Navigator.pop(ctx); action(uid, active ? 'suspend' : 'activate'); },
            child: Text(active ? 'Suspender' : 'Reativar', style: TextStyle(color: active ? danger : goldLight))),
          TextButton(onPressed: () { Navigator.pop(ctx); action(uid, 'disable_random'); }, child: const Text('Desativar aleatório')),
          TextButton(onPressed: () { Navigator.pop(ctx); action(uid, 'enable_random'); }, child: const Text('Ativar aleatório')),
        ]));
    } catch (e) { toast(e.toString()); }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(children: [
        const SectionTitle('Gestão de contas', 'Pesquisa por nome, @handle ou UID Firebase.'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: search, onSubmitted: (_) => load(),
            decoration: const InputDecoration(hintText: 'Pesquisar conta', prefixIcon: Icon(Icons.search)))),
          const SizedBox(width: 7),
          IconButton.filledTonal(onPressed: loading ? null : load, icon: const Icon(Icons.search)),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: status,
          decoration: const InputDecoration(labelText: 'Estado'),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('Todas')),
            DropdownMenuItem(value: 'ACTIVE', child: Text('Ativas')),
            DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspensas')),
            DropdownMenuItem(value: 'CLOSED', child: Text('Fechadas')),
          ],
          onChanged: (v) { setState(() => status = v ?? 'ALL'); load(); }),
      ]),
    ),
    if (loading) const LinearProgressIndicator(minHeight: 2, color: gold),
    Expanded(child: users.isEmpty && !loading
      ? const EmptyPanel(icon: Icons.person_search, text: 'Nenhuma conta encontrada.')
      : ListView.separated(
          padding: const EdgeInsets.all(12), itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (ctx, i) {
            final u = users[i];
            return Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0x22F0CE7C), child: Icon(Icons.person, color: goldLight)),
              title: Text(show(u['pilot_name']), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('@' + show(u['pilot_handle'], 'sem handle') + ' · ' + show(u['status']) + '\n' + show(u['uid']),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              isThreeLine: true,
              trailing: IconButton(onPressed: () => detail(u['uid'].toString()), icon: const Icon(Icons.chevron_right, color: goldLight)),
            ));
          })),
  ]);
}

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  List<Map<String, dynamic>> reports = [], planes = [], replies = [], blocks = [];
  bool loading = false;
  @override
  void initState() { super.initState(); load(); }
  void toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        widget.api.get('/v1/admin/reports'),
        widget.api.get('/v1/admin/review'),
        widget.api.get('/v1/admin/blocks'),
      ]);
      if (mounted) setState(() {
        reports = itemsOf(results[0]['items']);
        planes = itemsOf(results[1]['items']);
        replies = itemsOf(results[1]['replies']);
        blocks = itemsOf(results[2]['items']);
      });
    } catch (e) { if (mounted) toast(e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> reportAction(String id, String actionName) async {
    try { await widget.api.post('/v1/admin/reports/' + Uri.encodeComponent(id), {'action': actionName}); await load(); }
    catch (e) { toast(e.toString()); }
  }

  Future<void> reviewAction(String id, String actionName, {bool reply = false}) async {
    final path = reply
      ? '/v1/admin/replies/' + Uri.encodeComponent(id)
      : '/v1/admin/review/' + Uri.encodeComponent(id);
    try { await widget.api.post(path, {'action': actionName}); await load(); }
    catch (e) { toast(e.toString()); }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: SectionTitle('Segurança e moderação', 'Denúncias, conteúdo retido e bloqueios registados.')),
    if (loading) const LinearProgressIndicator(minHeight: 2, color: gold),
    Expanded(child: DefaultTabController(
      length: 3,
      child: Column(children: [
        const TabBar(isScrollable: true, tabs: [Tab(text: 'Denúncias'), Tab(text: 'Revisão'), Tab(text: 'Bloqueios')]),
        Expanded(child: TabBarView(children: [
          RefreshIndicator(onRefresh: load, child: reports.isEmpty
            ? const EmptyPanel(icon: Icons.flag_outlined, text: 'Sem denúncias abertas.')
            : ListView(padding: const EdgeInsets.all(12), children: reports.map((r) => Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(show(r['reason']), style: const TextStyle(color: goldLight, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(show(r['message_text'], show(r['details'], 'Sem mensagem associada.'))),
                const SizedBox(height: 6),
                Text('Conta: ' + show(r['reported_uid']) + ' · Denúncia: ' + show(r['id']),
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Wrap(children: [
                  TextButton(onPressed: () => reportAction(r['id'].toString(), 'dismiss'), child: const Text('Ignorar')),
                  TextButton(onPressed: () => reportAction(r['id'].toString(), 'actioned'), child: const Text('Concluir')),
                  TextButton(onPressed: r['reported_uid'] == null ? null : () => reportAction(r['id'].toString(), 'suspend_user'),
                    child: const Text('Suspender conta', style: TextStyle(color: danger))),
                ]),
              ]),
            ))).toList())),
          RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12), children: [
            const Text('AVIÕES RETIDOS', style: TextStyle(color: goldLight, fontWeight: FontWeight.w900)),
            if (planes.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Nenhum avião em revisão.', style: TextStyle(color: Colors.white60))),
            for (final p in planes) Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(show(p['message_text']), style: const TextStyle(height: 1.4)),
                Text('UID: ' + show(p['sender_uid']), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Wrap(children: [
                  TextButton(onPressed: () => reviewAction(p['id'].toString(), 'approve'), child: const Text('Aprovar')),
                  TextButton(onPressed: () => reviewAction(p['id'].toString(), 'reject'), child: const Text('Rejeitar', style: TextStyle(color: danger))),
                ]),
              ]))),
            const Divider(height: 24),
            const Text('RESPOSTAS PÚBLICAS RETIDAS', style: TextStyle(color: goldLight, fontWeight: FontWeight.w900)),
            if (replies.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Nenhuma resposta em revisão.', style: TextStyle(color: Colors.white60))),
            for (final p in replies) Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(show(p['message_text']), style: const TextStyle(height: 1.4)),
                Text('UID: ' + show(p['sender_uid']), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Wrap(children: [
                  TextButton(onPressed: () => reviewAction(p['id'].toString(), 'approve', reply: true), child: const Text('Aprovar')),
                  TextButton(onPressed: () => reviewAction(p['id'].toString(), 'reject', reply: true), child: const Text('Rejeitar', style: TextStyle(color: danger))),
                ]),
              ]))),
          ])),
          RefreshIndicator(onRefresh: load, child: blocks.isEmpty
            ? const EmptyPanel(icon: Icons.block, text: 'Sem bloqueios registados.')
            : ListView(padding: const EdgeInsets.all(12), children: blocks.map((b) => Card(child: ListTile(
              leading: const Icon(Icons.block, color: danger),
              title: Text('@' + show(b['blocker_handle'], show(b['blocker_uid'])) + ' bloqueou @' + show(b['blocked_handle'], show(b['blocked_uid']))),
              subtitle: Text(show(b['created_at']), style: const TextStyle(color: Colors.white54, fontSize: 10)),
              trailing: IconButton(
                tooltip: 'Remover bloqueio',
                icon: const Icon(Icons.link_off, color: danger),
                onPressed: () async {
                  try {
                    await widget.api.post(
                      '/v1/admin/blocks/' + Uri.encodeComponent(b['blocker_uid'].toString()) +
                      '/' + Uri.encodeComponent(b['blocked_uid'].toString()),
                      {'action': 'remove'},
                    );
                    await load();
                  } catch (e) {
                    toast(e.toString());
                  }
                },
              ),
            ))).toList())),
        ])),
      ]),
    )),
  ]);
}

class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  List<Map<String, dynamic>> tickets = [];
  bool loading = false;
  @override
  void initState() { super.initState(); load(); }
  void toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await widget.api.get('/v1/admin/support');
      if (mounted) setState(() => tickets = itemsOf(data['items']));
    } catch (e) { if (mounted) toast(e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> updateTicket(String id, String actionName) async {
    try { await widget.api.post('/v1/admin/support/' + Uri.encodeComponent(id), {'action': actionName}); await load(); }
    catch (e) { toast(e.toString()); }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.all(16),
      child: SectionTitle('Centro de suporte', 'Pedidos privados e problemas reportados pelos utilizadores.')),
    if (loading) const LinearProgressIndicator(minHeight: 2, color: gold),
    Expanded(child: tickets.isEmpty && !loading
      ? const EmptyPanel(icon: Icons.support_agent, text: 'Não há pedidos em aberto.')
      : RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(12),
          children: tickets.map((t) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(show(t['subject']), style: const TextStyle(color: goldLight, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(show(t['details']), style: const TextStyle(height: 1.4)),
              Text(show(t['category']) + ' · @' + show(t['pilot_handle']) + ' · ' + show(t['status']),
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Wrap(children: [
                TextButton(onPressed: () => updateTicket(t['id'].toString(), 'in_review'), child: const Text('Em análise')),
                TextButton(onPressed: () => updateTicket(t['id'].toString(), 'resolve'), child: const Text('Resolver')),
                TextButton(onPressed: () => updateTicket(t['id'].toString(), 'close'), child: const Text('Fechar')),
              ]),
            ]))).toList()))),
  ]);
}

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, required this.api});
  final AdminApi api;
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final title = TextEditingController();
  final body = TextEditingController();
  final uid = TextEditingController();
  bool sendAll = true, sending = false, loading = false;
  List<Map<String, dynamic>> history = [];
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { title.dispose(); body.dispose(); uid.dispose(); super.dispose(); }
  void toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Future<void> load() async {
    setState(() => loading = true);
    try {
      final result = await widget.api.get('/v1/admin/notifications');
      if (mounted) setState(() => history = itemsOf(result['items']));
    } catch (e) { if (mounted) toast(e.toString()); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> send() async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty || (!sendAll && uid.text.trim().isEmpty)) {
      toast('Preenche o título, a mensagem e o UID se o envio for individual.');
      return;
    }
    setState(() => sending = true);
    try {
      final result = await widget.api.post('/v1/admin/notifications', {
        'target': sendAll ? 'ALL' : 'USER',
        if (!sendAll) 'targetUid': uid.text.trim(),
        'title': title.text.trim(), 'body': body.text.trim(),
      });
      toast('Notificações entregues: ' + show(result['sentCount'], '0') +
        ' · falhas: ' + show(result['failedCount'], '0'));
      title.clear(); body.clear(); await load();
    } catch (e) { toast(e.toString()); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const SectionTitle('Notificações push', 'Avisos globais ou dirigidos a um utilizador específico.'),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Novo aviso', style: TextStyle(color: goldLight, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Todos'), icon: Icon(Icons.campaign)),
            ButtonSegment(value: false, label: Text('Um UID'), icon: Icon(Icons.person)),
          ],
          selected: {sendAll}, onSelectionChanged: (v) => setState(() => sendAll = v.first)),
        if (!sendAll) ...[
          const SizedBox(height: 10),
          TextField(controller: uid, decoration: const InputDecoration(labelText: 'UID Firebase do destinatário')),
        ],
        const SizedBox(height: 10),
        TextField(controller: title, maxLength: 80, decoration: const InputDecoration(labelText: 'Título')),
        const SizedBox(height: 8),
        TextField(controller: body, maxLength: 220, maxLines: 4,
          decoration: const InputDecoration(labelText: 'Mensagem', alignLabelWithHint: true)),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: sending ? null : send,
          icon: sending ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send), label: Text(sending ? 'A enviar…' : 'Enviar notificação')),
        const SizedBox(height: 8),
        const Text('Só recebem dispositivos ativos com notificações ligadas. Cada envio fica no histórico.',
          style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4)),
      ]))),
    const SizedBox(height: 18),
    Row(children: [
      const Expanded(child: Text('Histórico de envios', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
      IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh)),
    ]),
    if (loading) const LinearProgressIndicator(minHeight: 2, color: gold),
    if (history.isEmpty && !loading) const EmptyPanel(icon: Icons.notifications_none, text: 'Ainda não foram enviados avisos.'),
    for (final row in history) Card(child: ListTile(
      leading: Icon(row['target_type'] == 'ALL' ? Icons.campaign : Icons.person, color: goldLight),
      title: Text(show(row['title']), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(show(row['body']) + '\n' +
        (row['target_type'] == 'ALL' ? 'Todos' : 'UID: ' + show(row['recipient_uid'])) +
        ' · enviados ' + show(row['sent_count'], '0') + '/' + show(row['device_count'], '0') +
        ' · falhas ' + show(row['failed_count'], '0'),
        style: const TextStyle(color: Colors.white60, fontSize: 11)),
      isThreeLine: true,
    )),
  ]);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.4)),
    const SizedBox(height: 4),
    Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
  ]);
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Icon(icon, color: goldLight),
      Text(value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ],
  )));
}

class DetailLine extends StatelessWidget {
  const DetailLine(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
      Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12))),
    ]),
  );
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 48),
      Icon(icon, size: 42, color: Colors.white30),
      const SizedBox(height: 12),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
    ],
  );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off, size: 42, color: danger),
      const SizedBox(height: 12),
      Text(error, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
    ]),
  ));
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: goldLight),
      SizedBox(height: 12),
      Text('A validar e carregar…', style: TextStyle(color: Colors.white60)),
    ])));
}

class MessagePage extends StatelessWidget {
  const MessagePage({super.key, required this.title, required this.detail, required this.icon, this.action});
  final String title, detail;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 56, color: goldLight),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ))),
  );
}
