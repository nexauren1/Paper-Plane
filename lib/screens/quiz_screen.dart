import 'package:flutter/material.dart';

const Color _quizNavy = Color(0xFF071225);
const Color _quizGold = Color(0xFFF0CE7C);
const Color _quizGoldBright = Color(0xFFFFE7A8);
const Color _quizPanel = Color(0xCC172844);

class _QuizQuestion {
  const _QuizQuestion(this.category, this.question, this.answers, this.correct, this.explanation);
  final String category;
  final String question;
  final List<String> answers;
  final int correct;
  final String explanation;
}

const List<_QuizQuestion> _quizQuestions = [
  _QuizQuestion('Geografia', 'Qual é a capital de Moçambique?', ['Beira', 'Maputo', 'Nampula', 'Pemba'], 1, 'Maputo é a capital e a maior cidade de Moçambique.'),
  _QuizQuestion('Geografia', 'Qual é o maior oceano do planeta?', ['Atlântico', 'Índico', 'Pacífico', 'Ártico'], 2, 'O Oceano Pacífico é o maior e também o mais profundo.'),
  _QuizQuestion('Cultura', 'Que língua é oficial em Moçambique?', ['Suaíli', 'Inglês', 'Português', 'Francês'], 2, 'O português é a língua oficial; o país também tem várias línguas nacionais.'),
  _QuizQuestion('Natureza', 'Quantos continentes existem no modelo mais usado nas escolas?', ['5', '6', '7', '8'], 2, 'O modelo de sete continentes é o mais usado internacionalmente.'),
  _QuizQuestion('Geografia', 'Em que país fica o Monte Fuji?', ['China', 'Japão', 'Coreia do Sul', 'Tailândia'], 1, 'O Monte Fuji é um dos símbolos mais conhecidos do Japão.'),
  _QuizQuestion('Natureza', 'Qual destes animais é um mamífero?', ['Tubarão', 'Crocodilo', 'Golfinho', 'Tartaruga'], 2, 'O golfinho respira ar e alimenta as crias com leite.'),
  _QuizQuestion('Cultura', 'Qual é a cor do círculo no centro da bandeira do Japão?', ['Azul', 'Verde', 'Vermelho', 'Amarelo'], 2, 'A bandeira japonesa tem um disco vermelho que representa o Sol.'),
  _QuizQuestion('Geografia', 'Qual destes países fica na América do Sul?', ['Angola', 'Brasil', 'Índia', 'Austrália'], 1, 'O Brasil ocupa grande parte da América do Sul.'),
  _QuizQuestion('Natureza', 'Qual é a estrela mais próxima da Terra?', ['Sírius', 'A Estrela Polar', 'O Sol', 'Vega'], 2, 'O Sol é a estrela do nosso sistema solar.'),
  _QuizQuestion('Cultura', 'Quantos lados tem um hexágono?', ['5', '6', '7', '8'], 1, 'Hexa significa seis: um hexágono tem seis lados.'),
  _QuizQuestion('Geografia', 'Qual é a capital de Portugal?', ['Porto', 'Coimbra', 'Faro', 'Lisboa'], 3, 'Lisboa é a capital de Portugal.'),
  _QuizQuestion('Natureza', 'Que gás as plantas absorvem na fotossíntese?', ['Oxigénio', 'Dióxido de carbono', 'Hélio', 'Azoto'], 1, 'As plantas utilizam dióxido de carbono, água e luz para produzir açúcares.'),
];

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  String _category = 'Todas';
  List<_QuizQuestion> _round = [];
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _started = false;
  bool _finished = false;

  List<_QuizQuestion> get _available => _category == 'Todas'
      ? _quizQuestions
      : _quizQuestions.where((q) => q.category == _category).toList();

  void _start() {
    setState(() {
      _round = List<_QuizQuestion>.from(_available);
      _index = 0;
      _score = 0;
      _selected = null;
      _started = true;
      _finished = false;
    });
  }

  void _answer(int value) {
    if (_selected != null || _finished) return;
    setState(() {
      _selected = value;
      if (value == _round[_index].correct) _score++;
    });
  }

  void _next() {
    if (_index >= _round.length - 1) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _selected = null;
      });
    }
  }

  void _restart() {
    setState(() {
      _started = false;
      _finished = false;
      _selected = null;
      _index = 0;
      _score = 0;
      _round = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(19, 15, 19, 12),
          child: Row(children: [
            const Icon(Icons.quiz_outlined, color: _quizGold, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Quiz do Céu', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              Text('Perguntas rápidas, só para diversão', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ])),
            if (_started) IconButton(onPressed: _restart, icon: const Icon(Icons.close_rounded, color: _quizGoldBright)),
          ]),
        ),
        Expanded(child: !_started ? _startPanel() : _finished ? _resultPanel() : _questionPanel()),
      ]),
    );
  }

  Widget _startPanel() => ListView(
    padding: const EdgeInsets.fromLTRB(18, 5, 18, 24),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF263F70), Color(0xFF101D34)]),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: _quizGold.withOpacity(0.45)),
        ),
        child: const Column(children: [
          Icon(Icons.auto_awesome_rounded, color: _quizGoldBright, size: 48),
          SizedBox(height: 12),
          Text('Desafia a tua curiosidade', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
          SizedBox(height: 7),
          Text('Escolhe um tema e responde às perguntas. Não há prémios nem pressão: é apenas uma pausa divertida entre voos.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('Escolhe a categoria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _categoryChip('Todas', Icons.public_rounded),
        _categoryChip('Geografia', Icons.map_outlined),
        _categoryChip('Natureza', Icons.eco_outlined),
        _categoryChip('Cultura', Icons.lightbulb_outline_rounded),
      ]),
      const SizedBox(height: 16),
      _metricRow(Icons.help_outline_rounded, _available.length.toString() + ' perguntas nesta ronda'),
      const SizedBox(height: 8),
      _metricRow(Icons.wifi_off_rounded, 'Funciona sem internet'),
      const SizedBox(height: 20),
      SizedBox(
        height: 60,
        child: FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Começar quiz'),
          style: FilledButton.styleFrom(backgroundColor: _quizGold, foregroundColor: _quizNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    ],
  );

  Widget _categoryChip(String value, IconData icon) {
    final selected = _category == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _category = value),
      avatar: Icon(icon, size: 17, color: selected ? _quizNavy : _quizGoldBright),
      label: Text(value),
      selectedColor: _quizGold,
      backgroundColor: _quizPanel,
      side: BorderSide(color: selected ? _quizGold : Colors.white24),
      labelStyle: TextStyle(color: selected ? _quizNavy : Colors.white70, fontWeight: FontWeight.w800),
    );
  }

  Widget _metricRow(IconData icon, String value) => Row(children: [
    Icon(icon, color: _quizGoldBright, size: 19),
    const SizedBox(width: 9),
    Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);

  Widget _questionPanel() {
    final question = _round[_index];
    final progress = (_index + 1) / _round.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        Row(children: [
          Text(question.category.toUpperCase(), style: const TextStyle(color: _quizGoldBright, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const Spacer(),
          Text('Pergunta ' + (_index + 1).toString() + ' de ' + _round.length.toString(), style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: Colors.white12, color: _quizGold),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(color: _quizPanel, borderRadius: BorderRadius.circular(22), border: Border.all(color: _quizGold.withOpacity(0.35))),
          child: Column(children: [
            const Icon(Icons.psychology_alt_rounded, color: _quizGoldBright, size: 38),
            const SizedBox(height: 15),
            Text(question.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, height: 1.35, fontWeight: FontWeight.w900)),
          ]),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < question.answers.length; i++) ...[
          _answerButton(i, question),
          const SizedBox(height: 9),
        ],
        if (_selected != null) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_selected == question.correct ? const Color(0xFF2D6A50) : const Color(0xFF703B42)).withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _selected == question.correct ? const Color(0xFF86DDAA) : const Color(0xFFFFA7A7).withOpacity(0.65)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_selected == question.correct ? 'Muito bem! Resposta certa.' : 'Quase! Vamos aprender.',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(question.explanation, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(backgroundColor: _quizGold, foregroundColor: _quizNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: Text(_index == _round.length - 1 ? 'Ver resultado' : 'Próxima pergunta', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _answerButton(int index, _QuizQuestion question) {
    final chosen = _selected == index;
    final correct = question.correct == index;
    final showResult = _selected != null;
    final color = showResult && correct ? const Color(0xFF327354) : showResult && chosen ? const Color(0xFF783F47) : _quizPanel;
    return InkWell(
      onTap: _selected == null ? () => _answer(index) : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: showResult && correct ? const Color(0xFF8DE0B0) : chosen ? _quizGold : Colors.white.withOpacity(0.13),
            width: chosen || (showResult && correct) ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 28, height: 28, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.09)),
            child: Text(String.fromCharCode(65 + index), style: const TextStyle(fontWeight: FontWeight.w900, color: _quizGoldBright)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(question.answers[index], style: const TextStyle(fontWeight: FontWeight.w700))),
          if (showResult && correct) const Icon(Icons.check_circle_rounded, color: Color(0xFF9AE6B8)),
          if (showResult && chosen && !correct) const Icon(Icons.close_rounded, color: Color(0xFFFFB1B1)),
        ]),
      ),
    );
  }

  Widget _resultPanel() {
    final percent = (_score / _round.length * 100).round();
    final title = percent >= 80 ? 'Excelente piloto!' : percent >= 50 ? 'Boa viagem!' : 'Continua a explorar!';
    final subtitle = percent >= 80
        ? 'Tens uma curiosidade de ouro. Parabéns!'
        : percent >= 50
            ? 'Já sabes bastante. Mais uma ronda e vais ainda melhor.'
            : 'Cada pergunta é uma oportunidade de aprender algo novo.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(color: _quizPanel, borderRadius: BorderRadius.circular(25), border: Border.all(color: _quizGold.withOpacity(0.45))),
          child: Column(children: [
            Icon(percent >= 80 ? Icons.workspace_premium_rounded : Icons.flight_takeoff_rounded, color: _quizGoldBright, size: 60),
            const SizedBox(height: 15),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.45)),
            const SizedBox(height: 24),
            Text(_score.toString() + ' / ' + _round.length.toString(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: _quizGoldBright)),
            const Text('respostas certas', style: TextStyle(color: Colors.white60)),
            const SizedBox(height: 7),
            Text(percent.toString() + '%', style: const TextStyle(color: _quizGoldBright, fontWeight: FontWeight.w800)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity, height: 54,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Jogar novamente'),
                style: FilledButton.styleFrom(backgroundColor: _quizGold, foregroundColor: _quizNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              ),
            ),
            TextButton(onPressed: _restart, child: const Text('Escolher outra categoria', style: TextStyle(color: _quizGoldBright))),
          ]),
        ),
      ),
    );
  }
}
