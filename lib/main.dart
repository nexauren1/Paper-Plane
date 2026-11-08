import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'services/firebase_runtime.dart';
import 'services/paper_plane_api.dart';
import 'services/paper_plane_auth.dart';
import 'services/paper_plane_notifications.dart';
import 'services/paper_plane_analytics.dart';
import 'screens/account_screen.dart';
import 'screens/pilot_profile_setup_screen.dart';

const Color ppNavy = Color(0xFF071225);
const Color ppNavyDeep = Color(0xFF040A15);
const Color ppBlue = Color(0xFF243F70);
const Color ppBlueLight = Color(0xFF83B8FF);
const Color ppGold = Color(0xFFF0CE7C);
const Color ppGoldBright = Color(0xFFFFE7A8);
const Color ppPaper = Color(0xFFF4F0E7);
const Color ppInk = Color(0xFF242735);
const Color ppPanel = Color(0xCC172844);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseRuntime.initialize();
  await PaperPlaneAnalytics.initialize();
  runApp(const PaperPlaneApp());
}

class PaperPlaneApp extends StatelessWidget {
  const PaperPlaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paper Plane',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        if (FirebaseRuntime.isInitialized)
          FirebaseAnalyticsObserver(
            analytics: FirebaseAnalytics.instance,
            nameExtractor: (settings) => settings.name ?? 'PaperPlaneScreen',
          ),
      ],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ppNavy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ppGold,
          brightness: Brightness.dark,
        ).copyWith(
          primary: ppGold,
          secondary: ppBlueLight,
          surface: ppNavy,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.7),
          headlineMedium: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

void ppPush(BuildContext context, Widget page) {
  Navigator.of(context).push(
    PageRouteBuilder(
      settings: RouteSettings(name: page.runtimeType.toString()),
      pageBuilder: (_, animation, secondaryAnimation) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.035, 0), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 420),
    ),
  );
}

