import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_runtime.dart';
import '../services/paper_plane_api.dart';
import '../services/paper_plane_auth.dart';
import 'pilot_profile_setup_screen.dart';

const Color _navy = Color(0xFF071225);
const Color _gold = Color(0xFFF0CE7C);
const Color _goldLight = Color(0xFFFFE7A8);

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _creating = false;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    String message;
    try {
      if (_creating) {
        await PaperPlaneAuth.createAccountWithEmail(
          email: _email.text,
          password: _password.text,
        );
        message = 'Conta criada com sucesso.';
      } else {
        await PaperPlaneAuth.signInWithEmail(
          email: _email.text,
          password: _password.text,
        );
        message = 'Sessão iniciada com sucesso.';
      }
      message = await _syncPilot(message);
    } catch (error) {
      message = _friendlyError(error);
    }

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _continueWithGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);

    String message;
    try {
      await PaperPlaneAuth.signInWithGoogle();
      message = await _syncPilot('Conta Google ligada com sucesso.');
    } catch (error) {
      message = _friendlyError(error);
    }

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<String> _syncPilot(String successMessage) async {
    final result = await PaperPlaneApi.instance.bootstrapPilot();
    final pilot = result['pilot'] as Map<String, dynamic>? ?? const {};
    if (pilot['profile_completed'] != 1) {
      if (!mounted) return '$successMessage';
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PilotProfileSetupScreen()),
      );
      if (completed != true) {
        return 'A conta foi criada, mas falta completar o perfil de copiloto para utilizar os voos.';
      }
    }
    return '$successMessage Perfil sincronizado com o Paper Plane.';
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduz primeiro o teu endereço de email.')),
      );
      return;
    }

    setState(() => _busy = true);
    String message;
    try {
      await PaperPlaneAuth.sendPasswordReset(email);
      message = 'Enviámos uma ligação para redefinir a palavra-passe.';
    } catch (error) {
      message = _friendlyError(error);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await PaperPlaneAuth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão terminada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'O endereço de email não é válido.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email ou palavra-passe incorretos.',
        'email-already-in-use' || 'credential-already-in-use' =>
          'Este email já está associado a uma conta. Escolhe Iniciar sessão.',
        'weak-password' => 'A palavra-passe deve ter pelo menos 6 caracteres.',
        'too-many-requests' => 'Muitas tentativas. Aguarda um pouco e tenta novamente.',
        'network-request-failed' => 'Sem ligação à internet. Verifica a rede.',
        'operation-not-allowed' => 'Este método ainda não está ativado no Firebase.',
        'account-exists-with-different-credential' =>
          'Este email já está associado a outro método de acesso.',
        _ => 'Não foi possível concluir a autenticação (${error.code}).',
      };
    }
    if (error is PaperPlaneApiException) return error.message;
    final raw = error.toString();
    if (raw.contains('canceled')) return 'Início de sessão cancelado.';
    if (raw.contains('clientConfigurationError') ||
        raw.contains('serverClientId') ||
        raw.contains('DEVELOPER_ERROR')) {
      return 'A configuração Google OAuth precisa de ser verificada no Firebase, incluindo a assinatura SHA do Android.';
    }
    return 'Não foi possível concluir a operação. Verifica a ligação e tenta novamente.';
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseRuntime.isInitialized) {
      return _frame(
        child: const _InfoPanel(
          icon: Icons.cloud_off_outlined,
          title: 'Firebase ainda não está ativo',
          body: 'Esta compilação precisa de ser feita com a configuração Firebase do Paper Plane.',
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null && !user.isAnonymous) {
          return _frame(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const _AccountHero(
                  icon: Icons.verified_user_outlined,
                  title: 'Conta ligada',
                  subtitle: 'A tua identidade está protegida pelo Firebase Authentication.',
                ),
                const SizedBox(height: 18),
                _AccountCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Conta atual', style: TextStyle(color: _goldLight, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(user.email ?? 'Conta Google', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        user.providerData.map((provider) => provider.providerId).join(' · '),
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GoldAction(
                  label: 'Terminar sessão',
                  icon: Icons.logout_rounded,
                  busy: _busy,
                  onPressed: _signOut,
                ),
              ],
            ),
          );
        }

        return _frame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _AccountHero(
                icon: _creating ? Icons.person_add_alt_1_rounded : Icons.flight_takeoff_rounded,
                title: _creating ? 'Criar conta' : 'Bem-vindo de volta',
                subtitle: _creating
                    ? 'Guarda o teu piloto e mantém a tua conta acessível.'
                    : 'Entra para manter a tua identidade sincronizada.',
              ),
              const SizedBox(height: 18),
              _AccountCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _ModeTab(label: 'Entrar', selected: !_creating, onTap: () => setState(() => _creating = false))),
                        const SizedBox(width: 8),
                        Expanded(child: _ModeTab(label: 'Criar conta', selected: _creating, onTap: () => setState(() => _creating = true))),
                      ],
                    ),
                    const SizedBox(height: 19),
                    _form(),
                    const SizedBox(height: 14),
                    _GoldAction(
                      label: _creating ? 'Criar conta com email' : 'Entrar com email',
                      icon: _creating ? Icons.person_add_alt_1 : Icons.login_rounded,
                      busy: _busy,
                      onPressed: _submit,
                    ),
                    if (!_creating)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: const Text('Esqueci-me da palavra-passe', style: TextStyle(color: _goldLight)),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white24)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OU', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                          Expanded(child: Divider(color: Colors.white24)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _continueWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: const Text('Continuar com Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: _gold.withOpacity(0.45)),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(color: _gold, backgroundColor: Colors.white12),
                      const SizedBox(height: 6),
                      const Text('A autenticar a tua conta…', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Ao criar uma conta, não partilhes a tua palavra-passe com ninguém. O Paper Plane nunca a pede por mensagem.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              final email = value?.trim() ?? '';
              if (!email.contains('@') || email.length < 5) return 'Introduz um email válido.';
              return null;
            },
            decoration: _inputDecoration('Email', Icons.email_outlined),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            enabled: !_busy,
            obscureText: !_showPassword,
            autofillHints: _creating ? const [AutofillHints.newPassword] : const [AutofillHints.password],
            validator: (value) {
              if ((value ?? '').length < 6) return 'Usa pelo menos 6 caracteres.';
              return null;
            },
            decoration: _inputDecoration(
              'Palavra-passe',
              Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white60),
              ),
            ),
          ),
          if (_creating) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassword,
              enabled: !_busy,
              obscureText: !_showPassword,
              validator: (value) {
                if (value != _password.text) return 'As palavras-passe não coincidem.';
                return null;
              },
              decoration: _inputDecoration('Confirmar palavra-passe', Icons.lock_reset_rounded),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _goldLight),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF0D1B30),
      labelStyle: const TextStyle(color: Colors.white60),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _gold, width: 1.4)),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _frame({required Widget child}) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _goldLight,
        title: const Text('A tua conta', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_navy, Color(0xFF0A1930), Color(0xFF040A15)],
          ),
        ),
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withOpacity(0.12),
            border: Border.all(color: _gold.withOpacity(0.55)),
            boxShadow: [BoxShadow(color: _gold.withOpacity(0.10), blurRadius: 22, spreadRadius: 2)],
          ),
          child: Icon(icon, color: _goldLight, size: 32),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.4)),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xCC172844),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? _gold.withOpacity(0.16) : Colors.transparent,
          foregroundColor: selected ? _goldLight : Colors.white60,
          side: BorderSide(color: selected ? _gold.withOpacity(0.65) : Colors.white12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _GoldAction extends StatelessWidget {
  const _GoldAction({required this.label, required this.icon, required this.busy, required this.onPressed});
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: _navy))
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        style: FilledButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _navy,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _goldLight, size: 48),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
