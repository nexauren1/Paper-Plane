import 'dart:math';
import 'package:flutter/material.dart';
import '../services/paper_plane_localization.dart';
import '../data/quiz_question_bank.dart';
import '../services/paper_plane_api.dart';

const Color _gold = Color(0xFFF0CE7C);
const Color _lightGold = Color(0xFFFFE7A8);
const Color _panel = Color(0xCC172844);
const Color _mint = Color(0xFF8EE0B1);
const Color _navy = Color(0xFF071225);

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _tab = 0, _index = 0, _score = 0, _streak = 0, _bestStreak = 0;
  String _category = 'Todas';
  List<QuizQuestion> _round = [];
  int? _selected;
  bool _started = false, _finished = false, _loading = true, _saving = false, _saved = false;
  String? _error, _saveError;
  int _xpEarned = 0;
  Map<String, dynamic> _progress = {};

  List<QuizQuestion> get _available => _category == 'Todas'
      ? quizQuestionBank
      : quizQuestionBank.where((q) => q.category == _category).toList();
  List<String> get _categories => [
    'Todas', ...quizQuestionBank.map((q) => q.category).toSet().toList()..sort(),
  ];

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await PaperPlaneApi.instance.getGamification();
      if (mounted) setState(() { _progress = result; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e is PaperPlaneApiException ? e.message : 'Não foi possível sincronizar o progresso.';
      });
    }
  }

  void _start() {
    final pool = List<QuizQuestion>.from(_available)..shuffle(Random());
    setState(() {
      _round = pool.take(10).toList();
      _index = 0; _score = 0; _selected = null; _streak = 0; _bestStreak = 0;
      _started = true; _finished = false; _saving = false; _saved = false;
      _saveError = null; _xpEarned = 0;
    });
  }

  void _answer(int value) {
    if (_selected != null || _finished) return;
    setState(() {
      _selected = value;
      if (value == _round[_index].correctIndex) {
        _score++; _streak++; _bestStreak = max(_bestStreak, _streak);
      } else {
        _streak = 0;
      }
    });
  }

  void _next() {
    if (_selected == null) return;
    if (_index == 9) {
      setState(() => _finished = true);
      _saveResult();
    } else {
      setState(() { _index++; _selected = null; });
    }
  }

  Future<void> _saveResult() async {
    if (_saving || _saved) return;
    setState(() { _saving = true; _saveError = null; });
    try {
      final result = await PaperPlaneApi.instance.recordQuizAttempt(
        category: _category, questionCount: 10, correctCount: _score,
      );
      if (!mounted) return;
      final attempt = result['attempt'] as Map<String, dynamic>? ?? const {};
      setState(() {
        _xpEarned = int.tryParse(attempt['xpAwarded']?.toString() ?? '') ?? 0;
        _progress = result['gamification'] as Map<String, dynamic>? ?? _progress;
        _saved = true; _saving = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _saveError = e is PaperPlaneApiException ? e.message : 'Não foi possível sincronizar os pontos.';
      });
    }
  }

  Future<void> _claim(String key) async {
    try {
      final result = await PaperPlaneApi.instance.claimMission(key);
      if (!mounted) return;
      setState(() => _progress = result['gamification'] as Map<String, dynamic>? ?? _progress);
      final xp = int.tryParse(result['xpAwarded']?.toString() ?? '') ?? 0;
      _notice('Recompensa resgatada: +$xp XP!');
    } catch (e) {
      if (!mounted) return;
      _notice(e is PaperPlaneApiException ? e.message : 'Não foi possível resgatar a missão.');
      _refresh(silent: true);
    }
  }

  void _notice(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: PlaneText(value), behavior: SnackBarBehavior.floating),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 16, 10),
        child: Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: _gold, size: 27),
          const SizedBox(width: 9),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlaneText('Clube do Céu', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            PlaneText('Joga, cumpre missões e sobe de nível', style: TextStyle(color: Colors.white60, fontSize: 11)),
          ])),
          IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded, color: _lightGold)),
        ]),
      ),
      if (!_started) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _tabs()),
      const SizedBox(height: 8),
      Expanded(child: _started ? (_finished ? _result() : _question()) :
        _tab == 0 ? _lobby() : _tab == 1 ? _missions() : _badges()),
    ]));
  }

  Widget _tabs() {
    const labels = ['Jogar', 'Missões', 'Crachás'];
    const icons = [Icons.sports_esports_rounded, Icons.flag_rounded, Icons.workspace_premium_rounded];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
      child: Row(children: List.generate(3, (i) => Expanded(child: InkWell(
        onTap: () => setState(() => _tab = i),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: _tab == i ? _gold.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _tab == i ? _gold.withOpacity(0.7) : Colors.transparent),
          ),
          child: Column(children: [
            Icon(icons[i], size: 17, color: _tab == i ? _lightGold : Colors.white60),
            const SizedBox(height: 3),
            PlaneText(labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _tab == i ? _lightGold : Colors.white60)),
          ]),
        ),
      )))),
    );
  }

  Widget _levelCard() {
    final xp = int.tryParse(_progress['xp']?.toString() ?? '') ?? 0;
    final level = int.tryParse(_progress['level']?.toString() ?? '') ?? 1;
    final next = int.tryParse(_progress['nextLevelXp']?.toString() ?? '') ?? 100;
    final ratio = (_progress['levelProgress'] as num?)?.toDouble() ?? 0;
    final title = _progress['title']?.toString() ?? 'Piloto novato';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF294979), Color(0xFF142640), Color(0xFF101A2B)]),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: _gold.withOpacity(0.48)),
      ),
      child: Row(children: [
        Container(
          width: 62, height: 62, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _gold.withOpacity(0.14), border: Border.all(color: _gold, width: 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            PlaneText('$level', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _lightGold)),
            const PlaneText('NÍVEL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlaneText(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          PlaneText('$xp XP acumulados', style: const TextStyle(color: _lightGold, fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: ratio.clamp(0, 1), minHeight: 7, backgroundColor: Colors.white12, color: _gold)),
          const SizedBox(height: 4),
          PlaneText('Próximo nível: $next XP', style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ])),
      ]),
    );
  }

  Widget _pill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.18), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: _lightGold), const SizedBox(width: 4),
      PlaneText(label, style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _lobby() => ListView(padding: const EdgeInsets.fromLTRB(17, 3, 17, 24), children: [
    _levelCard(),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(21), border: Border.all(color: _gold.withOpacity(0.3))),
      child: Column(children: [
        const Icon(Icons.public_rounded, size: 43, color: _lightGold),
        const SizedBox(height: 9),
        const PlaneText('O mundo é o teu campo de jogo', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        PlaneText(quizQuestionBank.length.toString() + ' perguntas offline, oito áreas de conhecimento e novas rondas aleatórias de dez perguntas.',
          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _pill(Icons.bolt_rounded, 'XP'), _pill(Icons.local_fire_department_rounded, 'Sequências'), _pill(Icons.emoji_events_rounded, 'Crachás'),
        ]),
      ]),
    ),
    const SizedBox(height: 17),
    const PlaneText('Escolhe o teu desafio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    Wrap(spacing: 7, runSpacing: 7, children: _categories.map(_categoryChip).toList()),
    const SizedBox(height: 11),
    PlaneText(_available.length.toString() + ' perguntas disponíveis nesta categoria', style: const TextStyle(color: Colors.white70, fontSize: 11)),
    const SizedBox(height: 15),
    SizedBox(height: 56, child: FilledButton.icon(
      onPressed: _available.length < 10 ? null : _start,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const PlaneText('Começar ronda · 10 perguntas'),
      style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
    )),
    const SizedBox(height: 9),
    const PlaneText('As perguntas funcionam sem Internet. O teu XP e as conquistas sincronizam quando estiveres ligado.',
      textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.4)),
  ]);

  Widget _categoryChip(String value) {
    final selected = _category == value;
    final count = value == 'Todas' ? quizQuestionBank.length : quizQuestionBank.where((q) => q.category == value).length;
    return ChoiceChip(
      selected: selected, onSelected: (_) => setState(() => _category = value),
      label: PlaneText('$value · $count'), selectedColor: _gold, backgroundColor: _panel,
      side: BorderSide(color: selected ? _gold : Colors.white24),
      labelStyle: TextStyle(color: selected ? _navy : Colors.white70, fontSize: 10, fontWeight: FontWeight.w800),
    );
  }

  Widget _question() {
    final q = _round[_index];
    final correct = _selected == q.correctIndex;
    return ListView(padding: const EdgeInsets.fromLTRB(17, 3, 17, 23), children: [
      Row(children: [
        PlaneText(q.category.toUpperCase(), style: const TextStyle(color: _lightGold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const Spacer(),
        if (_streak >= 2) _pill(Icons.local_fire_department_rounded, '$_streak seguidas'),
        const SizedBox(width: 7),
        PlaneText((_index + 1).toString() + '/10', style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 9),
      ClipRRect(borderRadius: BorderRadius.circular(18), child: LinearProgressIndicator(value: (_index + 1) / 10, minHeight: 7, backgroundColor: Colors.white12, color: _gold)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF203D68), Color(0xFF14253D)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: _gold.withOpacity(0.35))),
        child: Column(children: [
          const Icon(Icons.psychology_alt_rounded, color: _lightGold, size: 34),
          const SizedBox(height: 13),
          PlaneText(q.prompt, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, height: 1.35, fontWeight: FontWeight.w900)),
        ]),
      ),
      const SizedBox(height: 15),
      for (var i = 0; i < 4; i++) ...[_answerButton(i, q), const SizedBox(height: 9)],
      if (_selected != null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: (correct ? const Color(0xFF245B47) : const Color(0xFF653B48)).withOpacity(0.7), borderRadius: BorderRadius.circular(15), border: Border.all(color: correct ? _mint : const Color(0xFFFFA7A7))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(correct ? Icons.check_circle_rounded : Icons.lightbulb_rounded, color: correct ? _mint : _lightGold, size: 18),
              const SizedBox(width: 7),
              PlaneText(correct ? 'Excelente! +1 ponto' : 'Aprender também é ganhar', style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 6),
            PlaneText(q.explanation, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
          ]),
        ),
        const SizedBox(height: 13),
        SizedBox(height: 52, child: FilledButton(
          onPressed: _next,
          style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          child: PlaneText(_index == 9 ? 'Ver resultado' : 'Próxima pergunta', style: const TextStyle(fontWeight: FontWeight.w900)),
        )),
      ],
    ]);
  }

  Widget _answerButton(int index, QuizQuestion q) {
    final chosen = _selected == index, correct = q.correctIndex == index, revealed = _selected != null;
    final color = revealed && correct ? const Color(0xFF285B47) : revealed && chosen ? const Color(0xFF713E49) : _panel;
    return InkWell(
      onTap: _selected == null ? () => _answer(index) : null, borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15), border: Border.all(
          color: revealed && correct ? _mint : chosen ? _gold : Colors.white.withOpacity(0.13),
          width: chosen || (revealed && correct) ? 1.5 : 1,
        )),
        child: Row(children: [
          Container(width: 29, height: 29, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
            child: PlaneText(String.fromCharCode(65 + index), style: const TextStyle(fontWeight: FontWeight.w900, color: _lightGold))),
          const SizedBox(width: 11),
          Expanded(child: PlaneText(q.answers[index], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          if (revealed && correct) const Icon(Icons.check_circle_rounded, color: _mint),
          if (revealed && chosen && !correct) const Icon(Icons.close_rounded, color: Color(0xFFFFB1B1)),
        ]),
      ),
    );
  }

  Widget _result() {
    final pct = (_score / 10 * 100).round();
    final title = pct >= 90 ? 'Lenda do conhecimento!' : pct >= 70 ? 'Excelente piloto!' : pct >= 50 ? 'Boa viagem!' : 'Continua a explorar!';
    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(17), child: Container(
      width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF203B62), Color(0xFF111D31)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: _gold.withOpacity(0.5))),
      child: Column(children: [
        Icon(pct >= 90 ? Icons.emoji_events_rounded : Icons.flight_takeoff_rounded, color: _lightGold, size: 58),
        const SizedBox(height: 10),
        PlaneText(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        const PlaneText('A tua ronda terminou. Cada resposta é mais uma descoberta.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 18),
        PlaneText('$_score / 10', style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: _lightGold)),
        const PlaneText('respostas certas', style: TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _pill(Icons.local_fire_department_rounded, '$_bestStreak seguidas'),
          const SizedBox(width: 7),
          _pill(Icons.bolt_rounded, _saved ? '+$_xpEarned XP' : 'XP a sincronizar'),
        ]),
        if (_saving) ...[
          const SizedBox(height: 15), const LinearProgressIndicator(color: _gold, backgroundColor: Colors.white12),
          const SizedBox(height: 6), const PlaneText('A guardar os pontos…', style: TextStyle(color: Colors.white60, fontSize: 10)),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 12), PlaneText(_saveError!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFC0B6), fontSize: 11)),
          OutlinedButton.icon(onPressed: _saving ? null : _saveResult, icon: const Icon(Icons.sync_rounded), label: const PlaneText('Tentar sincronizar')),
        ],
        if (_saved) const Padding(padding: EdgeInsets.only(top: 12), child: PlaneText('Os pontos foram guardados na tua conta.', style: TextStyle(color: _mint, fontWeight: FontWeight.w800, fontSize: 11))),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(
          onPressed: _start, icon: const Icon(Icons.replay_rounded), label: const PlaneText('Jogar outra ronda'),
          style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        )),
        TextButton(onPressed: () { setState(() { _started = false; _finished = false; _tab = 1; }); _refresh(silent: true); },
          child: const PlaneText('Ver as minhas missões', style: TextStyle(color: _lightGold))),
      ]),
    )));
  }

  Widget _missions() {
    final missions = (_progress['missions'] as List<dynamic>? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final claimed = missions.where((m) => m['claimed'] == true).length;
    return ListView(padding: const EdgeInsets.fromLTRB(17, 3, 17, 24), children: [
      _levelCard(),
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(child: PlaneText('Missões do piloto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        PlaneText(claimed.toString() + '/' + missions.length.toString() + ' resgatadas', style: const TextStyle(color: _lightGold, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 5),
      const PlaneText('Cumpre objectivos reais no Paper Plane. Cada recompensa só pode ser resgatada uma vez.', style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
      if (_loading && missions.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: _gold)))
      else if (_error != null && missions.isEmpty) _retry(_error!)
      else for (final m in missions) ...[const SizedBox(height: 9), _missionCard(m)],
    ]);
  }

  Widget _missionCard(Map<String, dynamic> m) {
    final current = int.tryParse(m['current']?.toString() ?? '') ?? 0;
    final target = int.tryParse(m['target']?.toString() ?? '') ?? 1;
    final xp = int.tryParse(m['xp']?.toString() ?? '') ?? 0;
    final claimed = m['claimed'] == true, canClaim = m['claimable'] == true;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: canClaim ? _gold.withOpacity(0.75) : Colors.white.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: PlaneText(m['title']?.toString() ?? 'Missão', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))), PlaneText('+$xp XP', style: const TextStyle(color: _lightGold, fontWeight: FontWeight.w900, fontSize: 11))]),
        const SizedBox(height: 4),
        PlaneText(m['description']?.toString() ?? '', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (current / max(1, target)).clamp(0, 1), minHeight: 7, backgroundColor: Colors.white12, color: claimed ? _mint : _gold))),
          const SizedBox(width: 9), PlaneText('$current/$target', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        if (claimed) const Row(children: [Icon(Icons.check_circle_rounded, size: 16, color: _mint), SizedBox(width: 6), PlaneText('Recompensa resgatada', style: TextStyle(color: _mint, fontSize: 10, fontWeight: FontWeight.w800))])
        else if (canClaim) SizedBox(height: 37, child: FilledButton.icon(
          onPressed: () => _claim(m['key']?.toString() ?? ''), icon: const Icon(Icons.card_giftcard_rounded, size: 16),
          label: const PlaneText('Resgatar XP'),
          style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy, textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
        ))
        else const PlaneText('Continua a jogar para desbloquear.', style: TextStyle(color: Colors.white38, fontSize: 10)),
      ]),
    );
  }

  Widget _badges() {
    final badges = (_progress['badges'] as List<dynamic>? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final unlocked = badges.where((b) => b['unlocked'] == true).length;
    return ListView(padding: const EdgeInsets.fromLTRB(17, 3, 17, 24), children: [
      _levelCard(),
      const SizedBox(height: 15),
      Row(children: [
        const Expanded(child: PlaneText('A tua colecção', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        PlaneText(unlocked.toString() + '/' + badges.length.toString() + ' desbloqueados', style: const TextStyle(color: _lightGold, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 5),
      const PlaneText('Os crachás são atribuídos por acções reais na aplicação.', style: TextStyle(color: Colors.white60, fontSize: 11)),
      if (_loading && badges.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: _gold)))
      else if (_error != null && badges.isEmpty) _retry(_error!)
      else Wrap(spacing: 9, runSpacing: 9, children: [
        for (final b in badges) SizedBox(width: (MediaQuery.of(context).size.width - 43) / 2, child: _badgeCard(b)),
      ]),
    ]);
  }

  Widget _badgeCard(Map<String, dynamic> b) {
    final unlocked = b['unlocked'] == true;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: unlocked ? _gold.withOpacity(0.6) : Colors.white.withOpacity(0.09))),
      child: Column(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: unlocked ? _gold.withOpacity(0.15) : Colors.black.withOpacity(0.16), border: Border.all(color: unlocked ? _gold : Colors.white24)),
          child: Icon(_badgeIcon(b['icon']?.toString()), color: unlocked ? _lightGold : Colors.white30, size: 24)),
        const SizedBox(height: 8),
        PlaneText(b['title']?.toString() ?? 'Crachá', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: unlocked ? Colors.white : Colors.white54)),
        const SizedBox(height: 4),
        PlaneText(b['description']?.toString() ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.white54, height: 1.35)),
        const SizedBox(height: 5),
        PlaneText(unlocked ? 'DESBLOQUEADO' : 'POR DESBLOQUEAR', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.4, color: unlocked ? _mint : Colors.white30)),
      ]),
    );
  }

  IconData _badgeIcon(String? key) => switch (key) {
    'flight' => Icons.flight_takeoff_rounded, 'send' => Icons.send_rounded,
    'public' => Icons.public_rounded, 'inbox' => Icons.inbox_rounded,
    'reply' => Icons.reply_rounded, 'people' => Icons.people_alt_rounded,
    'forum' => Icons.forum_rounded, 'quiz' => Icons.quiz_rounded,
    'star' => Icons.star_rounded, 'school' => Icons.school_rounded,
    'flame' => Icons.local_fire_department_rounded, 'chat' => Icons.chat_bubble_rounded,
    'globe' => Icons.public_rounded, 'brain' => Icons.psychology_rounded,
    _ => Icons.workspace_premium_rounded,
  };

  Widget _retry(String message) => Container(
    padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      PlaneText(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const PlaneText('Tentar novamente')),
    ]),
  );
}