class SpaceBackground extends StatelessWidget {
  const SpaceBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF08172E), Color(0xFF081329), Color(0xFF040A15)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: StarFieldPainter())),
          Positioned(
            top: -115,
            right: -110,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ppBlue.withOpacity(0.10),
                boxShadow: [BoxShadow(color: ppBlue.withOpacity(0.15), blurRadius: 100, spreadRadius: 30)],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class StarFieldPainter extends CustomPainter {
  const StarFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(21);
    for (var i = 0; i < 125; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.15 + 0.2;
      final opacity = random.nextDouble() * 0.47 + 0.12;
      final color = i % 11 == 0 ? ppGoldBright : Colors.white;
      canvas.drawCircle(Offset(dx, dy), radius, Paint()..color = color.withOpacity(opacity));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlanePainter extends CustomPainter {
  const PlanePainter({this.color = ppGoldBright, this.glow = true, this.fill = true});
  final Color color;
  final bool glow;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final plane = Path()
      ..moveTo(size.width * 0.05, size.height * 0.42)
      ..lineTo(size.width * 0.95, size.height * 0.05)
      ..lineTo(size.width * 0.61, size.height * 0.95)
      ..lineTo(size.width * 0.43, size.height * 0.63)
      ..lineTo(size.width * 0.27, size.height * 0.81)
      ..lineTo(size.width * 0.30, size.height * 0.53)
      ..close();

    final fold = Path()
      ..moveTo(size.width * 0.30, size.height * 0.53)
      ..lineTo(size.width * 0.95, size.height * 0.05)
      ..lineTo(size.width * 0.43, size.height * 0.63);

    if (glow) {
      canvas.drawPath(
        plane,
        Paint()
          ..color = color.withOpacity(0.26)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
    }
    if (fill) {
      canvas.drawPath(plane, Paint()..color = color.withOpacity(0.12));
    }
    canvas.drawPath(
      plane,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      fold,
      Paint()
        ..color = color.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant PlanePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.glow != glow || oldDelegate.fill != fill;
}

class PlaneMark extends StatelessWidget {
  const PlaneMark({super.key, this.width = 112, this.color = ppGoldBright});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width * 0.68,
        child: CustomPaint(painter: PlanePainter(color: color)),
      );
}


class AnimatedPlane extends StatefulWidget {
  const AnimatedPlane({super.key, this.width = 112, this.color = ppGoldBright});
  final double width;
  final Color color;

  @override
  State<AnimatedPlane> createState() => _AnimatedPlaneState();
}

class _AnimatedPlaneState extends State<AnimatedPlane> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * math.pi * 2;
        return SizedBox(
          width: widget.width,
          height: widget.width * 0.78,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PlaneTrailPainter(color: widget.color, phase: _controller.value),
                ),
              ),
              Transform.translate(
                offset: Offset(math.sin(phase) * 3.5, -math.cos(phase * 0.8) * 5.5),
                child: Transform.rotate(
                  angle: math.sin(phase) * 0.025,
                  child: PlaneMark(width: widget.width * 0.82, color: widget.color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PlaneTrailPainter extends CustomPainter {
  const PlaneTrailPainter({required this.color, required this.phase});
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.87)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.78,
        size.width * 0.28,
        size.height * 0.40,
        size.width * 0.58,
        size.height * 0.28,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    for (var i = 0; i < 19; i++) {
      final t = i / 19;
      final x = size.width * (0.09 + t * 0.49);
      final y = size.height * (0.86 - 0.58 * t + 0.08 * math.sin(t * math.pi * 2 + phase));
      final radius = 0.7 + (1 - t) * 1.1;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withOpacity((1 - t) * 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PlaneTrailPainter oldDelegate) => oldDelegate.phase != phase || oldDelegate.color != color;
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.highlight = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: color ?? ppPanel,
        border: Border.all(
          color: highlight ? ppGold.withOpacity(0.58) : Colors.white.withOpacity(0.13),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 8)),
          if (highlight) BoxShadow(color: ppGold.withOpacity(0.11), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 58,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: ppInk,
          backgroundColor: ppGold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
          elevation: 5,
          shadowColor: ppGold.withOpacity(0.24),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 19),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: ppGoldBright,
          side: BorderSide(color: ppGold.withOpacity(0.48)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 18),
        child: Row(
          children: [
            Expanded(child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ppNavy,
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 7, 13, 9),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ppGoldBright, size: 20),
                    ),
                    Expanded(
                      child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    SizedBox(width: 44, child: action ?? const SizedBox.shrink()),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  late final Animation<double> _appear = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<double> _rise = Tween<double>(begin: 24, end: 0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'MainShell'),
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 650),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Opacity(
              opacity: _appear.value,
              child: Transform.translate(
                offset: Offset(0, _rise.value),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 34),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      const AnimatedPlane(width: 245, color: Colors.white),
                      const SizedBox(height: 36),
                      const Text(
                        'PAPER PLANE',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 34, letterSpacing: 3.5, fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Send a message to a stranger',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, color: Colors.white70),
                      ),
                      const Spacer(flex: 3),
                      GoldButton(label: 'Start Flying', icon: Icons.flight_takeoff_rounded, onPressed: _start, height: 66),
                      const SizedBox(height: 18),
                      const Text('Um pensamento. Um avião. O mundo inteiro.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onWrite: () => ppPush(context, const WritePlaneScreen()), onOpenInbox: () => setState(() => _index = 1)),
      const InboxPage(),
      const OpenSkyPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: ppNavy,
      body: SpaceBackground(
        child: SafeArea(
          child: IndexedStack(index: _index, children: pages),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xEE101D33),
          border: Border(top: BorderSide(color: ppGold.withOpacity(0.22))),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 70,
            backgroundColor: Colors.transparent,
            indicatorColor: ppGold.withOpacity(0.13),
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: ppGold), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded, color: ppGold), label: 'Caixa'),
              NavigationDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public, color: ppGold), label: 'Open Sky'),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: ppGold), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onWrite, required this.onOpenInbox});
  final VoidCallback onWrite;
  final VoidCallback onOpenInbox;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _sent = [];
  int _unread = 0;
  bool _loading = true;
  String? _error;

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) => _refresh());
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      await PaperPlaneAuth.ensureAnonymousPilot();
      final results = await Future.wait([
        PaperPlaneApi.instance.getProfile(),
        PaperPlaneApi.instance.getSentPlanes(),
        PaperPlaneApi.instance.getInbox(),
      ]);
      final pilot = results[0]['pilot'] as Map<String, dynamic>? ?? {};
      final sent = (results[1]['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      final inbox = (results[2]['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() {
        _profile = pilot;
        _sent = sent;
        _unread = inbox.where((item) => item['status'] == 'DELIVERED').length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException ? error.message : 'Não foi possível sincronizar o painel do piloto.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile['pilot_name']?.toString();
    final handle = _profile['pilot_handle']?.toString();
    final stats = _profile['stats'] as Map<String, dynamic>? ?? const {};
    final received = int.tryParse(stats['received']?.toString() ?? '') ?? 0;
    final active = _sent.where((plane) => ['QUEUED', 'FLYING'].contains(plane['status'])).length;
    final profileReady = _profile['profile_completed'] == 1;

    return RefreshIndicator(
      color: ppGold,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 24),
        children: [
          Row(children: [
            const Icon(Icons.send_rounded, color: ppGold, size: 22),
            const SizedBox(width: 8),
            const Text('PAPER PLANE', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800, color: ppGoldBright)),
            const Spacer(),
            IconButton(onPressed: widget.onOpenInbox, icon: const Icon(Icons.notifications_none_rounded, color: ppGoldBright)),
            IconButton(onPressed: () => ppPush(context, const ProfilePage()), icon: const Icon(Icons.account_circle_outlined, color: ppGoldBright)),
          ]),
          const SizedBox(height: 12),
          Text('Olá, ' + (name == null || name.isEmpty ? 'Piloto' : name), style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
          if (handle != null && handle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('@' + handle, style: const TextStyle(color: ppGoldBright, fontSize: 13)),
            ),
          const SizedBox(height: 5),
          const Text('O teu correio digital está ligado ao mundo.', style: TextStyle(color: Color(0xFFB8C8E5), fontSize: 14)),
          const SizedBox(height: 19),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(26), child: CircularProgressIndicator(color: ppGold)))
          else if (_error != null)
            GlassPanel(
              child: Column(children: [
                const Icon(Icons.cloud_off_outlined, color: Colors.orangeAccent, size: 30),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 9),
                OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
              ]),
            )
          else ...[
            if (!profileReady)
              GlassPanel(
                highlight: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Completa o teu perfil de copiloto', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  const Text('Escolhe o teu nome único, ano de nascimento e país para preparar a rota.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 10),
                  GoldButton(
                    label: 'Completar perfil',
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: () async {
                      final completed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const PilotProfileSetupScreen()),
                      );
                      if (completed == true) _refresh();
                    },
                  ),
                ]),
              ),
            GlassPanel(
              highlight: true,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
              child: Column(children: [
                const SizedBox(height: 4),
                const AnimatedPlane(width: 150),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _homeStat(Icons.flight_rounded, 'Voos ativos', active.toString())),
                  Container(width: 1, height: 62, color: Colors.white24),
                  Expanded(child: _homeStat(Icons.send_outlined, 'Aviões enviados', _sent.length.toString())),
                  Container(width: 1, height: 62, color: Colors.white24),
                  Expanded(child: _homeStat(Icons.mark_email_read_outlined, 'Recebidos', received.toString())),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            GoldButton(label: 'Escrever Avião', icon: Icons.edit_outlined, onPressed: widget.onWrite, height: 64),
            const SizedBox(height: 12),
            SizedBox(
              height: 58,
              child: OutlinedButton.icon(
                onPressed: widget.onOpenInbox,
                icon: const Icon(Icons.markunread_mailbox_outlined),
                label: Text(_unread == 0 ? 'Abrir caixa de entrada' : 'Abrir ' + _unread.toString() + ' carta(s) nova(s)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ppGoldBright,
                  side: BorderSide(color: ppGold.withOpacity(0.58)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  backgroundColor: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            const SectionTitle('Acompanhar voos'),
            if (_sent.where((plane) => ['QUEUED', 'FLYING'].contains(plane['status'])).isEmpty)
              const GlassPanel(child: Text('Não tens aviões em viagem neste momento.', style: TextStyle(color: Colors.white70)))
            else
              for (final plane in _sent.where((item) => ['QUEUED', 'FLYING'].contains(item['status'])).take(3)) ...[
                const SizedBox(height: 9),
                InkWell(
                  onTap: () => ppPush(context, FlightScreen(airplaneId: plane['id'].toString())),
                  borderRadius: BorderRadius.circular(18),
                  child: GlassPanel(
                    child: Row(children: [
                      const Icon(Icons.flight_takeoff_rounded, color: ppGoldBright, size: 27),
                      const SizedBox(width: 11),
                      Expanded(child: Text(
                        plane['status'] == 'QUEUED' ? 'À procura de destinatário' : 'Em viagem · ' + (plane['flight_distance_km']?.toString() ?? 'a calcular') + ' km',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      )),
                      const Icon(Icons.chevron_right, color: ppGold),
                    ]),
                  ),
                ),
              ],
            const SizedBox(height: 10),
            const Text('Os totais e os estados acima são carregados da conta e do servidor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _homeStat(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Column(children: [
      Icon(icon, color: ppGoldBright),
      const SizedBox(height: 5),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      const SizedBox(height: 1),
      Text(value, style: const TextStyle(fontSize: 27, color: ppGoldBright, fontWeight: FontWeight.w800)),
    ]),
  );
}

class WritePlaneScreen extends StatefulWidget {
  const WritePlaneScreen({super.key});
  @override
  State<WritePlaneScreen> createState() => _WritePlaneScreenState();
}

class _WritePlaneScreenState extends State<WritePlaneScreen> {
  final TextEditingController _message = TextEditingController();
  String _mood = 'Esperança';
  String _visibility = 'Aleatório 1-para-1';
  bool _allowReply = true;
  String _destination = 'Qualquer lugar do mundo';

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escreve uma mensagem antes de lançar o avião.')));
      return;
    }
    if (!FirebaseRuntime.isInitialized || !PaperPlaneApi.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível iniciar: liga a configuração Firebase e o servidor Cloudflare.')),
      );
      return;
    }

    var launchDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LaunchDialog(),
    );
    try {
      await PaperPlaneAuth.ensureAnonymousPilot();
      final profileResult = await PaperPlaneApi.instance.getProfile();
      final pilot = profileResult['pilot'] as Map<String, dynamic>? ?? const {};
      if (pilot['profile_completed'] != 1) {
        if (mounted) Navigator.of(context).pop();
        launchDialogOpen = false;
        final completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const PilotProfileSetupScreen()),
        );
        if (completed != true) return;
      }

      final result = await PaperPlaneApi.instance.sendPlane(
        message: _message.text.trim(),
        language: 'pt',
        mood: _mood,
        visibility: _visibility,
        destinationCountry: switch (_destination) {
          'Japão' => 'JP',
          'Portugal' => 'PT',
          'Brasil' => 'BR',
          _ => null,
        },
        allowReply: _allowReply,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      launchDialogOpen = false;
      final airplane = result['airplane'] as Map<String, dynamic>? ?? const {};
      final id = airplane['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const PaperPlaneApiException('AIRPLANE_NOT_CREATED', 'O servidor não confirmou a criação do avião.');
      }
      ppPush(context, FlightScreen(airplaneId: id));
    } catch (error) {
      if (!mounted) return;
      if (launchDialogOpen && Navigator.of(context).canPop()) Navigator.of(context).pop();
      final message = error is PaperPlaneApiException
          ? error.message
          : 'Não foi possível lançar o avião. Verifica a ligação e tenta novamente.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Escrever Avião',
      action: IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: ppGoldBright)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Container(
            height: 250,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ppPaper,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: ppGold.withOpacity(0.13), blurRadius: 18)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    maxLength: 200,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(color: ppInk, fontSize: 18, height: 1.45),
                    decoration: const InputDecoration(
                      hintText: 'Escreve algo gentil...',
                      hintStyle: TextStyle(color: Color(0xFF77736B)),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _message,
                    builder: (_, value, __) => Text(
                      value.text.length.toString() + '/200',
                      style: const TextStyle(color: Color(0xFF8A7856), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Escolhe o sentimento'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Felicidade', 'Tristeza', 'Esperança', 'Carinho'].map((mood) {
              final selected = _mood == mood;
              return ChoiceChip(
                selected: selected,
                label: Text(mood),
                avatar: Icon(_moodIcon(mood), size: 17),
                onSelected: (_) => setState(() => _mood = mood),
                selectedColor: ppGold.withOpacity(0.22),
                side: BorderSide(color: selected ? ppGold : Colors.white24),
                labelStyle: TextStyle(color: selected ? ppGoldBright : Colors.white70),
              );
            }).toList(),
          ),
          const SectionTitle('Visibilidade'),
          GlassPanel(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Público', label: Text('Público'), icon: Icon(Icons.public)),
                ButtonSegment(value: 'Aleatório 1-para-1', label: Text('Aleatório'), icon: Icon(Icons.person_outline)),
              ],
              selected: {_visibility},
              onSelectionChanged: (value) => setState(() => _visibility = value.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? ppInk : Colors.white70),
                backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? ppGold : Colors.transparent),
              ),
            ),
          ),
          const SectionTitle('Destino'),
          GlassPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public, color: ppGoldBright, size: 30),
              title: const Text('Destino'),
              subtitle: Text(_destination, style: const TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.chevron_right, color: ppGold),
              onTap: _chooseDestination,
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: ppGold,
              title: const Text('Permitir resposta'),
              subtitle: const Text('A pessoa poderá responder com outro avião.', style: TextStyle(color: Colors.white60, fontSize: 12)),
              value: _allowReply,
              onChanged: (value) => setState(() => _allowReply = value),
            ),
          ),
          const SizedBox(height: 18),
          GoldButton(label: 'Lançar avião', icon: Icons.send_rounded, onPressed: _send, height: 64),
          const SizedBox(height: 9),
          const Text('Máximo de 200 caracteres. O servidor gere a procura de destinatário, a rota e a entrega.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  IconData _moodIcon(String mood) {
    switch (mood) {
      case 'Felicidade': return Icons.wb_sunny_outlined;
      case 'Tristeza': return Icons.cloud_outlined;
      case 'Carinho': return Icons.favorite_border;
      default: return Icons.auto_awesome;
    }
  }

  Future<void> _chooseDestination() async {
    final destination = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF142542),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Escolher destino', style: TextStyle(fontWeight: FontWeight.w800))),
          ListTile(leading: const Icon(Icons.public, color: ppGold), title: const Text('Qualquer lugar do mundo'), onTap: () => Navigator.pop(context, 'Qualquer lugar do mundo')),
          ListTile(leading: const Icon(Icons.flag_outlined, color: ppGold), title: const Text('Japão'), onTap: () => Navigator.pop(context, 'Japão')),
          ListTile(leading: const Icon(Icons.flag_outlined, color: ppGold), title: const Text('Portugal'), onTap: () => Navigator.pop(context, 'Portugal')),
          ListTile(leading: const Icon(Icons.flag_outlined, color: ppGold), title: const Text('Brasil'), onTap: () => Navigator.pop(context, 'Brasil')),
        ]),
      ),
    );
    if (destination != null) setState(() => _destination = destination);
  }
}

