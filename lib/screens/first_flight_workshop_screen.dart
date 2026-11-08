import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/paper_plane_api.dart';

const Color _workshopNavy = Color(0xFF071225);
const Color _workshopGold = Color(0xFFF0CE7C);
const Color _workshopGoldBright = Color(0xFFFFE7A8);
const Color _workshopPaper = Color(0xFFF3EFE5);

class FirstFlightWorkshopScreen extends StatefulWidget {
  const FirstFlightWorkshopScreen({
    super.key,
    this.initialMessage = '',
    this.initialPlaneModel = 'DART',
  });

  final String initialMessage;
  final String initialPlaneModel;

  @override
  State<FirstFlightWorkshopScreen> createState() => _FirstFlightWorkshopScreenState();
}

class _FirstFlightWorkshopScreenState extends State<FirstFlightWorkshopScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _message = TextEditingController();
  late final AnimationController _fold = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  String _model = 'DART';
  bool _busy = false;
  bool _waitingForAge = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _message.text = widget.initialMessage;
    const availableModels = ['DART', 'GLIDER', 'SWALLOW'];
    if (availableModels.contains(widget.initialPlaneModel.toUpperCase())) {
      _model = widget.initialPlaneModel.toUpperCase();
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _fold.dispose();
    super.dispose();
  }

  Future<void> _launchFirstPlane() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Escreve primeiro uma mensagem para dentro do avião.');
      return;
    }
    if (text.runes.length > 200) {
      setState(() => _error = 'A primeira carta pode ter no máximo 200 caracteres.');
      return;
    }
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _fold.forward();
      final saved = await PaperPlaneApi.instance.saveFirstFlight(
        message: text,
        planeModel: _model,
      );
      final privateOnly = saved['privateOnly'] == true;
      if (!privateOnly) {
        final launched = await PaperPlaneApi.instance.sendPlane(
          message: text,
          language: 'pt',
          mood: 'Esperança',
          visibility: 'Aleatório 1-para-1',
          destinationCountry: null,
          allowReply: true,
          planeModel: _model,
        );
        final airplane = launched['airplane'] as Map<String, dynamic>? ?? const {};
        final id = airplane['id']?.toString();
        if (id == null || id.isEmpty) {
          throw const PaperPlaneApiException(
            'AIRPLANE_NOT_CREATED',
            'O servidor não confirmou o lançamento do primeiro avião.',
          );
        }
        if (!mounted) return;
        Navigator.of(context).pop({
          'completed': true,
          'airplaneId': id,
          'privateOnly': false,
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _waitingForAge = true;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is PaperPlaneApiException
            ? error.message
            : 'Não foi possível guardar o primeiro avião. Verifica a ligação e tenta novamente.';
      });
      _fold.reverse();
    }
  }

  void _continueToSky() {
    Navigator.of(context).pop({
      'completed': true,
      'privateOnly': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_waitingForAge) {
      return Scaffold(
        backgroundColor: _workshopNavy,
        body: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _WorkshopStarsPainter())),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.inventory_2_outlined, color: _workshopGoldBright, size: 58),
                  const SizedBox(height: 18),
                  const Text('O teu primeiro avião está no hangar', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  const Text(
                    'Guardámos a tua carta na tua conta online. O avião ainda não foi enviado a outra pessoa: o servidor só liberta voos para desconhecidos depois da verificação de idade confiável.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _continueToSky,
                      icon: const Icon(Icons.flight_takeoff_rounded),
                      label: const Text('Entrar no meu céu'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _workshopGold,
                        foregroundColor: _workshopNavy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: _workshopNavy,
      appBar: AppBar(
        backgroundColor: _workshopNavy,
        foregroundColor: _workshopGoldBright,
        title: const Text('Constrói o teu primeiro avião', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: _WorkshopStarsPainter())),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(19, 8, 19, 28),
            children: [
              const Text('Toda a viagem começa com uma dobra.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Escolhe o desenho, escreve a tua primeira carta e vê o papel ganhar asas.', style: TextStyle(color: Colors.white70, height: 1.45)),
              const SizedBox(height: 16),
              Container(
                height: 190,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF132B4A), Color(0xFF08152A)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _workshopGold.withOpacity(0.38)),
                  boxShadow: [BoxShadow(color: _workshopGold.withOpacity(0.08), blurRadius: 22)],
                ),
                child: AnimatedBuilder(
                  animation: _fold,
                  builder: (context, _) => CustomPaint(
                    painter: _PaperFoldPainter(progress: _fold.value, model: _model),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Escolhe o formato do avião', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _workshopGoldBright)),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: _planeOption('DART', 'Dardo', 'Rápido e direto')),
                const SizedBox(width: 8),
                Expanded(child: _planeOption('GLIDER', 'Planador', 'Asas largas')),
                const SizedBox(width: 8),
                Expanded(child: _planeOption('SWALLOW', 'Andorinha', 'Leve e elegante')),
              ]),
              const SizedBox(height: 17),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: _workshopPaper,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('A tua primeira carta', style: TextStyle(color: Color(0xFF766B58), fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _message,
                    maxLength: 200,
                    maxLines: 4,
                    minLines: 3,
                    style: const TextStyle(color: Color(0xFF252A33), fontSize: 17, height: 1.4),
                    decoration: const InputDecoration(
                      hintText: 'Escreve algo gentil para o mundo…',
                      hintStyle: TextStyle(color: Color(0xFF8B877F)),
                      border: InputBorder.none,
                      counterStyle: TextStyle(color: Color(0xFF82745A)),
                    ),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF9D9D), fontSize: 12)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 62,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _launchFirstPlane,
                  icon: _busy
                      ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: _workshopNavy))
                      : const Icon(Icons.send_rounded),
                  label: Text(_busy ? 'A dobrar e lançar…' : 'Lançar o meu primeiro avião'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _workshopGold,
                    foregroundColor: _workshopNavy,
                    disabledBackgroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const Text('O avião e o texto são guardados online. Não há envio fictício nem destinatário inventado.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white45, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _planeOption(String model, String title, String description) {
    final selected = _model == model;
    return GestureDetector(
      onTap: _busy ? null : () => setState(() {
        _model = model;
        _fold.reset();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(7, 10, 7, 11),
        decoration: BoxDecoration(
          color: selected ? _workshopGold.withOpacity(0.17) : const Color(0xFF10223B),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: selected ? _workshopGold : Colors.white.withOpacity(0.12), width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: _workshopGold.withOpacity(0.12), blurRadius: 14)] : const [],
        ),
        child: Column(children: [
          SizedBox(
            height: 58,
            child: CustomPaint(painter: _PlaneTypePainter(model: model), child: const SizedBox.expand()),
          ),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: selected ? _workshopGoldBright : Colors.white)),
          const SizedBox(height: 3),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white60)),
        ]),
      ),
    );
  }
}

