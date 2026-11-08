import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/paper_plane_api.dart';

const Color _chatNavy = Color(0xFF071225);
const Color _chatGold = Color(0xFFF0CE7C);
const Color _chatGoldBright = Color(0xFFFFE7A8);
const Color _chatPanel = Color(0xCC172844);

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  int _section = 0;
  bool _loading = true;
  bool _searching = false;
  String? _error;
  String _myHandle = '';
  final TextEditingController _search = TextEditingController();
  Timer? _poller;
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 25), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data, String key) =>
      (data[key] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        PaperPlaneApi.instance.getChats(),
        PaperPlaneApi.instance.getFriends(),
        PaperPlaneApi.instance.getFriendRequests(),
        PaperPlaneApi.instance.getProfile(),
      ]);
      if (!mounted) return;
      final pilot = responses[3]['pilot'] as Map<String, dynamic>? ?? const {};
      final accepted = _items(responses[1], 'items');
      final friendRequests = _items(responses[2], 'incoming');
      final pending = _items(responses[1], 'incomingRequests');
      final incomingById = <String, Map<String, dynamic>>{
        for (final item in [...pending, ...friendRequests])
          item['id']?.toString() ?? '': item,
      }..remove('');
      setState(() {
        _chats = _items(responses[0], 'items');
        _friends = accepted;
        _incoming = incomingById.values.toList();
        _outgoing = _items(responses[2], 'outgoing');
        _myHandle = pilot['pilot_handle']?.toString() ?? '';
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException
            ? error.message
            : 'Não foi possível atualizar as tuas amizades e Chamas.';
      });
    }
  }

  Future<void> _searchPilots() async {
    final query = _search.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (query.length < 2) {
      _notice('Escreve pelo menos duas letras do nome de copiloto.');
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await PaperPlaneApi.instance.searchFriends(query);
      if (!mounted) return;
      setState(() => _results = _items(result, 'items'));
      if (_results.isEmpty) _notice('Não encontrámos copilotos com esse nome.');
    } catch (error) {
      if (!mounted) return;
      _notice(error is PaperPlaneApiException ? error.message : 'A pesquisa falhou. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFriend(String handle) async {
    try {
      final result = await PaperPlaneApi.instance.requestFriend(handle);
      if (!mounted) return;
      final status = result['status']?.toString();
      _notice(status == 'ACCEPTED'
          ? 'Amizade confirmada. A Chama acende quando trocarem aviões.'
          : 'Pedido enviado. O outro copiloto pode aceitar no Chat.');
      await _refresh(silent: true);
      await _searchPilots();
    } catch (error) {
      if (!mounted) return;
      _notice(error is PaperPlaneApiException ? error.message : 'Não foi possível enviar o pedido.');
    }
  }

  Future<void> _respond(String id, bool accept) async {
    try {
      await PaperPlaneApi.instance.respondFriendRequest(id, accept: accept);
      if (!mounted) return;
      _notice(accept ? 'Pedido aceite. Já fazem parte da lista de amigos.' : 'Pedido recusado.');
      await _refresh(silent: true);
    } catch (error) {
      if (!mounted) return;
      _notice(error is PaperPlaneApiException ? error.message : 'Não foi possível atualizar o pedido.');
    }
  }

  Future<void> _removeFriend(String uid, String handle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF172844),
        title: const Text('Remover amigo?'),
        content: Text('Queres remover @$handle da tua lista de amigos? A conversa Chama não será apagada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _chatGold, foregroundColor: _chatNavy),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PaperPlaneApi.instance.removeFriend(uid);
      await _refresh(silent: true);
      _notice('Amigo removido.');
    } catch (error) {
      _notice(error is PaperPlaneApiException ? error.message : 'Não foi possível remover o amigo.');
    }
  }

  Future<void> _copyInvite() async {
    if (_myHandle.isEmpty) {
      _notice('Completa primeiro o teu perfil de copiloto.');
      return;
    }
    final link = PaperPlaneApi.instance.buildFriendInviteLink(_myHandle);
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    _notice('Link de convite copiado. Partilha-o com quem quiseres adicionar.');
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 15, 19, 10),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: _chatGold, size: 27),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chat & Amigos', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                      Text('Liga-te a copilotos de todo o mundo', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _copyInvite,
                  tooltip: 'Copiar link de convite',
                  icon: const Icon(Icons.link_rounded, color: _chatGoldBright),
                ),
                IconButton(
                  onPressed: () => _refresh(),
                  tooltip: 'Atualizar',
                  icon: const Icon(Icons.refresh_rounded, color: _chatGoldBright),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(child: _sectionChip(0, 'Chamas', Icons.local_fire_department_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _sectionChip(1, 'Amigos', Icons.people_alt_outlined)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _chatGold))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined, color: Colors.orangeAccent, size: 34),
                              const SizedBox(height: 10),
                              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: _chatGold,
                        onRefresh: _refresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 26),
                          children: _section == 0 ? _buildFlames() : _buildFriends(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sectionChip(int index, String label, IconData icon) {
    final active = _section == index;
    return InkWell(
      onTap: () => setState(() => _section = index),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _chatGold.withOpacity(0.18) : _chatPanel,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: active ? _chatGold : Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? _chatGoldBright : Colors.white70),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? _chatGoldBright : Colors.white70)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFlames() {
    return [
      _infoPanel(
        icon: Icons.local_fire_department_rounded,
        title: 'A Chama do Deserto',
        body: 'A Chama só começa quando alguém recebe um dos teus aviões e te responde com outro avião. Depois disso, a conversa privada fica disponível para os dois.',
        highlight: true,
      ),
      const SizedBox(height: 15),
      _sectionTitle('As tuas Chamas', _chats.length.toString()),
      if (_chats.isEmpty)
        _emptyPanel(
          icon: Icons.flight_takeoff_rounded,
          title: 'Ainda não tens uma Chama acesa',
          body: 'Envia um avião, recebe uma resposta e abre a ligação que nasce entre os dois copilotos. Não é preciso adicionar a pessoa primeiro.',
        )
      else
        for (final chat in _chats) ...[
          const SizedBox(height: 9),
          _chatTile(chat),
        ],
      const SizedBox(height: 12),
      _infoPanel(
        icon: Icons.public_rounded,
        title: 'Amigos pelo mundo',
        body: 'Podes adicionar amigos por @nome ou enviar o teu link de convite. A amizade não abre a conversa automaticamente: a Chama continua a depender da troca de aviões.',
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => setState(() => _section = 1),
        icon: const Icon(Icons.people_alt_outlined),
        label: const Text('Explorar amigos do mundo'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _chatGoldBright,
          side: BorderSide(color: _chatGold.withOpacity(0.55)),
          minimumSize: const Size.fromHeight(49),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    ];
  }

  List<Widget> _buildFriends() {
    return [
      _infoPanel(
        icon: Icons.public_rounded,
        title: 'A tua rede mundial',
        body: 'Procura pelo nome de copiloto que começa com @. As amizades respeitam a faixa etária declarada e os bloqueios de segurança.',
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _searchPilots(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Pesquisar @nome_de_copiloto',
                prefixIcon: const Icon(Icons.search_rounded, color: _chatGoldBright),
                filled: true,
                fillColor: const Color(0xFF132541),
                contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withOpacity(0.12))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _chatGold)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 51,
            child: FilledButton(
              onPressed: _searching ? null : _searchPilots,
              style: FilledButton.styleFrom(backgroundColor: _chatGold, foregroundColor: _chatNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _searching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _chatNavy))
                  : const Icon(Icons.search_rounded),
            ),
          ),
        ],
      ),
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionTitle('Resultados', _results.length.toString()),
        for (final person in _results) ...[
          const SizedBox(height: 8),
          _personTile(person, action: 'Adicionar', onTap: () => _addFriend('@${person['pilot_handle']}')),
        ],
      ],
      const SizedBox(height: 16),
      _sectionTitle('Pedidos recebidos', _incoming.length.toString()),
      if (_incoming.isEmpty)
        _emptyPanel(icon: Icons.mark_email_read_outlined, title: 'Sem pedidos pendentes', body: 'Quando alguém te convidar, o pedido aparece aqui.')
      else
        for (final request in _incoming) ...[
          const SizedBox(height: 8),
          _requestTile(request),
        ],
      if (_outgoing.isNotEmpty) ...[
        const SizedBox(height: 15),
        _sectionTitle('Pedidos enviados', _outgoing.length.toString()),
        for (final request in _outgoing) ...[
          const SizedBox(height: 8),
          _personTile(request, action: 'Pendente', onTap: null),
        ],
      ],
      const SizedBox(height: 16),
      _sectionTitle('Amigos', _friends.length.toString()),
      if (_friends.isEmpty)
        _emptyPanel(icon: Icons.people_outline_rounded, title: 'A tua lista está vazia', body: 'Procura um @nome ou copia o teu link de convite para começar.')
      else
        for (final friend in _friends) ...[
          const SizedBox(height: 8),
          _personTile(
            friend,
            action: 'Remover',
            onTap: () => _removeFriend(
              friend['uid']?.toString() ?? '',
              friend['pilot_handle']?.toString() ?? 'copiloto',
            ),
            actionColor: const Color(0xFFFFB6A6),
          ),
        ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _copyInvite,
        icon: const Icon(Icons.link_rounded),
        label: const Text('Copiar o meu link de convite'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _chatGoldBright,
          side: BorderSide(color: _chatGold.withOpacity(0.55)),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    ];
  }

  Widget _chatTile(Map<String, dynamic> chat) {
    final name = chat['pilot_name']?.toString() ?? 'Copiloto';
    final handle = chat['pilot_handle']?.toString() ?? 'piloto';
    final country = chat['country_code']?.toString();
    final last = chat['last_message']?.toString();
    final conversationId = chat['conversation_id']?.toString() ?? '';
    return InkWell(
      onTap: conversationId.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChamaConversationScreen(
                    conversationId: conversationId,
                    fallbackName: name,
                    fallbackHandle: handle,
                    fallbackCountry: country,
                  ),
                ),
              ),
      borderRadius: BorderRadius.circular(18),
      child: _panel(
        highlight: true,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFF304C77),
              child: Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB66E), size: 27),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 3),
                Text('@$handle${country == null ? '' : ' · ${_flag(country)} ${_country(country)}'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 5),
                Text(last?.isNotEmpty == true ? last! : 'A Chama está acesa. Começa a conversa…',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _chatGoldBright, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: _chatGold),
          ],
        ),
      ),
    );
  }

  Widget _requestTile(Map<String, dynamic> request) {
    final name = request['pilot_name']?.toString() ?? 'Copiloto';
    final handle = request['pilot_handle']?.toString() ?? 'piloto';
    final country = request['country_code']?.toString();
    final id = request['id']?.toString() ?? '';
    return _panel(
      child: Row(children: [
        const CircleAvatar(backgroundColor: Color(0xFF253E65), child: Icon(Icons.person_add_alt_1_rounded, color: _chatGoldBright)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('@$handle${country == null ? '' : ' · ${_flag(country)} ${_country(country)}'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ])),
        IconButton(
          tooltip: 'Aceitar',
          onPressed: id.isEmpty ? null : () => _respond(id, true),
          icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF8EE0B1)),
        ),
        IconButton(
          tooltip: 'Recusar',
          onPressed: id.isEmpty ? null : () => _respond(id, false),
          icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFFA6A6)),
        ),
      ]),
    );
  }

  Widget _personTile(
    Map<String, dynamic> person, {
    required String action,
    required VoidCallback? onTap,
    Color actionColor = _chatGoldBright,
  }) {
    final name = person['pilot_name']?.toString() ?? 'Copiloto';
    final handle = person['pilot_handle']?.toString() ?? 'piloto';
    final country = person['country_code']?.toString();
    return _panel(
      child: Row(children: [
        const CircleAvatar(
          backgroundColor: Color(0xFF263F68),
          child: Icon(Icons.person_outline_rounded, color: _chatGoldBright),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('@$handle${country == null ? '' : ' · ${_flag(country)} ${_country(country)}'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ])),
        TextButton(
          onPressed: onTap,
          child: Text(action, style: TextStyle(color: actionColor, fontWeight: FontWeight.w800, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String title, String count) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
        Text(count, style: const TextStyle(color: _chatGoldBright, fontWeight: FontWeight.w800)),
      ]);

  Widget _infoPanel({required IconData icon, required String title, required String body, bool highlight = false}) =>
      _panel(
        highlight: highlight,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _chatGoldBright, size: 28),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
          ])),
        ]),
      );

  Widget _emptyPanel({required IconData icon, required String title, required String body}) =>
      _panel(
        child: Column(children: [
          Icon(icon, color: _chatGoldBright, size: 32),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45)),
        ]),
      );

  Widget _panel({required Widget child, bool highlight = false}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _chatPanel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: highlight ? _chatGold.withOpacity(0.46) : Colors.white.withOpacity(0.11)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 5)),
            if (highlight) BoxShadow(color: _chatGold.withOpacity(0.06), blurRadius: 14),
          ],
        ),
        child: child,
      );

  String _country(String? code) {
    const names = {
      'MZ': 'Moçambique', 'BR': 'Brasil', 'PT': 'Portugal', 'JP': 'Japão',
      'ZA': 'África do Sul', 'AO': 'Angola', 'IN': 'Índia', 'US': 'EUA',
      'GB': 'Reino Unido', 'FR': 'França', 'DE': 'Alemanha', 'NG': 'Nigéria',
    };
    return names[code?.toUpperCase()] ?? (code ?? 'Mundo');
  }

  String _flag(String? code) {
    if (code == null || code.length != 2) return '🌍';
    return String.fromCharCodes(code.toUpperCase().codeUnits.map((value) => value + 127397));
  }
}