class LaunchDialog extends StatefulWidget {
  const LaunchDialog({super.key});
  @override
  State<LaunchDialog> createState() => _LaunchDialogState();
}

class _LaunchDialogState extends State<LaunchDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF142542),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Transform.translate(
              offset: Offset(_controller.value * 12, -_controller.value * 8),
              child: const AnimatedPlane(width: 115),
            ),
          ),
          const SizedBox(height: 22),
          const Text('A preparar o teu avião...', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('A dobrar a mensagem e preparar o voo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 22),
          const LinearProgressIndicator(color: ppGold, backgroundColor: Colors.white12),
        ]),
      ),
    );
  }
}


String _countryName(String? code) {
  const names = <String, String>{
    'MZ': 'Moçambique', 'JP': 'Japão', 'BR': 'Brasil', 'PT': 'Portugal',
    'ZA': 'África do Sul', 'IN': 'Índia', 'TH': 'Tailândia', 'US': 'Estados Unidos',
    'GB': 'Reino Unido', 'FR': 'França', 'DE': 'Alemanha', 'AO': 'Angola',
    'KE': 'Quénia', 'NG': 'Nigéria', 'CA': 'Canadá', 'AU': 'Austrália',
  };
  if (code == null || code.isEmpty) return 'Outro lugar do mundo';
  return names[code.toUpperCase()] ?? code.toUpperCase();
}

String _countryFlag(String? code) {
  if (code == null || code.length != 2) return '🌍';
  return String.fromCharCodes(code.toUpperCase().codeUnits.map((value) => value + 127397));
}

String _flightTimeLeft(String? arrival) {
  if (arrival == null) return 'A calcular';
  final date = DateTime.tryParse(arrival);
  if (date == null) return 'A calcular';
  final left = date.difference(DateTime.now());
  if (left.isNegative) return 'A concluir';
  final hours = left.inHours;
  final minutes = left.inMinutes.remainder(60);
  if (hours == 0) return minutes.toString() + 'min';
  return hours.toString() + 'h ' + minutes.toString() + 'min';
}

class GlobeFlightPainter extends CustomPainter {
  const GlobeFlightPainter({this.route, this.progress = 0});
  final Map<String, dynamic>? route;
  final double progress;

  Offset? _project(double lat, double lng, double centerLat, double centerLng, Offset center, double radius) {
    const r = math.pi / 180;
    final p = lat * r;
    final l = lng * r;
    final cp = centerLat * r;
    final cl = centerLng * r;
    final delta = l - cl;
    final x = math.cos(p) * math.sin(delta);
    final y = math.sin(p) * math.cos(cp) - math.cos(p) * math.cos(delta) * math.sin(cp);
    final z = math.sin(p) * math.sin(cp) + math.cos(p) * math.cos(delta) * math.cos(cp);
    if (z < -0.025) return null;
    return Offset(center.dx + x * radius, center.dy - y * radius);
  }