class _PlaneTypePainter extends CustomPainter {
  const _PlaneTypePainter({required this.model});
  final String model;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    switch (model) {
      case 'GLIDER':
        path
          ..moveTo(center.dx, size.height * 0.08)
          ..lineTo(size.width * 0.97, size.height * 0.82)
          ..lineTo(center.dx, size.height * 0.64)
          ..lineTo(size.width * 0.03, size.height * 0.82)
          ..close();
        break;
      case 'SWALLOW':
        path
          ..moveTo(center.dx, size.height * 0.05)
          ..lineTo(size.width * 0.96, size.height * 0.82)
          ..lineTo(center.dx + 6, size.height * 0.62)
          ..lineTo(center.dx, size.height * 0.93)
          ..lineTo(center.dx - 6, size.height * 0.62)
          ..lineTo(size.width * 0.04, size.height * 0.82)
          ..close();
        break;
      default:
        path
          ..moveTo(center.dx, size.height * 0.04)
          ..lineTo(size.width * 0.91, size.height * 0.85)
          ..lineTo(center.dx, size.height * 0.65)
          ..lineTo(size.width * 0.09, size.height * 0.85)
          ..close();
    }
    canvas.drawPath(path, Paint()..color = _workshopPaper);
    canvas.drawPath(path, Paint()
      ..color = _workshopGoldBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeJoin = StrokeJoin.round);
    final fold = Path()
      ..moveTo(center.dx, size.height * 0.05)
      ..lineTo(center.dx, size.height * 0.65);
    canvas.drawPath(fold, Paint()..color = const Color(0xFF9A8B70)..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _PlaneTypePainter oldDelegate) => oldDelegate.model != model;
}