class ChamaConversationScreen extends StatefulWidget {
  const ChamaConversationScreen({
    super.key,
    required this.conversationId,
    required this.fallbackName,
    required this.fallbackHandle,
    this.fallbackCountry,
  });

  final String conversationId;
  final String fallbackName;
  final String fallbackHandle;
  final String? fallbackCountry;

  @override
  State<ChamaConversationScreen> createState() => _ChamaConversationScreenState();
}

class _ChamaConversationScreenState extends State<ChamaConversationScreen> {
  final TextEditingController _message = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _poller;
  bool _loading = true;
  bool _sending = false;
  String _name = '';
  String _handle = '';
  String? _countryCode;
  String? _otherUid;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _name = widget.fallbackName;
    _handle = widget.fallbackHandle;
    _countryCode = widget.fallbackCountry;
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 8), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final data = await PaperPlaneApi.instance.getChat(widget.conversationId);
      final conversation = data['conversation'] as Map<String, dynamic>? ?? const {};
      final messages = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _name = conversation['pilot_name']?.toString() ?? _name;
        _handle = conversation['pilot_handle']?.toString() ?? _handle;
        _countryCode = conversation['country_code']?.toString() ?? _countryCode;
        _otherUid = conversation['other_uid']?.toString();
        _messages = messages;
        _loading = false;
        _error = null;
      });
      if (messages.isNotEmpty && !_scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException ? error.message : 'Não foi possível carregar a conversa.';
      });
    }
  }

  void _jumpToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await PaperPlaneApi.instance.sendChatMessage(widget.conversationId, text);
      _message.clear();
      await _refresh(silent: true);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException
          ? error.message
          : 'Não foi possível enviar. Verifica a ligação e tenta novamente.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _block() async {
    final uid = _otherUid;
    if (uid == null || uid.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF172844),
        title: const Text('Bloquear copiloto?'),
        content: const Text('Deixarás de receber aviões e mensagens desta conta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB1A1), foregroundColor: _chatNavy),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await PaperPlaneApi.instance.blockPilot(uid);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiloto bloqueado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is PaperPlaneApiException ? error.message : 'Não foi possível bloquear.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chatNavy,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1B31),
        foregroundColor: _chatGoldBright,
        title: Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB36F)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            Text('@$_handle${_countryCode == null ? '' : ' · ${_countryFlag(_countryCode)} ${_countryName(_countryCode)}'}',
                style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ])),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _block();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'block', child: Text('Bloquear copiloto')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF263D66),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _chatGold.withOpacity(0.22)),
          ),
          child: const Row(children: [
            Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB36F), size: 26),
            SizedBox(width: 9),
            Expanded(child: Text(
              'Chama acesa: a conversa privada abriu depois da vossa troca de aviões.',
              style: TextStyle(fontSize: 11, height: 1.4, fontWeight: FontWeight.w700),
            )),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _chatGold))
              : _error != null && _messages.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
                      ]),
                    ))
                  : RefreshIndicator(
                      color: _chatGold,
                      onRefresh: _refresh,
                      child: ListView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                        children: [
                          if (_messages.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 50, horizontal: 18),
                              child: Text(
                                'A vossa primeira conversa começa aqui. Escreve algo simpático e mantém a Chama viva.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white60, height: 1.5),
                              ),
                            ),
                          for (final message in _messages) _messageBubble(message),
                        ],
                      ),
                    ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF101D33),
              border: Border(top: BorderSide(color: Color(0x33F0CE7C))),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _message,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enviar mensagem em papel…',
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF1B2A43),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _chatGold,
                child: IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _chatNavy))
                      : const Icon(Icons.send_rounded, color: _chatNavy),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final isOwn = message['sender_uid']?.toString() == FirebaseAuth.instance.currentUser?.uid;
    final content = message['message_text']?.toString() ?? '';
    final date = DateTime.tryParse(message['created_at']?.toString() ?? '');
    final time = date == null
        ? ''
        : '${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 8),
        decoration: BoxDecoration(
          color: isOwn ? const Color(0xFF3B5E98) : const Color(0xFF1A2B49),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(isOwn ? 17 : 4),
            bottomRight: Radius.circular(isOwn ? 4 : 17),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(content, style: const TextStyle(fontSize: 14, height: 1.42)),
          const SizedBox(height: 5),
          Text(time, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ]),
      ),
    );
  }

  String _countryName(String? code) {
    const names = {'MZ': 'Moçambique', 'JP': 'Japão', 'BR': 'Brasil', 'PT': 'Portugal', 'ZA': 'África do Sul', 'AO': 'Angola'};
    return names[code?.toUpperCase()] ?? (code ?? 'Mundo');
  }

  String _countryFlag(String? code) {
    if (code == null || code.length != 2) return '🌍';
    return String.fromCharCodes(code.toUpperCase().codeUnits.map((value) => value + 127397));
  }
}