  List<double> _midpoint(Map<String, dynamic> origin, Map<String, dynamic> destination) {
    const r = math.pi / 180;
    List<double> vector(Map<String, dynamic> point) {
      final lat = (point['lat'] as num).toDouble() * r;
      final lng = (point['lng'] as num).toDouble() * r;
      return [math.cos(lat) * math.cos(lng), math.cos(lat) * math.sin(lng), math.sin(lat)];
    }
    final a = vector(origin), b = vector(destination);
    final x = a[0] + b[0], y = a[1] + b[1], z = a[2] + b[2];
    return [
      math.atan2(z, math.sqrt(x * x + y * y)) / r,
      math.atan2(y, x) / r,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width * 0.44, size.height * 0.43).toDouble();
    final origin = route?['origin'];
    final destination = route?['destination'];
    final midpoint = origin is Map && destination is Map
        ? _midpoint(Map<String, dynamic>.from(origin), Map<String, dynamic>.from(destination))
        : <double>[0, 0];
    final centerLat = midpoint[0], centerLng = midpoint[1];
    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.42),
          radius: 1.1,
          colors: [Color(0xFF1B3B65), Color(0xFF0B1C35), Color(0xFF030914)],
          stops: [0, 0.56, 1],
        ).createShader(sphereRect),
    );
    canvas.drawCircle(center, radius, Paint()
      ..color = ppGold.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    canvas.save();
    canvas.clipPath(Path()..addOval(sphereRect));

    final gridPaint = Paint()
      ..color = const Color(0xFF6D8CB8).withOpacity(0.23)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var factor = -0.75; factor <= 0.75; factor += 0.25) {
      final y = center.dy + radius * factor;
      final rx = radius * math.sqrt(1 - factor * factor);
      canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, y), width: rx * 2, height: radius * 0.12), gridPaint);
    }
    canvas.drawOval(Rect.fromCenter(center: center, width: radius * 0.72, height: radius * 2), gridPaint);
    canvas.drawOval(Rect.fromCenter(center: center, width: radius * 1.45, height: radius * 2), gridPaint);

    final raw = route?['points'];
    final points = raw is List
        ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    if (points.isNotEmpty) {
      final path = Path();
      Offset? previous;
      for (final point in points) {
        final projected = _project(
          (point['lat'] as num).toDouble(),
          (point['lng'] as num).toDouble(),
          centerLat, centerLng, center, radius * 0.985,
        );
        if (projected == null) {
          previous = null;
          continue;
        }
        if (previous == null) {
          path.moveTo(projected.dx, projected.dy);
        } else {
          path.lineTo(projected.dx, projected.dy);
        }
        previous = projected;
      }
      canvas.drawPath(path, Paint()
        ..color = ppGold.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawPath(path, Paint()
        ..color = ppGoldBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round);

      final scaled = progress.clamp(0.0, 1.0).toDouble() * (points.length - 1);
      final index = math.min(points.length - 2, scaled.floor());
      if (points.length > 1) {
        final fraction = scaled - index;
        final first = points[index], second = points[index + 1];
        final lat1 = (first['lat'] as num).toDouble();
        final lng1 = (first['lng'] as num).toDouble();
        final lat2 = (second['lat'] as num).toDouble();
        final lng2 = (second['lng'] as num).toDouble();
        final marker = _project(
          lat1 + (lat2 - lat1) * fraction,
          lng1 + (lng2 - lng1) * fraction,
          centerLat, centerLng, center, radius * 0.985,
        );
        if (marker != null) {
          canvas.drawCircle(marker, 9, Paint()
            ..color = ppGold.withOpacity(0.24)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
          canvas.drawCircle(marker, 4.2, Paint()..color = Colors.white);
          canvas.drawCircle(marker, 2.3, Paint()..color = ppGold);
        }
      }
      if (origin is Map) {
        final p = _project((origin['lat'] as num).toDouble(), (origin['lng'] as num).toDouble(), centerLat, centerLng, center, radius * 0.985);
        if (p != null) canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF8DE0AF));
      }
      if (destination is Map) {
        final p = _project((destination['lat'] as num).toDouble(), (destination['lng'] as num).toDouble(), centerLat, centerLng, center, radius * 0.985);
        if (p != null) canvas.drawCircle(p, 4, Paint()..color = ppGoldBright);
      }
    } else {
      canvas.drawCircle(center, radius * 0.28, Paint()
        ..color = ppGold.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GlobeFlightPainter oldDelegate) =>
      oldDelegate.route != route || oldDelegate.progress != progress;
}

class FlightScreen extends StatefulWidget {
  const FlightScreen({super.key, required this.airplaneId});
  final String airplaneId;

  @override
  State<FlightScreen> createState() => _FlightScreenState();
}

class _FlightScreenState extends State<FlightScreen> {
  Map<String, dynamic>? _flight;
  String? _error;
  bool _loading = true;
  Timer? _poller;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _flight != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final response = await PaperPlaneApi.instance.getAirplaneFlight(widget.airplaneId);
      if (!mounted) return;
      setState(() {
        _flight = response['flight'] as Map<String, dynamic>?;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is PaperPlaneApiException ? error.message : 'Não foi possível atualizar o voo pela internet.';
        _loading = false;
      });
    }
  }

  double get _progress {
    final flight = _flight;
    if (flight == null) return 0;
    final status = flight['status']?.toString() ?? '';
    if (['DELIVERED', 'READ', 'RESPONDED'].contains(status)) return 1;
    final started = DateTime.tryParse(flight['startedAt']?.toString() ?? '');
    final arrival = DateTime.tryParse(flight['estimatedArrivalAt']?.toString() ?? '');
    if (started == null || arrival == null || !arrival.isAfter(started)) {
      return ((flight['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0).toDouble();
    }
    return (DateTime.now().difference(started).inMilliseconds /
        arrival.difference(started).inMilliseconds).clamp(0.0, 0.999).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final flight = _flight;
    final status = flight?['status']?.toString() ?? 'QUEUED';
    final searching = flight?['searching'] == true || status == 'QUEUED';
    final route = flight?['route'] is Map ? Map<String, dynamic>.from(flight!['route'] as Map) : null;
    final distance = (flight?['distanceKm'] as num?)?.toInt();
    final travelled = distance == null ? null : (distance * _progress).round();
    final destinationCode = route?['destinationCountry']?.toString();

    return ScreenFrame(
      title: 'O teu avião está a voar',
      action: IconButton(onPressed: _refresh, tooltip: 'Atualizar voo', icon: const Icon(Icons.refresh_rounded, color: ppGoldBright)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          const SizedBox(height: 5),
          Text(
            _loading ? 'A contactar o servidor…' : searching
                ? 'À procura de alguém para receber a tua carta'
                : status == 'FLYING'
                    ? 'Em rota para ' + _countryName(destinationCode)
                    : ['DELIVERED', 'READ', 'RESPONDED'].contains(status)
                        ? 'O avião chegou ao destino'
                        : status == 'HELD_REVIEW' ? 'Em revisão de segurança' : 'Estado: ' + status,
            style: const TextStyle(color: ppGoldBright, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            padding: const EdgeInsets.all(10),
            highlight: true,
            child: SizedBox(
              height: 290,
              child: CustomPaint(
                painter: GlobeFlightPainter(route: route, progress: _progress),
                child: Center(
                  child: route == null
                      ? Icon(Icons.public_rounded, size: 44, color: ppGold.withOpacity(0.65))
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: ppGold)))
          else if (_error != null)
            GlassPanel(
              child: Column(children: [
                const Icon(Icons.cloud_off_outlined, color: Colors.orangeAccent, size: 30),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
              ]),
            )
          else if (searching)
            GlassPanel(
              highlight: true,
              child: Column(children: [
                const Icon(Icons.radar_rounded, color: ppGoldBright, size: 34),
                const SizedBox(height: 7),
                const Text('O avião continua à procura de um destinatário elegível.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('A procura é feita pelo servidor. Quando encontrar alguém, a rota, a distância e a previsão de chegada serão registadas aqui.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.45)),
                const SizedBox(height: 10),
                const LinearProgressIndicator(color: ppGold, backgroundColor: Colors.white12),
              ]),
            )
          else if (['FLYING', 'DELIVERED', 'READ', 'RESPONDED'].contains(status))
            GlassPanel(
              child: Column(children: [
                Row(children: [
                  Expanded(child: _flightMetric('DISTÂNCIA PERCORRIDA', travelled == null ? '—' : travelled.toString() + ' km', Icons.route_rounded)),
                  Container(width: 1, height: 66, color: Colors.white24),
                  Expanded(child: _flightMetric('DISTÂNCIA TOTAL', distance == null ? '—' : distance.toString() + ' km', Icons.public_rounded)),
                ]),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(minHeight: 13, value: _progress, backgroundColor: Colors.white12, color: ppGoldBright),
                ),
                const SizedBox(height: 9),
                Row(children: [
                  Text((_progress * 100).round().toString() + '% percorrido', style: const TextStyle(color: ppGoldBright, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(status == 'FLYING' ? 'Chegada em ' + _flightTimeLeft(flight?['estimatedArrivalAt']?.toString()) : 'Chegada confirmada', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ]),
            ),
          const SizedBox(height: 10),
          if (route != null)
            GlassPanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Percurso do avião', style: TextStyle(color: ppGoldBright, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(children: [
                  Text(_countryFlag(route['originCountry']?.toString()), style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 9),
                  Expanded(child: Text(_countryName(route['originCountry']?.toString()))),
                  const Icon(Icons.flight_takeoff_rounded, color: ppGold),
                ]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 7), child: Divider(color: Colors.white12)),
                Row(children: [
                  Text(_countryFlag(route['destinationCountry']?.toString()), style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 9),
                  Expanded(child: Text(_countryName(route['destinationCountry']?.toString()))),
                  const Icon(Icons.location_on_outlined, color: ppGold),
                ]),
              ]),
            ),
          if (status == 'HELD_REVIEW')
            const GlassPanel(child: Text('A mensagem está retida para revisão de segurança. Não será entregue até a revisão terminar.', style: TextStyle(color: Colors.white70))),
          if (['DELIVERED', 'READ', 'RESPONDED'].contains(status))
            const GlassPanel(child: Text('Entrega registada no servidor. O estado da carta será atualizado quando o destinatário a abrir ou responder.', style: TextStyle(color: Colors.white70))),
          const SizedBox(height: 14),
          const Text('O globo mostra uma rota digital calculada entre centros geográficos aproximados dos países. Não é localização GPS nem rastreamento de aeronaves físicas.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.45)),
          const SizedBox(height: 14),
          SoftButton(label: 'Voltar ao início', icon: Icons.home_outlined, onPressed: () => Navigator.popUntil(context, (route) => route.isFirst)),
        ],
      ),
    );
  }

  Widget _flightMetric(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: ppGoldBright),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      Text(value, style: const TextStyle(color: ppGoldBright, fontSize: 21, fontWeight: FontWeight.w800)),
    ]),
  );
}


