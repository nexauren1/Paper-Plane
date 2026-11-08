import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/paper_plane_api.dart';

const Color _ageNavy = Color(0xFF071225);
const Color _ageGold = Color(0xFFF0CE7C);
const Color _ageGoldBright = Color(0xFFFFE7A8);

class AgeVerificationScreen extends StatefulWidget {
  const AgeVerificationScreen({super.key});

  @override
  State<AgeVerificationScreen> createState() => _AgeVerificationScreenState();
}

class _AgeVerificationScreenState extends State<AgeVerificationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  Map<String, dynamic>? _session;
  bool _busy = false;
  bool _verified = false;
  String _status = 'NOT_STARTED';
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await PaperPlaneApi.instance.getProfile();
      final pilot = response['pilot'] as Map<String, dynamic>? ?? const {};
      if (pilot['age_verified'] == 1 && mounted) {
        setState(() {
          _verified = true;
          _status = 'VERIFIED';
          _message = 'A tua faixa etária já está confirmada.';
        });
      }
    } catch (_) {
      // The authenticated status check is repeated when the user starts or resumes verification.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _session != null && !_verified) {
      _checkStatus();
    }
  }

  Future<void> _start() async {
    if (_busy || _verified) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = 'A preparar uma sessão segura de verificação…';
    });
    try {
      final response = await PaperPlaneApi.instance.startAgeVerification();
      if (response['status'] == 'VERIFIED') {
        _complete(response['ageBand']?.toString());
        return;
      }
      final session = response['session'] as Map<String, dynamic>?;
      if (session == null || session['id'] == null || session['verifyUrl'] == null) {
        throw const PaperPlaneApiException(
          'AGE_SESSION_INVALID',
          'O servidor não devolveu uma sessão de verificação válida.',
        );
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _status = 'PENDING';
        _message = 'Confirma a idade no serviço seguro. Depois regressa a esta aplicação.';
      });
      await _openProvider();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PaperPlaneApiException
            ? error.message
            : 'Não foi possível iniciar a verificação. Confirma a ligação e tenta novamente.';
        _message = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openProvider() async {
    final raw = _session?['verifyUrl']?.toString();
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (uri == null || !(uri.scheme == 'https' && uri.host == 'age.yoti.com')) {
      if (mounted) setState(() => _error = 'A ligação de verificação não é válida.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Não foi possível abrir a página segura. Tenta novamente.');
    }
  }

  Future<void> _checkStatus() async {
    final id = _session?['id']?.toString();
    if (id == null || id.isEmpty || _busy || _verified) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = 'A confirmar o resultado com o servidor…';
    });
    try {
      final response = await PaperPlaneApi.instance.getAgeVerificationStatus(id);
      final status = response['status']?.toString() ?? 'PENDING';
      if (status == 'VERIFIED') {
        _complete(response['ageBand']?.toString());
        return;
      }
      if (status == 'NEXT_STEP' || status == 'DOCUMENT_CHECK_REQUIRED') {
        final next = response['nextSession'] as Map<String, dynamic>?;
        if (next == null || next['id'] == null || next['verifyUrl'] == null) {
          throw const PaperPlaneApiException(
            'AGE_SESSION_INVALID',
            'O servidor não devolveu a próxima etapa de verificação.',
          );
        }
        if (!mounted) return;
        setState(() {
          _session = next;
          _status = 'PENDING';
          _message = response['message']?.toString() ??
              'Abre a próxima etapa para concluir a verificação.';
        });
        await _openProvider();
        return;
      }
      if (status == 'FAILED' || status == 'ERROR') {
        if (!mounted) return;
        setState(() {
          _status = status;
          _message = response['message']?.toString() ??
              'Não foi possível confirmar a idade. Podes iniciar uma nova tentativa.';
          _session = null;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _status = 'PENDING';
        _message = 'O fornecedor ainda está a processar a verificação. Volta a consultar dentro de alguns instantes.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PaperPlaneApiException
            ? error.message
            : 'Não foi possível consultar o resultado. Tenta novamente.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _complete(String? ageBand) {
    if (!mounted) return;
    setState(() {
      _verified = true;
      _status = 'VERIFIED';
      _message = ageBand == 'ADULT'
          ? 'Faixa adulta confirmada. O teu primeiro avião pode seguir viagem.'
          : 'Faixa 13–17 confirmada. O teu avião será encaminhado apenas para pilotos da mesma faixa.';
    });
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _status == 'PENDING' && _session != null;
    return Scaffold(
      backgroundColor: _ageNavy,
      appBar: AppBar(
        backgroundColor: _ageNavy,
        foregroundColor: _ageGoldBright,
        title: const Text('Verificação segura de idade'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _AgeStars()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final scale = 0.96 + _pulse.value * 0.07;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _ageGold.withOpacity(0.10),
                            border: Border.all(color: _ageGold.withOpacity(0.55), width: 1.4),
                            boxShadow: [
                              BoxShadow(
                                color: _ageGold.withOpacity(0.12 + _pulse.value * 0.12),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.verified_user_rounded, color: _ageGoldBright, size: 58),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Protegemos cada viagem.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 9),
                const Text(
                  'O Paper Plane confirma primeiro a idade mínima de 13 anos e depois determina a faixa 13–17 ou adulta. Só permite correspondência entre pessoas da mesma faixa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.55),
                ),
                const SizedBox(height: 20),
                _step('01', 'Confirmar idade mínima', 'A primeira etapa confirma que a conta cumpre a idade mínima do serviço.'),
                const SizedBox(height: 9),
                _step('02', 'Definir a faixa de segurança', 'A segunda etapa determina se o piloto pertence à faixa 13–17 ou adulta.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xCC172844),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                  ),
                  child: const Text(
                    'A data indicada no perfil não é usada como prova. A verificação é feita pelo fornecedor especializado. O Paper Plane guarda apenas o estado e a faixa etária resultante; não recebe nem guarda fotografias de documentos ou selfies.',
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  _statusPanel(_status, _message!),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFA7A7), height: 1.45)),
                ],
                const SizedBox(height: 20),
                if (_verified)
                  const _GoldButton(label: 'Verificação concluída', icon: Icons.check_circle_rounded, busy: false, onPressed: null)
                else if (waiting) ...[
                  _GoldButton(
                    label: 'Abrir verificação segura',
                    icon: Icons.open_in_new_rounded,
                    busy: _busy,
                    onPressed: _busy ? null : _openProvider,
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _checkStatus,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded),
                    label: const Text('Já terminei — consultar estado'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ageGoldBright,
                      side: BorderSide(color: _ageGold.withOpacity(0.45)),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    ),
                  ),
                ] else
                  _GoldButton(
                    label: _busy ? 'A preparar…' : 'Começar verificação',
                    icon: Icons.shield_outlined,
                    busy: _busy,
                    onPressed: _busy ? null : _start,
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(false),
                  child: const Text('Voltar ao hangar', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String number, String title, String body) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF10223B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _ageGold.withOpacity(0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _ageGold.withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(color: _ageGold.withOpacity(0.45)),
              ),
              alignment: Alignment.center,
              child: Text(number, style: const TextStyle(color: _ageGoldBright, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4)),
              ]),
            ),
          ],
        ),
      );

  Widget _statusPanel(String status, String value) {
    final success = status == 'VERIFIED';
    final failed = status == 'FAILED' || status == 'ERROR';
    final color = success ? const Color(0xFF7DDAA0) : failed ? const Color(0xFFFFA7A7) : _ageGoldBright;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(success ? Icons.check_circle_outline : failed ? Icons.info_outline : Icons.hourglass_top_rounded, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: TextStyle(color: color, fontSize: 12, height: 1.45))),
      ]),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 58,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _ageNavy))
              : Icon(icon),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: _ageGold,
            foregroundColor: _ageNavy,
            disabledBackgroundColor: Colors.white24,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class _AgeStars extends StatelessWidget {
  const _AgeStars();

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _AgeStarsPainter());
}

class _AgeStarsPainter extends CustomPainter {
  const _AgeStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 70; i++) {
      final x = (i * 83 % 997) / 997 * size.width;
      final y = (i * 137 % 991) / 991 * size.height;
      final radius = 0.5 + (i % 4) * 0.35;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = (i % 9 == 0 ? _ageGoldBright : Colors.white).withOpacity(0.12 + (i % 5) * 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AgeStarsPainter oldDelegate) => false;
}
