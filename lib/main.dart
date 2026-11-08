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
import 'screens/first_flight_workshop_screen.dart';
import 'screens/support_screen.dart';
import 'screens/chat_hub_screen.dart';
import 'screens/quiz_screen.dart';
import 'widgets/report_dialog.dart';

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
  await PaperPlaneNotifications.initializeMessageHandlers();
  await PaperPlaneAnalytics.initialize();
  runApp(const PaperPlaneApp());
}

class PaperPlaneApp extends StatelessWidget {
  const PaperPlaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: PaperPlaneNotifications.scaffoldMessengerKey,
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
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'AccountEntry'),
        pageBuilder: (_, __, ___) => AccountScreen(
          onAuthenticated: (firstFlightId) {
            navigator.pushReplacement(
              PageRouteBuilder(
                settings: const RouteSettings(name: 'MainShell'),
                pageBuilder: (_, __, ___) => MainShell(initialFlightId: firstFlightId),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 650),
              ),
            );
          },
        ),
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
  const MainShell({super.key, this.initialFlightId});
  final String? initialFlightId;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    PaperPlaneNotifications.onOpenInbox = _openInboxFromNotification;
    PaperPlaneNotifications.onOpenPlane = _openPlaneFromNotification;
    PaperPlaneNotifications.onOpenChat = _openChatFromNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pendingAirplaneId = PaperPlaneNotifications.consumePendingPlaneOpen();
      if (pendingAirplaneId != null) {
        _openPlaneFromNotification(pendingAirplaneId);
      } else if (PaperPlaneNotifications.consumePendingChatOpen()) {
        _openChatFromNotification();
      } else if (PaperPlaneNotifications.consumePendingInboxOpen()) {
        _openInboxFromNotification();
      }
      final firstFlightId = widget.initialFlightId;
      if (firstFlightId != null && firstFlightId.isNotEmpty) {
        ppPush(context, FlightScreen(airplaneId: firstFlightId));
      }
    });
  }

  void _openInboxFromNotification() {
    if (mounted) setState(() => _index = 1);
  }

  void _openChatFromNotification() {
    if (mounted) setState(() => _index = 3);
  }

  Future<void> _openPlaneFromNotification(String airplaneId) async {
    if (!mounted || airplaneId.isEmpty) return;
    setState(() => _index = 1);
    String? senderCountry;
    try {
      final response = await PaperPlaneApi.instance.getInbox();
      final items = (response['items'] as List<dynamic>? ?? const [])
          .whereType<Map>();
      for (final item in items) {
        if (item['id']?.toString() == airplaneId) {
          senderCountry = item['sender_country_code']?.toString();
          break;
        }
      }
    } catch (_) {
      // The inbox tab remains available if the network is temporarily unavailable.
    }
    if (!mounted) return;
    ppPush(
      context,
      IncomingPlaneScreen(
        airplaneId: airplaneId,
        countryCode: senderCountry,
      ),
    );
  }

  @override
  void dispose() {
    PaperPlaneNotifications.onOpenInbox = null;
    PaperPlaneNotifications.onOpenPlane = null;
    PaperPlaneNotifications.onOpenChat = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onWrite: () => ppPush(context, const WritePlaneScreen()), onOpenInbox: () => setState(() => _index = 1)),
      const InboxPage(),
      const OpenSkyPage(),
      const ChatHubScreen(),
      const QuizScreen(),
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
          child: SizedBox(
            height: 66,
            child: Row(children: [
              _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.inbox_outlined, Icons.inbox_rounded, 'Caixa'),
              _navItem(2, Icons.public_outlined, Icons.public_rounded, 'Open Sky'),
              _navItem(3, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
              _navItem(4, Icons.quiz_outlined, Icons.quiz_rounded, 'Quiz'),
              _navItem(5, Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData selectedIcon, String label) {
    final selected = _index == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = index),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? ppGold.withOpacity(0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: selected ? ppGoldBright : Colors.white70, size: 21),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected ? ppGoldBright : Colors.white60,
                    fontSize: 9.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
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
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _sent = [];
  int _unread = 0;
  String? _firstFlightState;
  Map<String, dynamic> _firstFlight = {};
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
      await PaperPlaneAuth.requireSignedInPilot();
      final results = await Future.wait([
        PaperPlaneApi.instance.getProfile(),
        PaperPlaneApi.instance.getSentPlanes(),
        PaperPlaneApi.instance.getInbox(),
      ]);
      final pilot = results[0]['pilot'] as Map<String, dynamic>? ?? {};
      final stats = results[0]['stats'] as Map<String, dynamic>? ?? {};
      final sent = (results[1]['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      final inbox = (results[2]['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() {
        _profile = pilot;
        _stats = stats;
        _sent = sent;
        _unread = inbox.where((item) => item['status'] == 'DELIVERED').length;
        _firstFlightState = results[0]['firstFlightState']?.toString();
        _firstFlight = results[0]['firstFlight'] as Map<String, dynamic>? ?? {};
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

  Future<void> _launchSavedFirstFlight() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => FirstFlightWorkshopScreen(
          initialMessage: _firstFlight['message']?.toString() ?? '',
          initialPlaneModel: _firstFlight['planeModel']?.toString() ?? 'DART',
        ),
      ),
    );
    if (result?['completed'] == true) {
      final airplaneId = result?['airplaneId']?.toString();
      await _refresh();
      if (mounted && airplaneId != null && airplaneId.isNotEmpty) {
        ppPush(context, FlightScreen(airplaneId: airplaneId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile['pilot_name']?.toString();
    final handle = _profile['pilot_handle']?.toString();
    final received = int.tryParse(_stats['received']?.toString() ?? '') ?? 0;
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
            if (_firstFlightState == 'READY_TO_LAUNCH')
              GlassPanel(
                highlight: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.flight_takeoff_rounded, color: ppGoldBright, size: 26),
                    SizedBox(width: 10),
                    Expanded(child: Text('O teu primeiro avião está pronto', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  ]),
                  const SizedBox(height: 6),
                  const Text('O teu primeiro avião está guardado no servidor e pronto para a viagem. Retoma a oficina para rever o desenho e lança-o quando estiveres preparado.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
                  const SizedBox(height: 12),
                  GoldButton(
                    label: 'Lançar o primeiro avião',
                    icon: Icons.rocket_launch_rounded,
                    onPressed: _launchSavedFirstFlight,
                    height: 54,
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
      await PaperPlaneAuth.requireSignedInPilot();
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
    'TZ': 'Tanzânia', 'ZW': 'Zimbabué', 'ZM': 'Zâmbia', 'MW': 'Maláui',
    'BW': 'Botsuana', 'NA': 'Namíbia', 'LS': 'Lesoto', 'SZ': 'Essuatíni',
    'EG': 'Egito', 'MA': 'Marrocos', 'DZ': 'Argélia', 'TN': 'Tunísia',
    'ET': 'Etiópia', 'UG': 'Uganda', 'RW': 'Ruanda', 'CD': 'RD Congo',
    'CG': 'Congo', 'CM': 'Camarões', 'GH': 'Gana', 'CI': 'Costa do Marfim',
    'SN': 'Senegal', 'CV': 'Cabo Verde', 'ES': 'Espanha', 'IT': 'Itália',
    'NL': 'Países Baixos', 'BE': 'Bélgica', 'CH': 'Suíça', 'AT': 'Áustria',
    'SE': 'Suécia', 'NO': 'Noruega', 'FI': 'Finlândia', 'PL': 'Polónia',
    'GR': 'Grécia', 'TR': 'Turquia', 'RU': 'Rússia', 'CN': 'China',
    'KR': 'Coreia do Sul', 'ID': 'Indonésia', 'MY': 'Malásia', 'SG': 'Singapura',
    'VN': 'Vietname', 'PH': 'Filipinas', 'PK': 'Paquistão', 'BD': 'Bangladesh',
    'NP': 'Nepal', 'SA': 'Arábia Saudita', 'AE': 'Emirados Árabes Unidos',
    'MX': 'México', 'AR': 'Argentina', 'CL': 'Chile', 'CO': 'Colômbia',
    'PE': 'Peru', 'VE': 'Venezuela', 'EC': 'Equador', 'UY': 'Uruguai',
    'NZ': 'Nova Zelândia', 'IE': 'Irlanda', 'IS': 'Islândia',
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


class AnimatedSkyFlight extends StatefulWidget {
  const AnimatedSkyFlight({super.key});
  @override
  State<AnimatedSkyFlight> createState() => _AnimatedSkyFlightState();
}

class _AnimatedSkyFlightState extends State<AnimatedSkyFlight> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _SkyFlightPainter(progress: _controller.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SkyFlightPainter extends CustomPainter {
  const _SkyFlightPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(20)),
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF142C4B), Color(0xFF071225)],
      ).createShader(bounds),
    );

    final random = math.Random(41);
    for (var i = 0; i < 44; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = 0.16 + random.nextDouble() * 0.45;
      canvas.drawCircle(
        Offset(x, y),
        0.5 + random.nextDouble() * 1.1,
        Paint()..color = (i % 9 == 0 ? ppGoldBright : Colors.white).withOpacity(opacity),
      );
    }

    final path = Path()
      ..moveTo(size.width * 0.07, size.height * 0.78)
      ..cubicTo(
        size.width * 0.28, size.height * 0.08,
        size.width * 0.58, size.height * 0.98,
        size.width * 0.91, size.height * 0.22,
      );
    final metric = path.computeMetrics().first;
    final trail = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(trail, Paint()
      ..color = ppGold.withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(trail, Paint()
      ..color = ppGoldBright.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round);

    final tangent = metric.getTangentForOffset(metric.length * progress);
    if (tangent != null) {
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(tangent.angle + math.pi / 2);
      final plane = Path()
        ..moveTo(0, -15)
        ..lineTo(8, 10)
        ..lineTo(0, 6)
        ..lineTo(-8, 10)
        ..close();
      canvas.drawPath(plane, Paint()
        ..color = ppGold.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawPath(plane, Paint()..color = ppPaper);
      canvas.drawPath(plane, Paint()..color = ppGoldBright..style = PaintingStyle.stroke..strokeWidth = 1.2);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SkyFlightPainter oldDelegate) => oldDelegate.progress != progress;
}

class AnimatedGlobeFlight extends StatefulWidget {
  const AnimatedGlobeFlight({
    super.key,
    required this.route,
    required this.progress,
  });

  final Map<String, dynamic>? route;
  final double progress;

  @override
  State<AnimatedGlobeFlight> createState() => _AnimatedGlobeFlightState();
}

class _AnimatedGlobeFlightState extends State<AnimatedGlobeFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) => CustomPaint(
        painter: GlobeFlightPainter(
          route: widget.route,
          progress: widget.progress,
          rotation: math.sin(_motion.value * math.pi * 2) * 5.0,
          pulse: (math.sin(_motion.value * math.pi * 2 * 1.4) + 1) / 2,
        ),
        child: child,
      ),
      child: Center(
        child: widget.route == null
            ? Icon(Icons.public_rounded, size: 44, color: ppGold.withOpacity(0.65))
            : const SizedBox.shrink(),
      ),
    );
  }
}

class GlobeFlightPainter extends CustomPainter {
  const GlobeFlightPainter({
    this.route,
    this.progress = 0,
    this.rotation = 0,
    this.pulse = 0,
  });

  final Map<String, dynamic>? route;
  final double progress;
  final double rotation;
  final double pulse;

  // Simplified Natural-Earth-style silhouettes, stored as longitude/latitude.
  // The globe is an illustrative world map, not a GPS map or country-boundary database.
  static const List<List<Offset>> _continents = [
    [
      Offset(-168, 70), Offset(-150, 72), Offset(-137, 61), Offset(-130, 53),
      Offset(-124, 48), Offset(-124, 40), Offset(-117, 32), Offset(-107, 27),
      Offset(-98, 20), Offset(-90, 16), Offset(-83, 9), Offset(-78, 18),
      Offset(-66, 45), Offset(-55, 52), Offset(-62, 61), Offset(-84, 70),
      Offset(-113, 74), Offset(-142, 72),
    ],
    [
      Offset(-81, 12), Offset(-71, 10), Offset(-62, 7), Offset(-51, -1),
      Offset(-45, -13), Offset(-49, -24), Offset(-58, -36), Offset(-67, -55),
      Offset(-74, -49), Offset(-78, -28), Offset(-80, -7),
    ],
    [
      Offset(-18, 35), Offset(-5, 37), Offset(10, 36), Offset(26, 32),
      Offset(34, 22), Offset(43, 11), Offset(50, -12), Offset(40, -34),
      Offset(20, -35), Offset(8, -28), Offset(-1, -12), Offset(-11, 4),
      Offset(-17, 20),
    ],
    [
      Offset(-10, 36), Offset(-4, 44), Offset(8, 48), Offset(15, 56),
      Offset(28, 61), Offset(42, 56), Offset(55, 62), Offset(72, 70),
      Offset(96, 75), Offset(121, 70), Offset(143, 58), Offset(150, 48),
      Offset(137, 39), Offset(124, 32), Offset(116, 22), Offset(104, 8),
      Offset(91, 7), Offset(80, 18), Offset(68, 24), Offset(56, 25),
      Offset(45, 40), Offset(31, 37), Offset(20, 42), Offset(8, 37),
    ],
    [
      Offset(68, 26), Offset(79, 29), Offset(89, 24), Offset(91, 17),
      Offset(84, 7), Offset(78, 8), Offset(73, 17),
    ],
    [
      Offset(112, -11), Offset(128, -10), Offset(145, -17), Offset(154, -28),
      Offset(146, -39), Offset(132, -44), Offset(116, -35), Offset(112, -22),
    ],
    [
      Offset(-52, 82), Offset(-30, 82), Offset(-20, 75), Offset(-40, 60),
      Offset(-54, 60), Offset(-64, 70),
    ],
    [
      Offset(45, -13), Offset(50, -15), Offset(49, -25), Offset(43, -25),
      Offset(40, -18),
    ],
    [
      Offset(95, 6), Offset(108, 8), Offset(119, 3), Offset(124, -5),
      Offset(116, -9), Offset(105, -7),
    ],
  ];

  Offset? _project(
    double lat,
    double lng,
    double centerLat,
    double centerLng,
    Offset center,
    double radius,
  ) {
    const radians = math.pi / 180;
    final latitude = lat * radians;
    final longitude = lng * radians;
    final centerLatitude = centerLat * radians;
    final centerLongitude = centerLng * radians;
    final delta = longitude - centerLongitude;
    final x = math.cos(latitude) * math.sin(delta);
    final y = math.sin(latitude) * math.cos(centerLatitude) -
        math.cos(latitude) * math.cos(delta) * math.sin(centerLatitude);
    final z = math.sin(latitude) * math.sin(centerLatitude) +
        math.cos(latitude) * math.cos(delta) * math.cos(centerLatitude);
    if (z < -0.02) return null;
    return Offset(center.dx + x * radius, center.dy - y * radius);
  }

  double _visibilityDepth(
    Offset point,
    double centerLat,
    double centerLng,
  ) {
    const radians = math.pi / 180;
    final latitude = point.dy * radians;
    final longitude = point.dx * radians;
    final centerLatitude = centerLat * radians;
    final centerLongitude = centerLng * radians;
    final delta = longitude - centerLongitude;
    return math.sin(latitude) * math.sin(centerLatitude) +
        math.cos(latitude) * math.cos(delta) * math.cos(centerLatitude);
  }

  Offset _horizonIntersection(
    Offset first,
    Offset second,
    double centerLat,
    double centerLng,
  ) {
    var low = 0.0;
    var high = 1.0;
    final firstVisible = _visibilityDepth(first, centerLat, centerLng) >= 0;
    for (var i = 0; i < 18; i++) {
      final middle = (low + high) / 2;
      final candidate = Offset(
        first.dx + (second.dx - first.dx) * middle,
        first.dy + (second.dy - first.dy) * middle,
      );
      final candidateVisible = _visibilityDepth(candidate, centerLat, centerLng) >= 0;
      if (candidateVisible == firstVisible) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final t = (low + high) / 2;
    return Offset(
      first.dx + (second.dx - first.dx) * t,
      first.dy + (second.dy - first.dy) * t,
    );
  }

  List<double> _midpoint(Map<String, dynamic> origin, Map<String, dynamic> destination) {
    const radians = math.pi / 180;
    List<double> vector(Map<String, dynamic> point) {
      final lat = (point['lat'] as num).toDouble() * radians;
      final lng = (point['lng'] as num).toDouble() * radians;
      return [math.cos(lat) * math.cos(lng), math.cos(lat) * math.sin(lng), math.sin(lat)];
    }
    final a = vector(origin);
    final b = vector(destination);
    final x = a[0] + b[0];
    final y = a[1] + b[1];
    final z = a[2] + b[2];
    return [
      math.atan2(z, math.sqrt(x * x + y * y)) / radians,
      math.atan2(y, x) / radians,
    ];
  }

  void _drawLand(
    Canvas canvas,
    List<Offset> polygon,
    double centerLat,
    double centerLng,
    Offset center,
    double radius,
  ) {
    if (polygon.length < 3) return;
    final visibleOutline = <Offset>[];
    for (var i = 0; i < polygon.length; i++) {
      final first = polygon[i];
      final second = polygon[(i + 1) % polygon.length];
      final firstVisible = _visibilityDepth(first, centerLat, centerLng) >= 0;
      final secondVisible = _visibilityDepth(second, centerLat, centerLng) >= 0;
      if (firstVisible) visibleOutline.add(first);
      if (firstVisible != secondVisible) {
        visibleOutline.add(_horizonIntersection(first, second, centerLat, centerLng));
      }
    }
    if (visibleOutline.length < 3) return;
    final projected = <Offset>[];
    for (final point in visibleOutline) {
      final value = _project(point.dy, point.dx, centerLat, centerLng, center, radius);
      if (value != null) projected.add(value);
    }
    if (projected.length < 3) return;
    final path = Path()..moveTo(projected.first.dx, projected.first.dy);
    for (final point in projected.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF24516A).withOpacity(0.78),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF7CA9B8).withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85,
    );
  }

  void _drawLocation(
    Canvas canvas,
    String? code,
    Map<String, dynamic>? point,
    double centerLat,
    double centerLng,
    Offset center,
    double radius,
    Color markerColor,
    bool destination, {
    String? countryName,
  }) {
    if (point == null || point['lat'] is! num || point['lng'] is! num) return;
    final marker = _project(
      (point['lat'] as num).toDouble(),
      (point['lng'] as num).toDouble(),
      centerLat,
      centerLng,
      center,
      radius,
    );
    if (marker == null) return;

    if (destination) {
      final wave = 7 + pulse * 9;
      canvas.drawCircle(
        marker,
        wave,
        Paint()
          ..color = markerColor.withOpacity(0.28 * (1 - pulse * 0.45))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      canvas.drawCircle(
        marker,
        13 + pulse * 4,
        Paint()
          ..color = markerColor.withOpacity(0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    } else {
      canvas.drawCircle(
        marker,
        9,
        Paint()
          ..color = markerColor.withOpacity(0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawCircle(marker, 4.2, Paint()..color = markerColor);
    canvas.drawCircle(
      marker,
      4.2,
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (code != null && code.isNotEmpty) {
      final label = _countryFlag(code) + ' ' + (countryName?.trim().isNotEmpty == true ? countryName! : _countryName(code));
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFFF5F0E4),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 112);
      final left = (marker.dx + 7).clamp(4.0, math.max(4.0, center.dx * 2 - textPainter.width - 14)).toDouble();
      final top = (marker.dy - 17).clamp(3.0, math.max(3.0, center.dy * 2 - 22)).toDouble();
      final labelRect = Rect.fromLTWH(
        left,
        top,
        textPainter.width + 10,
        textPainter.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(7)),
        Paint()..color = const Color(0xE6102038),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(7)),
        Paint()
          ..color = markerColor.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      textPainter.paint(canvas, Offset(left + 5, top + 3));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width * 0.46, size.height * 0.43).toDouble();
    final origin = route?['origin'];
    final destination = route?['destination'];
    final originMap = origin is Map ? Map<String, dynamic>.from(origin) : null;
    final destinationMap = destination is Map ? Map<String, dynamic>.from(destination) : null;
    final midpoint = originMap != null && destinationMap != null
        ? _midpoint(originMap, destinationMap)
        : <double>[0, 0];
    final centerLat = midpoint[0];
    final centerLng = midpoint[1] + rotation;
    final sphereRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius + 8,
      Paint()
        ..color = const Color(0xFF5F9BB8).withOpacity(0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.34, -0.42),
          radius: 1.05,
          colors: [
            Color(0xFF1B5277),
            Color(0xFF0D2947),
            Color(0xFF04101F),
          ],
          stops: [0, 0.58, 1],
        ).createShader(sphereRect),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(sphereRect));

    final gridPaint = Paint()
      ..color = const Color(0xFF8CB2C6).withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var factor = -0.75; factor <= 0.75; factor += 0.25) {
      final y = center.dy + radius * factor;
      final rx = radius * math.sqrt(1 - factor * factor);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, y),
          width: rx * 2,
          height: radius * 0.12,
        ),
        gridPaint,
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 0.72, height: radius * 2),
      gridPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 1.45, height: radius * 2),
      gridPaint,
    );

    for (final continent in _continents) {
      _drawLand(canvas, continent, centerLat, centerLng, center, radius * 0.99);
    }

    final raw = route?['points'];
    final points = raw is List
        ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    final routePath = Path();
    var pathStarted = false;
    for (final point in points) {
      if (point['lat'] is! num || point['lng'] is! num) continue;
      final projected = _project(
        (point['lat'] as num).toDouble(),
        (point['lng'] as num).toDouble(),
        centerLat,
        centerLng,
        center,
        radius * 0.99,
      );
      if (projected == null) {
        pathStarted = false;
        continue;
      }
      if (!pathStarted) {
        routePath.moveTo(projected.dx, projected.dy);
        pathStarted = true;
      } else {
        routePath.lineTo(projected.dx, projected.dy);
      }
    }

    for (final metric in routePath.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length),
        Paint()
          ..color = ppGold.withOpacity(0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawPath(
        metric.extractPath(0, metric.length),
        Paint()
          ..color = const Color(0xFF9ABBD0).withOpacity(0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
      final completedLength = metric.length * progress.clamp(0.0, 1.0);
      if (completedLength > 0) {
        final completed = metric.extractPath(0, completedLength);
        canvas.drawPath(
          completed,
          Paint()
            ..color = ppGold.withOpacity(0.38)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawPath(
          completed,
          Paint()
            ..color = ppGoldBright
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    Offset? currentMarker;
    if (points.length > 1) {
      final scaled = progress.clamp(0.0, 1.0) * (points.length - 1);
      final index = math.min(points.length - 2, scaled.floor());
      final fraction = scaled - index;
      final first = points[index];
      final second = points[index + 1];
      if (first['lat'] is num && first['lng'] is num &&
          second['lat'] is num && second['lng'] is num) {
        final lat1 = (first['lat'] as num).toDouble();
        final lng1 = (first['lng'] as num).toDouble();
        final lat2 = (second['lat'] as num).toDouble();
        final lng2 = (second['lng'] as num).toDouble();
        currentMarker = _project(
          lat1 + (lat2 - lat1) * fraction,
          lng1 + (lng2 - lng1) * fraction,
          centerLat,
          centerLng,
          center,
          radius * 0.99,
        );
        final before = _project(lat1, lng1, centerLat, centerLng, center, radius * 0.99);
        final after = _project(lat2, lng2, centerLat, centerLng, center, radius * 0.99);
        if (currentMarker != null) {
          final heading = before != null && after != null
              ? math.atan2(after.dy - before.dy, after.dx - before.dx)
              : 0.0;
          canvas.drawCircle(
            currentMarker,
            17,
            Paint()
              ..color = ppGold.withOpacity(0.22)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
          canvas.save();
          canvas.translate(currentMarker.dx, currentMarker.dy);
          canvas.rotate(heading + math.pi / 2);
          final plane = Path()
            ..moveTo(0, -13)
            ..lineTo(7, 10)
            ..lineTo(0, 6)
            ..lineTo(-7, 10)
            ..close();
          canvas.drawPath(
            plane,
            Paint()
              ..color = ppGold.withOpacity(0.32)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          canvas.drawPath(plane, Paint()..color = ppPaper);
          canvas.drawPath(
            plane,
            Paint()
              ..color = ppGoldBright
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..strokeJoin = StrokeJoin.round,
          );
          canvas.restore();
        }
      }
    }

    if (originMap != null) {
      _drawLocation(
        canvas,
        route?['originCountry']?.toString(),
        originMap,
        centerLat,
        centerLng,
        center,
        radius * 0.99,
        const Color(0xFF79DBBA),
        false,
        countryName: route?['originName']?.toString(),
      );
    }
    if (destinationMap != null) {
      _drawLocation(
        canvas,
        route?['destinationCountry']?.toString(),
        destinationMap,
        centerLat,
        centerLng,
        center,
        radius * 0.99,
        const Color(0xFFFF5C72),
        true,
        countryName: route?['destinationName']?.toString(),
      );
    }

    if (currentMarker == null && points.isEmpty) {
      canvas.drawCircle(
        center,
        radius * 0.28,
        Paint()
          ..color = ppGold.withOpacity(0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }

    canvas.restore();
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF9BC5D8).withOpacity(0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 3),
      -math.pi * 0.84,
      math.pi * 0.42,
      false,
      Paint()
        ..color = ppGold.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant GlobeFlightPainter oldDelegate) =>
      oldDelegate.route != route ||
      oldDelegate.progress != progress ||
      oldDelegate.rotation != rotation ||
      oldDelegate.pulse != pulse;
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
    final destinationName = route?['destinationName']?.toString();
    final originName = route?['originName']?.toString();

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
                    ? 'Em rota para ' + (destinationName?.trim().isNotEmpty == true ? destinationName! : _countryName(destinationCode))
                    : ['DELIVERED', 'READ', 'RESPONDED'].contains(status)
                        ? 'O avião chegou ao destino'
                        : status == 'HELD_REVIEW' ? 'Em revisão de segurança' : 'Estado: ' + status,
            style: const TextStyle(color: ppGoldBright, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(height: 142, child: AnimatedSkyFlight()),
          ),
          const SizedBox(height: 10),
          GlassPanel(
            padding: const EdgeInsets.all(10),
            highlight: true,
            child: SizedBox(
              height: 340,
              child: AnimatedGlobeFlight(
                route: route,
                progress: _progress,
              ),
            ),
          ),
          if (route != null) ...[
            const SizedBox(height: 10),
            GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('PARTIDA', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    _countryFlag(route['originCountry']?.toString()) + ' ' + (originName?.trim().isNotEmpty == true ? originName! : _countryName(route['originCountry']?.toString())),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ])),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.flight_rounded, color: ppGoldBright, size: 22),
                ),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('DESTINO LOCALIZADO', style: TextStyle(color: Color(0xFFFF8393), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                  const SizedBox(height: 4),
                  Text(
                    _countryFlag(route['destinationCountry']?.toString()) + ' ' + (destinationName?.trim().isNotEmpty == true ? destinationName! : _countryName(route['destinationCountry']?.toString())),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ])),
              ]),
            ),
          ],
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
          const Text('O globo mostra uma rota digital estimada entre os centros geográficos dos países. O avião acompanha o progresso guardado pelo servidor; não usa GPS nem representa a posição de uma aeronave física.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.45)),
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
      await PaperPlaneAuth.requireSignedInPilot();
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

class _IncomingPlaneScreenState extends State<IncomingPlaneScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _scene = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _scene.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final result = await PaperPlaneApi.instance.openIncomingPlane(widget.airplaneId);
      final plane = result['airplane'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (plane == null) throw const PaperPlaneApiException('NOT_FOUND', 'Esta carta já não está disponível.');
      ppPush(context, ArrivalExperienceScreen(airplane: plane));
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
    if (!block) {
      await showReportDialog(context, widget.airplaneId);
      return;
    }
    setState(() => _busy = true);
    try {
      await PaperPlaneApi.instance.blockSenderOfPlane(widget.airplaneId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remetente bloqueado. Não receberás novas correspondências desta conta.')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException ? error.message : 'Não foi possível bloquear este remetente.';
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
          AnimatedBuilder(
            animation: _scene,
            builder: (_, __) => SizedBox(
              height: 300,
              width: double.infinity,
              child: CustomPaint(
                painter: _IncomingPlanePainter(progress: _scene.value),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          SoftButton(label: 'Libertar avião', icon: Icons.airplanemode_active_rounded, onPressed: _busy ? () {} : _release),
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


class _IncomingPlanePainter extends CustomPainter {
  const _IncomingPlanePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(24)),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 0.95,
          colors: [Color(0xFF153C68), Color(0xFF091A31), Color(0xFF040B17)],
        ).createShader(bounds),
    );

    final random = math.Random(37);
    for (var i = 0; i < 62; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final twinkle = 0.22 + 0.55 * (0.5 + 0.5 * math.sin(progress * math.pi * 2 + i));
      canvas.drawCircle(
        Offset(x, y),
        0.45 + random.nextDouble() * 1.15,
        Paint()..color = (i % 8 == 0 ? ppGoldBright : Colors.white).withOpacity(twinkle),
      );
    }

    // Golden arrival stream and drifting confetti.
    final trail = Path()
      ..moveTo(size.width * 0.18, size.height * 0.39)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.04,
        size.width * 0.58,
        size.height * 0.34,
        size.width * 0.56,
        size.height * 0.48,
      );
    canvas.drawPath(
      trail,
      Paint()
        ..color = ppGold.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      trail,
      Paint()
        ..color = ppGoldBright.withOpacity(0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < 24; i++) {
      final x = (i * 0.61803398875 % 1) * size.width;
      final y = ((i * 0.371 + progress * 0.52) % 1) * size.height;
      final rotation = progress * math.pi * 2 + i;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final confetti = Rect.fromCenter(
        center: Offset.zero,
        width: 2.2 + (i % 3),
        height: 6 + (i % 4) * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(confetti, const Radius.circular(1)),
        Paint()..color = (i.isEven ? ppGoldBright : const Color(0xFF9CCBFF)).withOpacity(0.36),
      );
      canvas.restore();
    }

    // Sealed envelope, with a softly lit paper surface.
    final envelope = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.70),
      width: size.width * 0.72,
      height: size.height * 0.37,
    );
    final shadowRect = envelope.inflate(5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(16)),
      Paint()
        ..color = ppGold.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(envelope, const Radius.circular(13)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF6), Color(0xFFE6E0D3), Color(0xFFCFC7B7)],
        ).createShader(envelope),
    );

    final leftFold = Path()
      ..moveTo(envelope.left, envelope.top + 2)
      ..lineTo(envelope.center.dx, envelope.center.dy + 12)
      ..lineTo(envelope.left, envelope.bottom - 2)
      ..close();
    final rightFold = Path()
      ..moveTo(envelope.right, envelope.top + 2)
      ..lineTo(envelope.center.dx, envelope.center.dy + 12)
      ..lineTo(envelope.right, envelope.bottom - 2)
      ..close();
    final lowerFold = Path()
      ..moveTo(envelope.left + 2, envelope.bottom - 2)
      ..lineTo(envelope.center.dx, envelope.center.dy - 2)
      ..lineTo(envelope.right - 2, envelope.bottom - 2)
      ..close();
    final flap = Path()
      ..moveTo(envelope.left + 2, envelope.top + 3)
      ..lineTo(envelope.center.dx, envelope.center.dy + 19)
      ..lineTo(envelope.right - 2, envelope.top + 3)
      ..close();

    canvas.drawPath(leftFold, Paint()..color = const Color(0xFFD7D0C2).withOpacity(0.78));
    canvas.drawPath(rightFold, Paint()..color = const Color(0xFFEAE5D9).withOpacity(0.9));
    canvas.drawPath(lowerFold, Paint()..color = const Color(0xFFF6F1E6).withOpacity(0.9));
    canvas.drawPath(
      flap,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFEF8), Color(0xFFE7E0D1)],
        ).createShader(envelope),
    );
    canvas.drawPath(
      flap,
      Paint()
        ..color = const Color(0xFFB8AD98).withOpacity(0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final seal = Offset(envelope.center.dx, envelope.center.dy + 16);
    canvas.drawCircle(
      seal,
      19,
      Paint()
        ..color = ppGold.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      seal,
      14,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFE9A5), Color(0xFFB87926), Color(0xFF70451D)],
        ).createShader(Rect.fromCircle(center: seal, radius: 14)),
    );
    canvas.drawCircle(
      seal,
      14,
      Paint()
        ..color = const Color(0xFFFFE7A8).withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(seal.translate(-4, -4), 3, Paint()..color = Colors.white.withOpacity(0.35));

    // The paper plane gently hovers above the envelope.
    final bob = math.sin(progress * math.pi * 2) * 5;
    final planeCenter = Offset(size.width * 0.57, size.height * 0.32 + bob);
    canvas.drawCircle(
      planeCenter,
      33,
      Paint()
        ..color = ppGold.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 19),
    );
    canvas.save();
    canvas.translate(planeCenter.dx, planeCenter.dy);
    canvas.rotate(-0.16 + math.sin(progress * math.pi * 2) * 0.025);
    final plane = Path()
      ..moveTo(0, -36)
      ..lineTo(42, 18)
      ..lineTo(4, 8)
      ..lineTo(-13, 31)
      ..lineTo(-8, 3)
      ..lineTo(-31, 14)
      ..close();
    final fold = Path()
      ..moveTo(-8, 3)
      ..lineTo(0, -36)
      ..lineTo(4, 8)
      ..close();
    canvas.drawPath(
      plane,
      Paint()
        ..color = ppGold.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      plane,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFEF8), Color(0xFFD8D1C5)],
        ).createShader(const Rect.fromLTWH(-32, -36, 75, 70)),
    );
    canvas.drawPath(fold, Paint()..color = const Color(0xFFB6AD9D).withOpacity(0.8));
    canvas.drawPath(
      plane,
      Paint()
        ..color = ppGoldBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IncomingPlanePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class ArrivalExperienceScreen extends StatefulWidget {
  const ArrivalExperienceScreen({super.key, required this.airplane});
  final Map<String, dynamic> airplane;

  @override
  State<ArrivalExperienceScreen> createState() => _ArrivalExperienceScreenState();
}

class _ArrivalExperienceScreenState extends State<ArrivalExperienceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'O avião chegou',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 25),
        child: Column(children: [
          const SizedBox(height: 8),
          const Text('Uma carta encontrou o caminho até ti.', textAlign: TextAlign.center, style: TextStyle(color: ppGoldBright, fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 14),
          Expanded(
            child: AnimatedBuilder(
              animation: _arrival,
              builder: (_, __) => CustomPaint(
                painter: _HouseArrivalPainter(progress: _arrival.value),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('O avião pousou à tua porta.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 7),
          const Text('A carta permanece fechada até escolheres abri-la.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _arrival,
            builder: (_, __) => AnimatedOpacity(
              opacity: _arrival.value >= 0.78 ? 1 : 0.35,
              duration: const Duration(milliseconds: 260),
              child: GoldButton(
                label: _arrival.value >= 0.78 ? 'Abrir carta' : 'A chegar à tua porta…',
                icon: Icons.mark_email_read_outlined,
                onPressed: _arrival.value < 0.78
                    ? () {}
                    : () => ppPush(context, LetterScreen(airplane: widget.airplane)),
                height: 62,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HouseArrivalPainter extends CustomPainter {
  const _HouseArrivalPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(22)),
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1D34), Color(0xFF030A15)],
      ).createShader(rect),
    );
    final random = math.Random(77);
    for (var i = 0; i < 65; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.65;
      canvas.drawCircle(Offset(x, y), 0.6 + random.nextDouble(), Paint()
        ..color = Colors.white.withOpacity(0.12 + random.nextDouble() * 0.28));
    }

    final houseWidth = size.width * 0.61;
    final houseHeight = size.height * 0.43;
    final house = Rect.fromCenter(
      center: Offset(size.width * 0.53, size.height * 0.70),
      width: houseWidth,
      height: houseHeight,
    );
    final wall = Path()
      ..moveTo(house.left, house.top + 14)
      ..lineTo(house.right, house.top + 14)
      ..lineTo(house.right, house.bottom)
      ..lineTo(house.left, house.bottom)
      ..close();
    final roof = Path()
      ..moveTo(house.left - 20, house.top + 18)
      ..lineTo(house.center.dx, house.top - houseHeight * 0.48)
      ..lineTo(house.right + 20, house.top + 18)
      ..close();
    canvas.drawPath(wall, Paint()..color = const Color(0xFF243754));
    canvas.drawPath(wall, Paint()..color = ppGold.withOpacity(0.36)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    canvas.drawPath(roof, Paint()..color = const Color(0xFF111C2D));
    canvas.drawPath(roof, Paint()..color = ppGold.withOpacity(0.75)..style = PaintingStyle.stroke..strokeWidth = 2);

    final door = Rect.fromCenter(
      center: Offset(house.center.dx, house.bottom - houseHeight * 0.20),
      width: houseWidth * 0.20,
      height: houseHeight * 0.42,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(door, const Radius.circular(7)), Paint()..color = const Color(0xFF071225));
    final doorGlow = Paint()
      ..color = ppGoldBright.withOpacity(0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(door.center, 19, doorGlow);
    canvas.drawRRect(RRect.fromRectAndRadius(door, const Radius.circular(7)), Paint()..color = const Color(0xFF182B43)..style = PaintingStyle.stroke..strokeWidth = 1.5..color = ppGoldBright.withOpacity(0.8));

    for (final dx in [house.left + houseWidth * 0.19, house.right - houseWidth * 0.19]) {
      final window = Rect.fromCenter(center: Offset(dx, house.top + houseHeight * 0.37), width: houseWidth * 0.19, height: houseHeight * 0.22);
      canvas.drawRRect(RRect.fromRectAndRadius(window, const Radius.circular(4)), Paint()..color = ppGold.withOpacity(0.75));
      canvas.drawRRect(RRect.fromRectAndRadius(window, const Radius.circular(4)), Paint()..color = ppGoldBright.withOpacity(0.9)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }

    final start = Offset(size.width * 0.13, size.height * 0.18);
    final end = Offset(door.center.dx, door.top + 6);
    final control1 = Offset(size.width * 0.65, size.height * 0.08);
    final control2 = Offset(size.width * 0.16, size.height * 0.58);
    final flightPath = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, end.dx, end.dy);
    final metric = flightPath.computeMetrics().first;
    final current = metric.getTangentForOffset(metric.length * progress.clamp(0.0, 1.0));
    if (current != null) {
      final trail = metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));
      canvas.drawPath(trail, Paint()
        ..color = ppGold.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawPath(trail, Paint()
        ..color = ppGoldBright.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round);
      canvas.save();
      canvas.translate(current.position.dx, current.position.dy);
      canvas.rotate(current.angle + math.pi / 2);
      final plane = Path()
        ..moveTo(0, -14)
        ..lineTo(7, 10)
        ..lineTo(0, 6)
        ..lineTo(-7, 10)
        ..close();
      canvas.drawPath(plane, Paint()..color = ppGold.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawPath(plane, Paint()..color = ppPaper);
      canvas.drawPath(plane, Paint()..color = ppGoldBright..style = PaintingStyle.stroke..strokeWidth = 1.2);
      canvas.restore();
    }

    canvas.drawCircle(end, 12 + progress * 9, Paint()
      ..color = ppGold.withOpacity((1 - progress).clamp(0.0, 1.0) * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _HouseArrivalPainter oldDelegate) => oldDelegate.progress != progress;
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
    await showReportDialog(context, widget.airplane['id'].toString());
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
      await PaperPlaneAuth.requireSignedInPilot();
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
                    if (message['is_own'] != 1 && message['is_own'] != true)
                      PopupMenuButton<String>(
                        tooltip: 'Mais opções',
                        icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70),
                        onSelected: (action) async {
                          final airplaneId = message['id'].toString();
                          if (action == 'report') {
                            await showReportDialog(context, airplaneId);
                          } else if (action == 'block') {
                            try {
                              await PaperPlaneApi.instance.blockSenderOfPlane(airplaneId);
                              await _refresh();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Remetente bloqueado.')),
                                );
                              }
                            } catch (error) {
                              if (mounted) {
                                final messageText = error is PaperPlaneApiException
                                    ? error.message
                                    : 'Não foi possível bloquear esta conta.';
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageText)));
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'report', child: Text('Denunciar mensagem')),
                          PopupMenuItem(value: 'block', child: Text('Bloquear remetente')),
                        ],
                      ),
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
      await PaperPlaneAuth.requireSignedInPilot();
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
            const SectionTitle('Explorar o teu percurso'),
            _ProfileLink(
              icon: Icons.public_rounded,
              title: 'Atlas do Céu',
              subtitle: 'Países ligados às tuas cartas e modelos utilizados',
              onTap: () => ppPush(context, const SkyAtlasScreen()),
            ),
            const SectionTitle('Conta e preferências'),
            _ProfileLink(icon: Icons.manage_accounts_outlined, title: 'A minha conta', subtitle: 'Google · Email e palavra-passe', onTap: () => ppPush(context, AccountScreen(onAuthenticated: (_) => Navigator.of(context).pop()))),
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


class SkyAtlasScreen extends StatefulWidget {
  const SkyAtlasScreen({super.key});

  @override
  State<SkyAtlasScreen> createState() => _SkyAtlasScreenState();
}

class _SkyAtlasScreenState extends State<SkyAtlasScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _countries = [];
  Map<String, dynamic> _models = {};
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
      await PaperPlaneAuth.requireSignedInPilot();
      final result = await PaperPlaneApi.instance.getSkyAtlas();
      final countries = (result['countries'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _stats = result['stats'] as Map<String, dynamic>? ?? {};
        _models = (_stats['models'] as Map?)?.cast<String, dynamic>() ?? {};
        _countries = countries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException
            ? error.message
            : 'Não foi possível carregar o Atlas pela internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = int.tryParse(_stats['totalDistanceKm']?.toString() ?? '') ?? 0;
    final totalFlights = int.tryParse(_stats['totalFlights']?.toString() ?? '') ?? 0;
    final completed = int.tryParse(_stats['completedFlights']?.toString() ?? '') ?? 0;
    final active = int.tryParse(_stats['activeFlights']?.toString() ?? '') ?? 0;
    final countryCount = int.tryParse(_stats['countriesCount']?.toString() ?? '') ?? _countries.length;

    return ScreenFrame(
      title: 'Atlas do Céu',
      action: IconButton(
        onPressed: _refresh,
        tooltip: 'Atualizar atlas',
        icon: const Icon(Icons.refresh_rounded, color: ppGoldBright),
      ),
      child: RefreshIndicator(
        color: ppGold,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            const Text(
              'O mundo que as tuas cartas estão a ligar.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 15),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(42),
                child: CircularProgressIndicator(color: ppGold),
              ))
            else if (_error != null)
              GlassPanel(
                child: Column(children: [
                  const Icon(Icons.cloud_off_outlined, color: Colors.orangeAccent, size: 32),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ]),
              )
            else ...[
              GlassPanel(
                highlight: true,
                child: Column(children: [
                  const Icon(Icons.public_rounded, color: ppGoldBright, size: 52),
                  const SizedBox(height: 8),
                  Text(countryCount.toString(), style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: ppGoldBright)),
                  const Text('PAÍSES LIGADOS ÀS TUAS CARTAS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.3)),
                  const SizedBox(height: 17),
                  Row(children: [
                    Expanded(child: _atlasStat('Quilómetros', totalDistance.toString(), Icons.route_rounded)),
                    Container(width: 1, height: 50, color: Colors.white24),
                    Expanded(child: _atlasStat('Voos concluídos', completed.toString(), Icons.mark_email_read_outlined)),
                    Container(width: 1, height: 50, color: Colors.white24),
                    Expanded(child: _atlasStat('Em curso', active.toString(), Icons.flight_takeoff_rounded)),
                  ]),
                ]),
              ),
              const SectionTitle('Países ligados'),
              if (_countries.isEmpty)
                const GlassPanel(
                  child: Column(children: [
                    Icon(Icons.explore_outlined, color: ppGoldBright, size: 34),
                    SizedBox(height: 9),
                    Text('O teu atlas está à espera da primeira rota.', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(height: 5),
                    Text('Quando uma carta encontrar um destinatário e tiver uma rota registada, os países ligados aparecerão aqui.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.45)),
                  ]),
                )
              else
                for (final country in _countries) ...[
                  const SizedBox(height: 8),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Text(_countryFlag(country['code']?.toString()), style: const TextStyle(fontSize: 27)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(country['name']?.toString() ?? _countryName(country['code']?.toString()), style: const TextStyle(fontWeight: FontWeight.w800))),
                      const Icon(Icons.verified_rounded, color: ppGoldBright, size: 19),
                    ]),
                  ),
                ],
              const SectionTitle('Aviões do teu hangar'),
              GlassPanel(
                child: Row(children: [
                  Expanded(child: _modelStat('Dardo', (_models['DART'] ?? 0).toString(), Icons.bolt_rounded)),
                  Expanded(child: _modelStat('Planador', (_models['GLIDER'] ?? 0).toString(), Icons.airplanemode_active_rounded)),
                  Expanded(child: _modelStat('Andorinha', (_models['SWALLOW'] ?? 0).toString(), Icons.airplanemode_active_rounded)),
                ]),
              ),
              const SizedBox(height: 10),
              Text(
                totalFlights == 0
                    ? 'Os dados serão acrescentados quando o servidor registar os teus voos.'
                    : '$totalFlights aviões registados na tua conta.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _atlasStat(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Column(children: [
      Icon(icon, color: ppGoldBright, size: 19),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ppGoldBright)),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white60)),
    ]),
  );

  Widget _modelStat(String title, String value, IconData icon) => Column(children: [
    Icon(icon, color: ppGoldBright, size: 25),
    const SizedBox(height: 5),
    Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
    Text(title, style: const TextStyle(fontSize: 10, color: Colors.white60)),
  ]);
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
                    TextButton.icon(onPressed: () => ppPush(context, const SupportScreen()), icon: const Icon(Icons.support_agent_rounded), label: const Text('Comunicar problema')),
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

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _countries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      await PaperPlaneAuth.requireSignedInPilot();
      final data = await PaperPlaneApi.instance.getSkyAtlas();
      final raw = data['countries'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() {
        _stats = data['stats'] as Map<String, dynamic>? ?? {};
        _countries = raw.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is PaperPlaneApiException ? e.message : 'Não foi possível atualizar a coleção online.';
      });
    }
  }

  int _number(String key) => int.tryParse(_stats[key]?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    final flights = _number('totalFlights');
    final countries = _number('countriesCount');
    final distance = _number('totalDistanceKm');
    final completed = _number('completedFlights');
    final active = _number('activeFlights');

    return ScreenFrame(
      title: 'A minha coleção',
      action: IconButton(
        onPressed: _load,
        tooltip: 'Atualizar coleção',
        icon: const Icon(Icons.refresh_rounded, color: ppGoldBright),
      ),
      child: RefreshIndicator(
        color: ppGold,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator(color: ppGold)),
              )
            else if (_error != null)
              GlassPanel(child: Column(children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 32),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
              ]))
            else ...[
              Row(children: [
                Expanded(child: _CollectionStat(value: flights.toString(), label: 'Voos totais')),
                const SizedBox(width: 9),
                Expanded(child: _CollectionStat(value: countries.toString(), label: 'Países')),
                const SizedBox(width: 9),
                Expanded(child: _CollectionStat(value: distance.toString(), label: 'km de voo')),
              ]),
              const SizedBox(height: 14),
              GlassPanel(
                child: Row(children: [
                  Expanded(child: _collectionMetric('Concluídos', completed, Icons.mark_email_read_outlined)),
                  Expanded(child: _collectionMetric('No ar', active, Icons.flight_takeoff_rounded)),
                ]),
              ),
              const SectionTitle('Emblemas conquistados'),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 0.92,
                children: [
                  _BadgeTile(icon: Icons.military_tech, label: 'Primeiro voo', unlocked: flights >= 1),
                  _BadgeTile(icon: Icons.public, label: 'Viajante do mundo', unlocked: countries >= 3),
                  _BadgeTile(icon: Icons.favorite, label: 'Voo concluído', unlocked: completed >= 1),
                ],
              ),
              const SectionTitle('Países visitados'),
              if (_countries.isEmpty)
                const GlassPanel(
                  child: Text('Ainda não há países registados nos teus voos. Quando uma rota real for concluída, os países aparecem aqui.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.5)),
                )
              else
                for (final country in _countries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Text(_countryFlag(country['code']?.toString()), style: const TextStyle(fontSize: 27)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(country['name']?.toString() ?? 'País', style: const TextStyle(fontWeight: FontWeight.w800))),
                        const Icon(Icons.verified_rounded, color: ppGoldBright, size: 19),
                      ]),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _collectionMetric(String label, int value, IconData icon) => Column(children: [
    Icon(icon, color: ppGoldBright, size: 22),
    const SizedBox(height: 5),
    Text(value.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
  ]);
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
  const _BadgeTile({required this.icon, required this.label, required this.unlocked});
  final IconData icon;
  final String label;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(8),
    highlight: unlocked,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: unlocked ? ppGoldBright : Colors.white24, size: 35),
      const SizedBox(height: 8),
      Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: unlocked ? Colors.white : Colors.white38)),
      const SizedBox(height: 4),
      Text(unlocked ? 'Conquistado' : 'Por conquistar', style: const TextStyle(fontSize: 9, color: Colors.white38)),
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
  bool _loadingNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    if (!FirebaseRuntime.isInitialized || !PaperPlaneApi.isConfigured) {
      if (mounted) setState(() => _loadingNotifications = false);
      return;
    }
    try {
      final result = await PaperPlaneApi.instance.getProfile();
      final pilot = result['pilot'] as Map<String, dynamic>? ?? const {};
      if (mounted) {
        setState(() {
          notifications = pilot['push_enabled'] == 1 || pilot['push_enabled'] == true;
          _loadingNotifications = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNotifications = false);
    }
  }

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
      await PaperPlaneAuth.requireSignedInPilot();
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
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: ppGold,
            title: const Text('Notificações neste dispositivo'),
            subtitle: Text(
              _loadingNotifications
                  ? 'A consultar a preferência da tua conta…'
                  : notifications
                      ? 'Recebe avisos de novos aviões no Android e dentro da aplicação.'
                      : 'Ativa para receber avisos quando um avião chegar.',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            value: notifications,
            onChanged: _loadingNotifications ? null : _setNotifications,
          ),
        ),
        const SectionTitle('Conta'),
        _ProfileLink(icon: Icons.manage_accounts_outlined, title: 'A minha conta', subtitle: 'Google · Email e palavra-passe', onTap: () => ppPush(context, const AccountScreen())),
        _ProfileLink(icon: Icons.shield_outlined, title: 'Segurança e privacidade', subtitle: 'Bloqueios, denúncias e controlos', onTap: () => ppPush(context, const SafetyScreen())),
        _ProfileLink(icon: Icons.help_outline, title: 'Ajuda e suporte', subtitle: 'Comunicar problemas e acompanhar pedidos', onTap: () => ppPush(context, const SupportScreen())),
        const SizedBox(height: 12),
        const Text('As notificações são sincronizadas com a conta e podem ser desativadas a qualquer momento.', style: TextStyle(color: Colors.white38, fontSize: 11)),
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: const [
          GlassPanel(
            highlight: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.shield_moon_outlined, color: ppGoldBright, size: 38),
              SizedBox(height: 12),
              Text('Proteção antes da entrega', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              SizedBox(height: 7),
              Text(
                'A correspondência aleatória usa a faixa etária declarada no perfil para separar grupos. É uma declaração do próprio utilizador, não uma verificação de identidade nem uma prova de idade.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
            ]),
          ),
          SectionTitle('Controlos reais'),
          GlassPanel(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.flag_outlined, color: ppGoldBright),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Denunciar uma carta', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Abre o avião recebido e escolhe Denunciar. A denúncia é enviada ao servidor para revisão.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
          SizedBox(height: 10),
          GlassPanel(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.block_rounded, color: ppGoldBright),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bloquear um remetente', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Abre o avião recebido e escolhe Bloquear. O servidor impede novas correspondências entre as duas contas.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
          SizedBox(height: 10),
          GlassPanel(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.visibility_off_outlined, color: ppGoldBright),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Identidade protegida', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Nas cartas aleatórias, o remetente não recebe o teu nome de conta nem o teu identificador Firebase. O país é a única referência geográfica mostrada nesta versão.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
          SizedBox(height: 14),
          Text(
            'Não partilhes morada, contactos, palavras-passe, escola ou outros dados pessoais com desconhecidos. Se uma carta te fizer sentir desconfortável, não respondas: denuncia e bloqueia.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.45),
          ),
        ],
      ),
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