class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<Map<String, dynamic>> _received = [];
  List<Map<String, dynamic>> _sent = [];
  bool _loading = true;
  String? _error;

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      await PaperPlaneAuth.ensureAnonymousPilot();
      final results = await Future.wait([
        PaperPlaneApi.instance.getInbox(),
        PaperPlaneApi.instance.getSentPlanes(),
      ]);
      final received = (results[0]['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      final sent = (results[1]['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() {
        _received = received;
        _sent = sent;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException ? error.message : 'Não foi possível carregar os aviões pela internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: ppGold,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 21, 20, 24),
        children: [
          const Text('A tua caixa', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Correio sincronizado com o servidor', style: TextStyle(color: Colors.white70)),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator(color: ppGold)),
            )
          else if (_error != null)
            GlassPanel(
              child: Column(children: [
                const Icon(Icons.cloud_off_outlined, color: Colors.orangeAccent, size: 32),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
              ]),
            )
          else ...[
            const SectionTitle('Recebidos'),
            if (_received.isEmpty)
              const GlassPanel(child: Text('Ainda não recebeste aviões. Quando uma carta chegar, aparecerá aqui.', style: TextStyle(color: Colors.white70)))
            else
              for (final plane in _received) ...[
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(19),
                  onTap: () => ppPush(context, IncomingPlaneScreen(
                    airplaneId: plane['id']?.toString() ?? '',
                    countryCode: plane['sender_country_code']?.toString(),
                  )),
                  child: GlassPanel(
                    highlight: plane['status'] == 'DELIVERED',
                    child: Row(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(color: ppBlue.withOpacity(0.35), borderRadius: BorderRadius.circular(15)),
                        child: const Icon(Icons.mark_email_unread_outlined, color: ppGoldBright, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Alguém em ' + _countryName(plane['sender_country_code']?.toString()), style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Uma carta selada chegou até ti.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(plane['status'] == 'READ' ? 'Já aberta' : 'Nova carta', style: const TextStyle(color: ppGold, fontSize: 11)),
                      ])),
                      const Icon(Icons.chevron_right, color: ppGold),
                    ]),
                  ),
                ),
              ],
            const SectionTitle('A sair'),
            if (_sent.isEmpty)
              const GlassPanel(child: Text('Ainda não lançaste nenhum avião.', style: TextStyle(color: Colors.white70)))
            else
              for (final plane in _sent) ...[
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => ppPush(context, FlightScreen(airplaneId: plane['id'].toString())),
                  child: GlassPanel(
                    child: Row(children: [
                      const Icon(Icons.flight_takeoff_rounded, color: ppGoldBright, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          plane['status'] == 'QUEUED'
                              ? 'À procura de destinatário'
                              : plane['status'] == 'FLYING'
                                  ? 'Em voo · ' + (plane['flight_distance_km']?.toString() ?? 'a calcular') + ' km'
                                  : plane['status']?.toString() ?? 'Estado desconhecido',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text('Lançado ' + (plane['created_at']?.toString() ?? ''), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ])),
                      const Icon(Icons.chevron_right, color: ppGold),
                    ]),
                  ),
                ),
              ],
          ],
          const SizedBox(height: 12),
          const Text('Puxa para baixo para sincronizar os aviões e os seus estados.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class IncomingPlaneScreen extends StatefulWidget {
  const IncomingPlaneScreen({super.key, required this.airplaneId, this.countryCode});
  final String airplaneId;
  final String? countryCode;

  @override
  State<IncomingPlaneScreen> createState() => _IncomingPlaneScreenState();
}

class _IncomingPlaneScreenState extends State<IncomingPlaneScreen> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final result = await PaperPlaneApi.instance.openIncomingPlane(widget.airplaneId);
      final plane = result['airplane'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (plane == null) throw const PaperPlaneApiException('NOT_FOUND', 'Esta carta já não está disponível.');
      ppPush(context, LetterScreen(airplane: plane));
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível abrir a carta.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _release() async {
    setState(() => _busy = true);
    try {
      await PaperPlaneApi.instance.releasePlane(widget.airplaneId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O avião foi libertado.')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível libertar este avião.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportOrBlock({required bool block}) async {
    setState(() => _busy = true);
    try {
      if (block) {
        await PaperPlaneApi.instance.blockSenderOfPlane(widget.airplaneId);
      } else {
        await PaperPlaneApi.instance.reportPlane(widget.airplaneId, reason: 'INAPPROPRIATE');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(block ? 'Remetente bloqueado.' : 'Denúncia enviada para análise.')));
      if (block) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível concluir esta ação.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Avião recebido',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
        child: Column(children: [
          const Spacer(),
          const Icon(Icons.mark_email_unread_rounded, color: ppGoldBright, size: 125),
          const SizedBox(height: 25),
          const Text('Recebeste um novo avião', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('De: Alguém em ' + _countryName(widget.countryCode) + ' ' + _countryFlag(widget.countryCode), style: const TextStyle(color: ppGoldBright, fontSize: 16)),
          const SizedBox(height: 22),
          const GlassPanel(child: Row(children: [
            Icon(Icons.lock_outline_rounded, color: ppGold, size: 31),
            SizedBox(width: 13),
            Expanded(child: Text('Mensagem selada · Abre quando estiveres pronto.', style: TextStyle(color: Colors.white70))),
          ])),
          const Spacer(),
          GoldButton(label: _busy ? 'A abrir…' : 'Abrir devagar', icon: Icons.mail_outline, onPressed: _busy ? () {} : _open),
          const SizedBox(height: 12),
          SoftButton(label: 'Libertar avião', icon: Icons.air_rounded, onPressed: _busy ? () {} : _release),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton.icon(onPressed: _busy ? null : () => _reportOrBlock(block: false), icon: const Icon(Icons.flag_outlined, color: Colors.white54), label: const Text('Denunciar', style: TextStyle(color: Colors.white54))),
            TextButton.icon(onPressed: _busy ? null : () => _reportOrBlock(block: true), icon: const Icon(Icons.block_rounded, color: Colors.white54), label: const Text('Bloquear', style: TextStyle(color: Colors.white54))),
          ]),
        ]),
      ),
    );
  }
}

