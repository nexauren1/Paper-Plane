import 'package:flutter/material.dart';
import '../services/paper_plane_api.dart';
import '../services/paper_plane_localization.dart';

const Color _bg = Color(0xFF050B19);
const Color _panel = Color(0xFF0D1A32);
const Color _blue = Color(0xFF1677F8);
const Color _cyan = Color(0xFF56DFFF);
const Color _white = Color(0xFFF4FAFF);

String _gt(String source) => PaperPlaneLocale.translate(source);

const Map<String, String> _categories = {
  'TECH': 'Tecnologia',
  'TRAVEL': 'Viagens',
  'LANGUAGE': 'Idiomas',
  'CULTURE': 'Cultura',
  'GAMING': 'Gaming',
  'GENERAL': 'Geral',
};

IconData _categoryIcon(String? category) {
  switch (category) {
    case 'TECH': return Icons.memory_rounded;
    case 'TRAVEL': return Icons.public_rounded;
    case 'LANGUAGE': return Icons.translate_rounded;
    case 'CULTURE': return Icons.palette_outlined;
    case 'GAMING': return Icons.sports_esports_rounded;
    default: return Icons.groups_rounded;
  }
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  String? _error;
  String _category = 'ALL';

  List<Map<String, dynamic>> _items(dynamic value) => (value as List<dynamic>? ?? const [])
      .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();

  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await PaperPlaneApi.instance.getGroups(query: _search.text, category: _category);
      if (!mounted) return;
      setState(() { _groups = _items(data['items']); _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException ? error.message : 'Não foi possível carregar as comunidades.';
      });
    }
  }

  Future<void> _open(Map<String, dynamic> group) async {
    final id = group['id']?.toString() ?? '';
    if (id.isEmpty) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GroupDetailScreen(groupId: id, initialGroup: group),
    ));
    if (mounted) _refresh();
  }

  Future<void> _join(Map<String, dynamic> group) async {
    final id = group['id']?.toString() ?? '';
    try {
      await PaperPlaneApi.instance.joinGroup(id);
      if (mounted) await _open({...group, 'is_member': 1});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is PaperPlaneApiException ? error.message : 'Não foi possível entrar nesta comunidade.'),
      ));
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final description = TextEditingController();
    String category = 'GENERAL';
    bool saving = false;
    String? errorText;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(sheet).viewInsets.bottom + 22),
          child: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(_gt('Criar comunidade'), style: TextStyle(color: _white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Text(_gt('Cria um espaço para pessoas com interesses em comum.'), style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 17),
              TextField(controller: name, maxLength: 40, style: const TextStyle(color: _white), decoration: _decoration('Nome da comunidade')),
              const SizedBox(height: 7),
              TextField(controller: description, maxLength: 160, maxLines: 3, style: const TextStyle(color: _white), decoration: _decoration('Descrição')),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: _panel,
                style: const TextStyle(color: _white),
                decoration: _decoration('Categoria'),
                items: _categories.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(_gt(entry.value)))).toList(),
                onChanged: saving ? null : (value) { if (value != null) update(() => category = value); },
              ),
              if (errorText != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(errorText!, style: const TextStyle(color: Color(0xFFFF9A9A), fontSize: 12)),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 52, child: FilledButton.icon(
                onPressed: saving ? null : () async {
                  if (name.text.trim().length < 3) { update(() => errorText = 'O nome precisa de pelo menos três caracteres.'); return; }
                  update(() { saving = true; errorText = null; });
                  try {
                    final result = await PaperPlaneApi.instance.createGroup(
                      name: name.text.trim(), description: description.text.trim(), category: category,
                    );
                    if (!sheet.mounted) return;
                    Navigator.pop(sheet);
                    await _refresh();
                    final group = result['group'];
                    if (group is Map && mounted) await _open(Map<String, dynamic>.from(group));
                  } catch (e) {
                    update(() {
                      saving = false;
                      errorText = e is PaperPlaneApiException ? e.message : 'Não foi possível criar a comunidade.';
                    });
                  }
                },
                icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded),
                label: Text(saving ? _gt('A criar…') : _gt('Criar comunidade')),
                style: FilledButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
              )),
            ],
          )),
        ),
      ),
    );
    name.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: _cyan,
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_gt('Comunidades'), style: TextStyle(color: _white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -0.7)),
            SizedBox(height: 3),
            Text(_gt('Encontra o teu lugar no mundo.'), style: TextStyle(color: Colors.white60, fontSize: 12)),
          ])),
          _ActionButton(icon: Icons.add_rounded, onTap: _create),
        ]),
        const SizedBox(height: 16),
        Container(
          height: 160,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1458B8), Color(0xFF14265A), Color(0xFF24144F)]),
            border: Border.all(color: _cyan.withOpacity(0.35)),
            boxShadow: [BoxShadow(color: _blue.withOpacity(0.2), blurRadius: 22, offset: const Offset(0, 9))],
          ),
          child: Stack(children: [
            const Positioned(right: -5, top: -12, child: Icon(Icons.groups_rounded, size: 118, color: Color(0x225BE7FF))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text(_gt('OS TEUS INTERESSES. O TEU MUNDO.'), style: TextStyle(color: _cyan, fontSize: 9, letterSpacing: 1.15, fontWeight: FontWeight.w900)),
              Spacer(),
              Text(_gt('Pessoas que pensam como tu.'), style: TextStyle(color: Colors.white, fontSize: 24, height: 1.04, fontWeight: FontWeight.w900)),
              SizedBox(height: 7),
              Text(_gt('Descobre comunidades e começa uma conversa.'), style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onSubmitted: (_) => _refresh(),
          style: const TextStyle(color: _white),
          decoration: _decoration(_gt('Pesquisar comunidades')).copyWith(
            prefixIcon: const Icon(Icons.search_rounded, color: _cyan),
            suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _refresh),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, children: [
          _chip('ALL', _gt('Todas')),
          for (final item in _categories.entries) _chip(item.key, _gt(item.value)),
        ])),
        const SizedBox(height: 18),
        Row(children: [
          const Expanded(child: Text(_gt('Explorar comunidades'), style: TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w900))),
          Text(_groups.length.toString() + ' ' + _gt('encontradas'), style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
        const SizedBox(height: 10),
        if (_loading) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: _cyan)))
        else if (_error != null) _EmptyState(icon: Icons.cloud_off_rounded, title: 'Sem ligação ao céu', detail: _error!, action: _refresh)
        else if (_groups.isEmpty) _EmptyState(icon: Icons.travel_explore_rounded, title: 'Ainda não há comunidades', detail: 'Cria a primeira comunidade e convida outros copilotos a participar.', action: _create)
        else for (final group in _groups) _GroupCard(
          group: group,
          onOpen: () => _open(group),
          onJoin: () => _join(group),
        ),
      ],
    ),
  );

  Widget _chip(String value, String label) {
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
        selected: selected,
        onSelected: (_) { setState(() => _category = value); _refresh(); },
        selectedColor: _blue,
        backgroundColor: _panel,
        side: BorderSide(color: selected ? _cyan.withOpacity(0.9) : Colors.white12),
        showCheckmark: false,
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onOpen, required this.onJoin});
  final Map<String, dynamic> group;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final category = group['category']?.toString() ?? 'GENERAL';
    final joined = group['is_member'] == 1 || group['is_member'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0x333D91E8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 13, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            height: 54, width: 54,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(17),
              gradient: const LinearGradient(colors: [_blue, Color(0xFF7139D6)]),
              boxShadow: [BoxShadow(color: _blue.withOpacity(0.25), blurRadius: 13)]),
            child: Icon(_categoryIcon(category), color: Colors.white, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(group['name']?.toString() ?? 'Comunidade', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _white, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 4),
            Text(_gt(_categories[category] ?? 'Geral'), style: const TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w700)),
          ])),
          if (joined) const Icon(Icons.verified_rounded, color: _cyan, size: 18),
        ]),
        const SizedBox(height: 11),
        Text((group['description']?.toString().isNotEmpty == true)
          ? group['description'].toString()
          : _gt('Uma comunidade para conversar, partilhar e descobrir.'),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        const SizedBox(height: 13),
        Row(children: [
          const Icon(Icons.people_alt_outlined, color: Colors.white54, size: 16),
          const SizedBox(width: 5),
          Text((group['member_count'] ?? 0).toString() + ' ' + _gt('membros'), style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const Spacer(),
          SizedBox(height: 36, child: FilledButton(
            onPressed: joined ? onOpen : onJoin,
            style: FilledButton.styleFrom(
              backgroundColor: joined ? const Color(0xFF183D68) : _blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(joined ? _gt('Abrir') : _gt('Participar'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          )),
        ]),
      ]),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId, this.initialGroup});
  final String groupId;
  final Map<String, dynamic>? initialGroup;
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic> _group = {};
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  bool get _member => _group['is_member'] == true || _group['is_member'] == 1;
  bool get _owner => _group['is_owner'] == true || _group['is_owner'] == 1;

  @override
  void initState() { super.initState(); _group = widget.initialGroup ?? {}; _refresh(); }
  @override
  void dispose() { _message.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await PaperPlaneApi.instance.getGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        _group = Map<String, dynamic>.from(data['group'] as Map? ?? const {});
        _messages = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is PaperPlaneApiException ? e.message : 'Não foi possível abrir esta comunidade.';
      });
    }
  }

  Future<void> _join() async {
    try { await PaperPlaneApi.instance.joinGroup(widget.groupId); await _refresh(); }
    catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is PaperPlaneApiException ? e.message : 'Não foi possível entrar.')));
    }
  }

  Future<void> _send() async {
    final message = _message.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await PaperPlaneApi.instance.sendGroupMessage(widget.groupId, message);
      _message.clear();
      await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is PaperPlaneApiException ? e.message : 'A mensagem não foi enviada.')));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _leaveOrDelete() async {
    final deleting = _owner;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _panel,
      title: Text(_gt(deleting ? 'Eliminar comunidade?' : 'Sair da comunidade?'), style: const TextStyle(color: _white)),
      content: Text(_gt(deleting ? 'A comunidade e as suas mensagens serão removidas.' : 'Deixarás de receber e enviar mensagens nesta comunidade.'),
        style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_gt('Cancelar'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_gt(deleting ? 'Eliminar' : 'Sair'))),
      ],
    ));
    if (confirmed != true) return;
    try {
      if (deleting) { await PaperPlaneApi.instance.deleteGroup(widget.groupId); }
      else { await PaperPlaneApi.instance.leaveGroup(widget.groupId); }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is PaperPlaneApiException ? e.message : 'Não foi possível concluir esta ação.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _group['name']?.toString() ?? 'Comunidade';
    final category = _group['category']?.toString() ?? 'GENERAL';
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, foregroundColor: _white,
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [if (_member) IconButton(onPressed: _leaveOrDelete, icon: const Icon(Icons.more_vert_rounded))],
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 5, 16, 13),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            gradient: const LinearGradient(colors: [Color(0xFF1557AB), Color(0xFF18214D), Color(0xFF27174A)]),
            border: Border.all(color: _cyan.withOpacity(0.32)),
          ),
          child: Row(children: [
            Container(height: 58, width: 58,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
              child: Icon(_categoryIcon(category), color: Colors.white, size: 30)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(_group['description']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.35)),
              const SizedBox(height: 5),
              Text((_group['member_count'] ?? 0).toString() + ' membros · ' + (_categories[category] ?? 'Geral'),
                style: const TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w700)),
            ])),
          ]),
        ),
        if (!_member)
          Expanded(child: Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.public_rounded, color: _cyan, size: 52),
              const SizedBox(height: 12),
              Text(_gt('Faz parte desta comunidade'), style: TextStyle(color: _white, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 7),
              Text(_gt('Entra para ver as conversas e participar.'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: _join, icon: const Icon(Icons.group_add_rounded), label: Text(_gt('Participar'))),
            ]),
          )))
        else if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _cyan)))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.white70))))
        else
          Expanded(child: _messages.isEmpty
            ? Center(child: Text(_gt('A primeira conversa começa contigo.'), style: TextStyle(color: Colors.white54)))
            : ListView.builder(
                controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _messages.length,
                itemBuilder: (ctx, index) {
                  final item = _messages[index];
                  final mine = item['is_own'] == 1 || item['is_own'] == true;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.82),
                      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: mine ? const Color(0xFF174F91) : _panel,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: mine ? _cyan.withOpacity(0.22) : Colors.white10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!mine) Text(item['pilot_name']?.toString() ?? 'Copiloto',
                          style: const TextStyle(color: _cyan, fontSize: 10, fontWeight: FontWeight.w900)),
                        Text(item['message_text']?.toString() ?? '', style: const TextStyle(color: _white, fontSize: 13, height: 1.4)),
                        const SizedBox(height: 4),
                        Text(_ago(item['created_at']?.toString()), style: const TextStyle(color: Colors.white38, fontSize: 9)),
                      ]),
                    ),
                  );
                },
              )),
        if (_member) SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _message, maxLength: 500, minLines: 1, maxLines: 4,
                style: const TextStyle(color: _white),
                decoration: _decoration(_gt('Escreve na comunidade')).copyWith(counterText: ''),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

String _ago(String? value) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return '';
  final age = DateTime.now().difference(date.toLocal());
  if (age.inMinutes < 1) return 'agora';
  if (age.inHours < 1) return age.inMinutes.toString() + ' min';
  if (age.inDays < 1) return age.inHours.toString() + ' h';
  return age.inDays.toString() + ' d';
}

InputDecoration _decoration(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
  filled: true,
  fillColor: const Color(0xFF071326),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _cyan.withOpacity(0.18))),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _cyan.withOpacity(0.18))),
);

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Ink(
        height: 46, width: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(colors: [_blue, Color(0xFF6943D8)]),
          boxShadow: [BoxShadow(color: _blue.withOpacity(0.3), blurRadius: 15)],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.detail, required this.action});
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
    child: Column(children: [
      Icon(icon, color: _cyan, size: 36),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(color: _white, fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(height: 6),
      Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45)),
      const SizedBox(height: 12),
      TextButton.icon(onPressed: action, icon: const Icon(Icons.refresh_rounded), label: Text(_gt('Tentar novamente'))),
    ]),
  );
}