class _PaperFoldPainter extends CustomPainter {
  const _PaperFoldPainter({required this.progress, required this.model});
  final double progress;
  final String model;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final paperOpacity = (1 - t * 0.96).clamp(0.0, 1.0);
    final planeOpacity = t.clamp(0.0, 1.0);

    final sheet = Rect.fromCenter(center: center, width: size.width * 0.62, height: size.height * 0.58);
    final paper = Path()..addRRect(RRect.fromRectAndRadius(sheet, const Radius.circular(5)));
    canvas.drawPath(paper, Paint()..color = _workshopPaper.withOpacity(paperOpacity));
    final crease = Paint()..color = const Color(0xFFB5A98F).withOpacity(paperOpacity)..strokeWidth = 1;
    canvas.drawLine(Offset(sheet.left, center.dy), Offset(sheet.right, center.dy), crease);
    canvas.drawLine(Offset(center.dx, sheet.top), Offset(center.dx, sheet.bottom), crease);
    final foldGlow = Paint()
      ..color = _workshopGoldBright.withOpacity(0.55 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final shimmer = Path()
      ..moveTo(sheet.left, sheet.bottom)
      ..quadraticBezierTo(center.dx, center.dy, sheet.right, sheet.top);
    canvas.drawPath(shimmer, foldGlow);

    canvas.save();
    canvas.translate(center.dx, center.dy + (1 - t) * 28);
    canvas.scale(0.35 + t * 0.85);
    canvas.rotate((1 - t) * -0.42);
    final planeSize = Size(size.width * 0.65, size.height * 0.55);
    final planeRect = Rect.fromCenter(center: Offset.zero, width: planeSize.width, height: planeSize.height);
    final plane = Path();
    switch (model) {
      case 'GLIDER':
        plane
          ..moveTo(0, -planeRect.height * 0.48)
          ..lineTo(planeRect.width * 0.5, planeRect.height * 0.38)
          ..lineTo(0, planeRect.height * 0.13)
          ..lineTo(-planeRect.width * 0.5, planeRect.height * 0.38)
          ..close();
        break;
      case 'SWALLOW':
        plane
          ..moveTo(0, -planeRect.height * 0.5)
          ..lineTo(planeRect.width * 0.5, planeRect.height * 0.4)
          ..lineTo(5, planeRect.height * 0.16)
          ..lineTo(0, planeRect.height * 0.48)
          ..lineTo(-5, planeRect.height * 0.16)
          ..lineTo(-planeRect.width * 0.5, planeRect.height * 0.4)
          ..close();
        break;
      default:
        plane
          ..moveTo(0, -planeRect.height * 0.5)
          ..lineTo(planeRect.width * 0.48, planeRect.height * 0.43)
          ..lineTo(0, planeRect.height * 0.16)
          ..lineTo(-planeRect.width * 0.48, planeRect.height * 0.43)
          ..close();
    }
    canvas.drawPath(plane, Paint()
      ..color = _workshopGold.withOpacity(0.25 * planeOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    canvas.drawPath(plane, Paint()..color = _workshopPaper.withOpacity(planeOpacity));
    canvas.drawPath(plane, Paint()..color = _workshopGoldBright.withOpacity(planeOpacity)..style = PaintingStyle.stroke..strokeWidth = 1.6);
    canvas.restore();

    if (t > 0.25) {
      final sparks = Paint()..color = _workshopGoldBright.withOpacity((t - 0.25) * 0.8);
      for (var i = 0; i < 13; i++) {
        final angle = i * math.pi * 2 / 13;
        final distance = (0.2 + (i % 4) * 0.07) * size.width * t;
        canvas.drawCircle(
          Offset(center.dx + math.cos(angle) * distance, center.dy + math.sin(angle) * distance),
          1.2 + (i % 3) * 0.5,
          sparks,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperFoldPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.model != model;
}

class _WorkshopStarsPainter extends CustomPainter {
  const _WorkshopStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(31);
    for (var i = 0; i < 92; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.4 + random.nextDouble() * 1.3;
      final opacity = 0.12 + random.nextDouble() * 0.38;
      canvas.drawCircle(Offset(x, y), radius, Paint()..color = (i % 12 == 0 ? _workshopGoldBright : Colors.white).withOpacity(opacity));
    }
  }

  @override
  bool shouldRepaint(covariant _WorkshopStarsPainter oldDelegate) => false;
}