class LetterScreen extends StatefulWidget {
  const LetterScreen({super.key, required this.airplane});
  final Map<String, dynamic> airplane;

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {
  final TextEditingController _reply = TextEditingController();
  bool _busy = false;
  bool _hearted = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final message = _reply.text.trim();
    if (message.isEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await PaperPlaneApi.instance.replyToPlane(
        widget.airplane['id'].toString(),
        message: message,
        language: 'pt',
        allowReply: true,
      );
      final plane = result['airplane'] as Map<String, dynamic>? ?? const {};
      final id = plane['id']?.toString();
      if (!mounted) return;
      if (id == null || id.isEmpty) throw const PaperPlaneApiException('REPLY_NOT_CREATED', 'A resposta não foi criada.');
      ppPush(context, FlightScreen(airplaneId: id));
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível enviar a resposta.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendHeart() async {
    if (_hearted || _busy) return;
    setState(() => _busy = true);
    try {
      await PaperPlaneApi.instance.sendHeart(widget.airplane['id'].toString());
      if (!mounted) return;
      setState(() => _hearted = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coração enviado.')));
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível enviar o coração.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report() async {
    try {
      await PaperPlaneApi.instance.reportPlane(widget.airplane['id'].toString(), reason: 'INAPPROPRIATE');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Denúncia enviada para análise.')));
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível enviar a denúncia.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final country = widget.airplane['sender_country_code']?.toString();
    final message = widget.airplane['message_text']?.toString() ?? '';
    final replyValue = widget.airplane['allow_reply'];
    final allowReply = replyValue == 1 || replyValue == true;
    return ScreenFrame(
      title: 'Mensagem',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(19, 10, 19, 25),
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            decoration: BoxDecoration(
              color: ppPaper,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [BoxShadow(color: ppGold.withOpacity(0.16), blurRadius: 19)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('De: Alguém em ' + _countryName(country) + ' ' + _countryFlag(country), style: const TextStyle(color: Color(0xFF82745A), fontSize: 13)),
              const SizedBox(height: 24),
              Text(message, style: const TextStyle(color: ppInk, fontSize: 22, height: 1.6, fontStyle: FontStyle.italic)),
              const SizedBox(height: 22),
              Text('Recebido · ' + (widget.airplane['delivered_at']?.toString() ?? ''), style: const TextStyle(color: Color(0xFF82745A), fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 18),
          if (allowReply) ...[
            const SectionTitle('Responder com outro avião'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF142541), borderRadius: BorderRadius.circular(18), border: Border.all(color: ppGold.withOpacity(0.28))),
              child: TextField(
                controller: _reply,
                maxLength: 200,
                maxLines: 4,
                minLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Escreve uma resposta gentil…', border: InputBorder.none, counterStyle: TextStyle(color: Colors.white54)),
              ),
            ),
            const SizedBox(height: 12),
            GoldButton(label: _busy ? 'A enviar…' : 'Responder com avião', icon: Icons.send_rounded, onPressed: _busy ? () {} : _sendReply),
            const SizedBox(height: 10),
          ] else
            const GlassPanel(child: Text('O remetente desativou as respostas para esta carta.', style: TextStyle(color: Colors.white70))),
          SoftButton(
            label: _hearted ? 'Coração enviado' : 'Enviar coração',
            icon: _hearted ? Icons.favorite : Icons.favorite_border,
            onPressed: _busy || _hearted ? () {} : _sendHeart,
          ),
          const SizedBox(height: 8),
          Center(child: TextButton.icon(onPressed: _report, icon: const Icon(Icons.shield_outlined, color: Colors.white54), label: const Text('Denunciar mensagem', style: TextStyle(color: Colors.white54)))),
        ],
      ),
    );
  }
}


class OpenSkyPage extends StatefulWidget {
  const OpenSkyPage({super.key});

  @override
  State<OpenSkyPage> createState() => _OpenSkyPageState();
}

class _OpenSkyPageState extends State<OpenSkyPage> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      await PaperPlaneAuth.ensureAnonymousPilot();
      final result = await PaperPlaneApi.instance.getOpenSky();
      final messages = (result['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() { _messages = messages; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException ? error.message : 'Não foi possível contactar o Open Sky.';
      });
    }
  }

  Future<void> _like(String id) async {
    try {
      await PaperPlaneApi.instance.likeOpenSkyMessage(id);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível enviar o coração.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showReplies(String id) async {
    try {
      final result = await PaperPlaneApi.instance.getPublicReplies(id);
      final items = (result['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      final controller = TextEditingController();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF142541),
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, MediaQuery.of(sheetContext).viewInsets.bottom + 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Respostas públicas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('Ainda não há respostas.', style: TextStyle(color: Colors.white70))
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text(item['message_text']?.toString() ?? '', style: const TextStyle(color: Colors.white70)),
                ),
            const Divider(color: Colors.white24),
            TextField(
              controller: controller,
              maxLength: 200,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'Escreve uma resposta…'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                try {
                  await PaperPlaneApi.instance.addPublicReply(id, text);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resposta enviada para publicação.')));
                    _refresh();
                  }
                } catch (error) {
                  if (sheetContext.mounted) {
                    final message = error is PaperPlaneApiException ? error.message : 'Não foi possível responder.';
                    ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text(message)));
                  }
                }
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar resposta'),
            ),
          ]),
        ),
      );
      controller.dispose();
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível carregar as respostas.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: ppGold,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text('Open Sky', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Mensagens públicas que chegaram ao céu', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: ppGold)))
          else if (_error != null)
            GlassPanel(
              child: Column(children: [
                const Icon(Icons.cloud_off_outlined, color: Colors.orangeAccent, size: 34),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
              ]),
            )
          else if (_messages.isEmpty)
            const GlassPanel(child: Text('O céu público ainda está vazio. Quando uma mensagem pública for aprovada e publicada, aparecerá aqui.', style: TextStyle(color: Colors.white70, height: 1.45)))
          else
            for (final message in _messages) ...[
              const SizedBox(height: 11),
              GlassPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(_countryFlag(message['sender_country_code']?.toString()), style: const TextStyle(fontSize: 25)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_countryName(message['sender_country_code']?.toString()), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    Text(message['created_at']?.toString() ?? '', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ]),
                  const SizedBox(height: 12),
                  Text(message['message_text']?.toString() ?? '', style: const TextStyle(fontSize: 15, height: 1.45)),
                  const SizedBox(height: 12),
                  Row(children: [
                    TextButton.icon(
                      onPressed: () => _like(message['id'].toString()),
                      icon: const Icon(Icons.favorite_border, color: ppGold, size: 18),
                      label: Text((message['likes_count'] ?? 0).toString()),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showReplies(message['id'].toString()),
                      icon: const Icon(Icons.chat_bubble_outline, size: 17),
                      label: Text('Responder (' + (message['replies_count'] ?? 0).toString() + ')'),
                    ),
                  ]),
                ]),
              ),
            ],
        ],
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label),
        backgroundColor: ppBlue.withOpacity(0.38),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
        labelStyle: const TextStyle(color: Colors.white),
      );
}


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _profile = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      await PaperPlaneAuth.ensureAnonymousPilot();
      final result = await PaperPlaneApi.instance.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException ? error.message : 'Não foi possível carregar o perfil online.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pilot = _profile['pilot'] as Map<String, dynamic>? ?? const {};
    final stats = _profile['stats'] as Map<String, dynamic>? ?? const {};
    final complete = pilot['profile_completed'] == 1;
    final name = pilot['pilot_name']?.toString() ?? 'Piloto';
    final handle = pilot['pilot_handle']?.toString();
    final country = pilot['country_code']?.toString();
    final sent = int.tryParse(stats['sent']?.toString() ?? '') ?? 0;
    final received = int.tryParse(stats['received']?.toString() ?? '') ?? 0;

    return RefreshIndicator(
      color: ppGold,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        children: [
          Row(children: [
            const Expanded(child: Text('Perfil & Conta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => ppPush(context, const SettingsScreen()), icon: const Icon(Icons.settings_outlined, color: ppGold)),
          ]),
          if (_loading)
            const Padding(padding: EdgeInsets.all(38), child: Center(child: CircularProgressIndicator(color: ppGold)))
          else if (_error != null)
            GlassPanel(
              child: Column(children: [
                const Icon(Icons.cloud_off_outlined, color: Colors.orangeAccent, size: 30),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 9),
                OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
              ]),
            )
          else ...[
            GlassPanel(
              highlight: true,
              child: Row(children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ppBlue.withOpacity(0.38), border: Border.all(color: ppGold.withOpacity(0.45))),
                  child: const Icon(Icons.flight_outlined, color: ppGoldBright, size: 42),
                ),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  if (handle != null) Text('@' + handle, style: const TextStyle(color: ppGoldBright)),
                  const SizedBox(height: 4),
                  Text(country == null ? 'País não definido' : _countryFlag(country) + ' ' + _countryName(country), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(complete ? 'Perfil sincronizado' : 'Perfil por completar', style: TextStyle(color: complete ? const Color(0xFF8DE0AF) : ppGold, fontSize: 11)),
                ])),
              ]),
            ),
            if (!complete) ...[
              const SizedBox(height: 12),
              GoldButton(
                label: 'Completar perfil de copiloto',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const PilotProfileSetupScreen()),
                  );
                  if (result == true) _refresh();
                },
              ),
            ],
            const SectionTitle('Resumo da conta'),
            GlassPanel(
              child: Row(children: [
                Expanded(child: _ProfileNumber(number: sent.toString(), label: 'Aviões enviados')),
                Container(width: 1, height: 55, color: Colors.white24),
                Expanded(child: _ProfileNumber(number: received.toString(), label: 'Aviões recebidos')),
              ]),
            ),
            const SectionTitle('Conta e preferências'),
            _ProfileLink(icon: Icons.manage_accounts_outlined, title: 'A minha conta', subtitle: 'Google · Email e palavra-passe', onTap: () => ppPush(context, const AccountScreen())),
            _ProfileLink(icon: Icons.translate, title: 'Idioma', subtitle: 'Português · English', onTap: () => ppPush(context, const SettingsScreen())),
            _ProfileLink(icon: Icons.shield_outlined, title: 'Segurança e privacidade', subtitle: 'Bloqueios, denúncias e controlos', onTap: () => ppPush(context, const SafetyScreen())),
            _ProfileLink(icon: Icons.help_outline, title: 'Ajuda e suporte', subtitle: 'Informações sobre o Paper Plane', onTap: () => showAboutDialog(context: context, applicationName: 'Paper Plane', applicationVersion: '0.1.0')),
          ],
          const SizedBox(height: 10),
          const Text('Os dados do perfil e os totais são obtidos no servidor Paper Plane.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ProfileNumber extends StatelessWidget {
  const _ProfileNumber({required this.number, required this.label});
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(number, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ppGoldBright)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
  ]);
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(children: [
          Icon(icon, color: ppGoldBright, size: 25),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ]),
      ),
    ),
  );
}


class ChamaScreen extends StatelessWidget {
  const ChamaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Chama do Deserto',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 17, 12),
            child: GlassPanel(
              highlight: true,
              child: Row(children: [
                const CircleAvatar(
                  radius: 27,
                  backgroundColor: Color(0xFF344C77),
                  child: Icon(Icons.person_rounded, color: ppGoldBright, size: 31),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Piloto associado', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('Ligação privada de demonstração', style: TextStyle(color: Colors.white60, fontSize: 11)),
                ])),
                const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFA15A), size: 29),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: GlassPanel(
              color: const Color(0xFF263D66),
              child: const Row(children: [
                Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFAA65), size: 30),
                SizedBox(width: 10),
                Expanded(child: Text('Uma chama precisa de respeito, cuidado e consentimento dos dois pilotos.', style: TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: const [
                _FlameBubble(text: 'Olá! Como está o teu dia? Espero que o deserto esteja mais calmo hoje ✨', time: 'ontem · 22:12', mine: false),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text('A conversa só continua com a escolha livre dos dois.', textAlign: TextAlign.center, style: TextStyle(color: ppGoldBright, fontSize: 11)),
                  ),
                ),
                _FlameBubble(text: 'Consegui ver as estrelas aqui esta noite. Foi muito bonito!', time: 'hoje · 09:34', mine: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 15, 17),
            child: GlassPanel(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Text('Pré-visualização — mensagens privadas ainda desativadas.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: 'Enviar mensagem em papel...',
                        filled: true,
                        fillColor: Color(0x3310182A),
                        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(18))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(onPressed: null, icon: const Icon(Icons.send_rounded, color: ppGold)),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  children: [
                    TextButton.icon(onPressed: () => showReportDialog(context), icon: const Icon(Icons.flag_outlined), label: const Text('Denunciar')),
                    TextButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O bloqueio será ligado à conta.'))), icon: const Icon(Icons.shield_outlined), label: const Text('Bloquear')),
                    TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded), label: const Text('Sair')),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlameBubble extends StatelessWidget {
  const _FlameBubble({required this.text, required this.time, required this.mine});
  final String text;
  final String time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF385C9A) : const Color(0xFF1A2B49),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
          const SizedBox(height: 6),
          Text(time, style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
      ),
    );
  }
}

class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Convidar e partilhar',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
        children: [
          const SizedBox(height: 8),
          const Center(child: PlaneMark(width: 120)),
          const SizedBox(height: 20),
          const Text('Convida amigos para voar', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Partilha o teu convite e espalha palavras gentis.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          GlassPanel(
            highlight: true,
            child: Column(children: [
              const Text('O teu link de convite', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 9),
              Row(children: [
                const Expanded(child: SelectableText('paperplane.app/invite/P7X9K2', style: TextStyle(color: ppGoldBright, fontWeight: FontWeight.w700))),
                IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O link será disponibilizado após configurar os convites.'))),
                  icon: const Icon(Icons.copy_rounded, color: ppGold),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 22),
          Center(
            child: GlassPanel(
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: 155,
                height: 155,
                child: CustomPaint(painter: QrPlaceholderPainter()),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const Text('Código QR de convite (pré-visualização)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 22),
          GoldButton(label: 'Partilhar convite', icon: Icons.ios_share_rounded, onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A partilha será ligada quando o link estiver ativo.')))),
          const SizedBox(height: 12),
          SoftButton(label: 'Copiar link', icon: Icons.copy_rounded, onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link de demonstração — ainda não ativo.')))),
          const SizedBox(height: 15),
          const Text('Os convites e recompensas serão ativados após a configuração da conta e do servidor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

class QrPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 21;
    final bg = Paint()..color = Colors.white;
    final dark = Paint()..color = const Color(0xFF13203A);
    canvas.drawRect(Offset.zero & size, bg);
    final random = math.Random(42);
    for (var y = 0; y < 21; y++) {
      for (var x = 0; x < 21; x++) {
        final inFinder = _finder(x, y, 0, 0) || _finder(x, y, 14, 0) || _finder(x, y, 0, 14);
        if (inFinder) continue;
        if (random.nextBool()) canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
      }
    }
    _drawFinder(canvas, cell, 0, 0, dark, bg);
    _drawFinder(canvas, cell, 14, 0, dark, bg);
    _drawFinder(canvas, cell, 0, 14, dark, bg);
  }

  bool _finder(int x, int y, int fx, int fy) => x >= fx && x < fx + 7 && y >= fy && y < fy + 7;

  void _drawFinder(Canvas canvas, double cell, int x, int y, Paint dark, Paint bg) {
    canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, 7 * cell, 7 * cell), dark);
    canvas.drawRect(Rect.fromLTWH((x + 1) * cell, (y + 1) * cell, 5 * cell, 5 * cell), bg);
    canvas.drawRect(Rect.fromLTWH((x + 2) * cell, (y + 2) * cell, 3 * cell, 3 * cell), dark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'A minha coleção',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Row(children: const [
            Expanded(child: _CollectionStat(value: '128', label: 'Voos totais')),
            SizedBox(width: 9),
            Expanded(child: _CollectionStat(value: '24', label: 'Países')),
            SizedBox(width: 9),
            Expanded(child: _CollectionStat(value: '12 400', label: 'km de voo')),
          ]),
          const SectionTitle('Emblemas'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 0.92,
            children: const [
              _BadgeTile(icon: Icons.military_tech, label: 'Primeiro voo'),
              _BadgeTile(icon: Icons.public, label: 'Viajante do mundo'),
              _BadgeTile(icon: Icons.favorite, label: 'Alma gentil'),
            ],
          ),
          const SectionTitle('Aviões colecionados'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 9,
            crossAxisSpacing: 9,
            childAspectRatio: 0.86,
            children: const [
              _PlaneStamp(flag: '🇯🇵', country: 'Japão'),
              _PlaneStamp(flag: '🇵🇹', country: 'Portugal'),
              _PlaneStamp(flag: '🇧🇷', country: 'Brasil'),
              _PlaneStamp(flag: '🇮🇳', country: 'Índia'),
              _PlaneStamp(flag: '🇮🇹', country: 'Itália'),
              _PlaneStamp(flag: '🇨🇦', country: 'Canadá'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionStat extends StatelessWidget {
  const _CollectionStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 7),
    highlight: true,
    child: Column(children: [
      FittedBox(child: Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: ppGoldBright))),
      const SizedBox(height: 5),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(8),
    highlight: true,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: ppGoldBright, size: 35),
      const SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _PlaneStamp extends StatelessWidget {
  const _PlaneStamp({required this.flag, required this.country});
  final String flag;
  final String country;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(9),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const PlaneMark(width: 40),
      const SizedBox(height: 8),
      Text(flag + ' ' + country, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ]),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = false;
  bool darkMode = true;
  String language = 'Português';

  Future<void> _setNotifications(bool enabled) async {
    if (!enabled) {
      try {
        final serverUpdated = await PaperPlaneNotifications.disableAndUnregister();
        if (!mounted) return;
        setState(() => notifications = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              serverUpdated
                  ? 'Notificações desativadas neste dispositivo.'
                  : 'Notificações desativadas localmente. O servidor ainda precisa de sincronizar esta alteração.',
            ),
          ),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível concluir a desativação das notificações.')),
          );
        }
      }
      return;
    }
    if (!FirebaseRuntime.isInitialized || !PaperPlaneApi.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura Firebase e Cloudflare antes de ativar notificações.')),
      );
      return;
    }
    try {
      await PaperPlaneAuth.ensureAnonymousPilot();
      await PaperPlaneNotifications.enableAndRegister();
      if (mounted) setState(() => notifications = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificações ativadas neste dispositivo.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => notifications = false);
      if (mounted) {
        final message = error is PaperPlaneApiException ? error.message : 'Não foi possível ativar notificações.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Configurações',
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
        const SectionTitle('Preferências'),
        GlassPanel(
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: language,
              decoration: const InputDecoration(labelText: 'Idioma', prefixIcon: Icon(Icons.language, color: ppGold)),
              dropdownColor: const Color(0xFF152541),
              items: const [
                DropdownMenuItem(value: 'Português', child: Text('Português')),
                DropdownMenuItem(value: 'English', child: Text('English')),
              ],
              onChanged: (value) => setState(() => language = value ?? language),
            ),
            const SizedBox(height: 9),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: ppGold,
              title: const Text('Notificações'),
              value: notifications,
              onChanged: _setNotifications,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: ppGold,
              title: const Text('Modo escuro'),
              value: darkMode,
              onChanged: (value) => setState(() => darkMode = value),
            ),
          ]),
        ),
        const SectionTitle('Conta'),
        _ProfileLink(icon: Icons.manage_accounts_outlined, title: 'A minha conta', subtitle: 'Google · Email e palavra-passe', onTap: () => ppPush(context, const AccountScreen())),
        _ProfileLink(icon: Icons.shield_outlined, title: 'Segurança e privacidade', subtitle: 'Bloqueios, denúncias e controlos', onTap: () => ppPush(context, const SafetyScreen())),
        _ProfileLink(icon: Icons.help_outline, title: 'Ajuda e suporte', subtitle: 'Informações sobre o Paper Plane', onTap: () => showAboutDialog(context: context, applicationName: 'Paper Plane', applicationVersion: '0.1.0')),
        const SizedBox(height: 12),
        const Text('As preferências desta versão são locais e ainda não estão sincronizadas com uma conta.', style: TextStyle(color: Colors.white38, fontSize: 11)),
      ]),
    );
  }
}

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Segurança e privacidade',
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
        const GlassPanel(
          highlight: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_moon_outlined, color: ppGoldBright, size: 38),
            SizedBox(height: 12),
            Text('A tua segurança importa', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            SizedBox(height: 7),
            Text('Não partilhes dados pessoais, morada, palavras-passe ou informações que te identifiquem com desconhecidos.', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SectionTitle('Controlos'),
        _ProfileLink(icon: Icons.block, title: 'Pessoas bloqueadas', subtitle: 'A lista ficará disponível com a conta', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A lista de bloqueios será ligada ao servidor.')))),
        _ProfileLink(icon: Icons.flag_outlined, title: 'As minhas denúncias', subtitle: 'Acompanhamento de segurança', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O centro de denúncias será ligado ao servidor.')))),
        _ProfileLink(icon: Icons.visibility_off_outlined, title: 'Privacidade', subtitle: 'Controlar o que outras pessoas veem', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Controlos de privacidade em preparação.')))),
      ]),
    );
  }
}

class WeeklyCountryScreen extends StatelessWidget {
  const WeeklyCountryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'País da semana',
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
        GlassPanel(
          padding: const EdgeInsets.all(24),
          highlight: true,
          child: const Column(children: [
            Text('🇯🇵', style: TextStyle(fontSize: 74)),
            SizedBox(height: 10),
            Text('Japão', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text('Uma viagem de palavras até ao Japão', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 15),
        GlassPanel(
          color: const Color(0xFF6D5325).withOpacity(0.42),
          child: const Row(children: [
            Icon(Icons.star_rounded, color: ppGoldBright, size: 35),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bónus especial', style: TextStyle(color: ppGoldBright, fontWeight: FontWeight.w900)),
              Text('Recompensas temáticas serão ativadas numa fase futura.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),
        const SectionTitle('Mensagens do país'),
        const _SimpleMessage(country: 'Tóquio, Japão', flag: '🇯🇵', text: 'Que a tua noite seja tranquila e cheia de pequenas descobertas.'),
        const SizedBox(height: 10),
        const _SimpleMessage(country: 'Quioto, Japão', flag: '🇯🇵', text: 'Mesmo uma pequena palavra pode iluminar o dia de alguém.'),
        const SizedBox(height: 15),
        GoldButton(label: 'Escrever avião', icon: Icons.send_rounded, onPressed: () => ppPush(context, const WritePlaneScreen())),
      ]),
    );
  }
}

class _SimpleMessage extends StatelessWidget {
  const _SimpleMessage({required this.country, required this.flag, required this.text});
  final String country;
  final String flag;
  final String text;

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(flag + '  ' + country, style: const TextStyle(color: ppGoldBright, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(text, style: const TextStyle(height: 1.5)),
    ]),
  );
}

Future<void> showReportDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF172844),
      title: const Text('Denunciar mensagem'),
      content: const Text('A ferramenta de denúncias será ligada ao sistema de segurança. Não respondas a mensagens que te deixem desconfortável.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
    ),
  );
}
