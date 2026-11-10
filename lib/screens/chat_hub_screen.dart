import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/paper_plane_localization.dart';
import 'package:flutter/services.dart';

import '../services/paper_plane_api.dart';
import '../widgets/chat_link_preview.dart';
import '../widgets/pilot_avatar.dart';
import '../widgets/report_dialog.dart';

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
  String _myLanguage = 'pt';
  static const Map<String, String> _languageNames = {
    'pt': 'Português',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
  };
  final TextEditingController _search = TextEditingController();
  Timer? _poller;
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _chamas = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 10), (_) => _refresh(silent: true));
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
        PaperPlaneApi.instance.getChamas(),
        PaperPlaneApi.instance.getFriends(),
        PaperPlaneApi.instance.getFriendRequests(),
        PaperPlaneApi.instance.getProfile(),
      ]);
      if (!mounted) return;
      final pilot = responses[4]['pilot'] as Map<String, dynamic>? ?? const {};
      final accepted = _items(responses[2], 'items');
      final friendRequests = _items(responses[3], 'incoming');
      final pending = _items(responses[2], 'incomingRequests');
      final incomingById = <String, Map<String, dynamic>>{
        for (final item in [...pending, ...friendRequests])
          item['id']?.toString() ?? '': item,
      }..remove('');
      setState(() {
        _chats = _items(responses[0], 'items');
        _chamas = _items(responses[1], 'items');
        _friends = accepted;
        _incoming = incomingById.values.toList();
        _outgoing = _items(responses[2], 'outgoing');
        _myHandle = pilot['pilot_handle']?.toString() ?? '';
        final savedLanguage = pilot['preferred_language']?.toString() ?? pilot['language']?.toString() ?? 'pt';
        _myLanguage = PaperPlaneLocale.supportedLanguages.contains(savedLanguage) ? savedLanguage : 'pt';
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

  Future<void> _deleteConversation(String id, {required bool chama, required String name}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF172844),
        title: const PlaneText('Eliminar conversa?'),
        content: PlaneText('A conversa com $name será removida da tua lista. A outra pessoa continuará a ter a sua cópia.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const PlaneText('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _chatGold, foregroundColor: _chatNavy),
            child: const PlaneText('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PaperPlaneApi.instance.deleteConversation(id, chama: chama);
      await _refresh(silent: true);
      _notice('Conversa removida da tua lista.');
    } catch (error) {
      _notice(error is PaperPlaneApiException ? error.message : 'Não foi possível eliminar a conversa.');
    }
  }

  Future<void> _removeFriend(String uid, String handle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF172844),
        title: const PlaneText('Remover amigo?'),
        content: PlaneText('Queres remover @$handle da tua lista de amigos? A conversa Chama não será apagada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const PlaneText('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _chatGold, foregroundColor: _chatNavy),
            child: const PlaneText('Remover'),
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

  Future<void> _changeLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF142541),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          children: [
            const PlaneText('Idioma preferido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const PlaneText('Os aviões recebidos serão traduzidos para este idioma.', style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 10),
            for (final entry in _languageNames.entries)
              ListTile(
                leading: Icon(_myLanguage == entry.key ? Icons.check_circle_rounded : Icons.language_rounded,
                    color: _myLanguage == entry.key ? _chatGoldBright : Colors.white54),
                title: PlaneText(entry.value),
                onTap: () => Navigator.pop(sheetContext, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == _myLanguage) return;
    try {
      await PaperPlaneApi.instance.updateLanguagePreference(selected);
      if (!mounted) return;
      setState(() => _myLanguage = selected);
      PaperPlaneLocale.setLanguage(selected);
      _notice('Idioma alterado para ${_languageNames[selected]}.');
      await _refresh(silent: true);
    } catch (error) {
      _notice(error is PaperPlaneApiException ? error.message : 'Não foi possível alterar o idioma.');
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
      SnackBar(content: PlaneText(message), behavior: SnackBarBehavior.floating),
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
                      PlaneText('Chat & Amigos', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                      PlaneText('Liga-te a copilotos de todo o mundo', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _copyInvite,
                  tooltip: PaperPlaneLocale.translate('Copiar link de convite'),
                  icon: const Icon(Icons.link_rounded, color: _chatGoldBright),
                ),
                IconButton(
                  onPressed: _changeLanguage,
                  tooltip: PaperPlaneLocale.translate('Idioma: ${_languageNames[_myLanguage] ?? _myLanguage}'),
                  icon: const Icon(Icons.translate_rounded, color: _chatGoldBright),
                ),
                IconButton(
                  onPressed: () => _refresh(),
                  tooltip: PaperPlaneLocale.translate('Atualizar'),
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
                const SizedBox(width: 6),
                Expanded(child: _sectionChip(1, 'Chat', Icons.chat_bubble_outline_rounded)),
                const SizedBox(width: 6),
                Expanded(child: _sectionChip(2, 'Amigos', Icons.people_alt_outlined)),
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
                              PlaneText(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const PlaneText('Tentar novamente')),
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
                          children: _section == 0 ? _buildFlames() : _section == 1 ? _buildChats() : _buildFriends(),
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
            PlaneText(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? _chatGoldBright : Colors.white70)),
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
        body: 'A Chama só acende quando a resposta em avião chega ao remetente original. Os dois aviões ficam no início da conversa e o Chat permanece separado.',
        highlight: true,
      ),
      const SizedBox(height: 15),
      _sectionTitle('As tuas Chamas', _chamas.length.toString()),
      if (_chamas.isEmpty)
        _emptyPanel(
          icon: Icons.flight_takeoff_rounded,
          title: 'Ainda não tens uma Chama acesa',
          body: 'Quando alguém te responde com um avião e essa resposta é entregue, a Chama abre automaticamente. Não é preciso adicionar a pessoa primeiro.',
        )
      else
        for (final chama in _chamas) ...[
          const SizedBox(height: 9),
          _chatTile(chama, chama: true),
        ],
      const SizedBox(height: 12),
      _infoPanel(
        icon: Icons.public_rounded,
        title: 'Amigos pelo mundo',
        body: 'Podes adicionar amigos por @nome ou enviar o teu link de convite. A Chama nasce da troca de aviões; depois disso, a conversa fica sempre disponível nesta lista.',
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => setState(() => _section = 2),
        icon: const Icon(Icons.people_alt_outlined),
        label: const PlaneText('Explorar amigos do mundo'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _chatGoldBright,
          side: BorderSide(color: _chatGold.withOpacity(0.55)),
          minimumSize: const Size.fromHeight(49),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    ];
  }

  List<Widget> _buildChats() {
    return [
      _infoPanel(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chat privado',
        body: 'Esta área é independente das Chamas. Abre um Chat com um amigo aceite, mesmo antes de trocarem aviões.',
        highlight: true,
      ),
      const SizedBox(height: 14),
      _sectionTitle('As tuas conversas', _chats.length.toString()),
      if (_chats.isEmpty)
        _emptyPanel(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Ainda não tens Chats',
          body: 'Vai a Amigos, procura um copiloto e abre um Chat depois de aceitarem o pedido de amizade.',
        )
      else
        for (final chat in _chats) ...[
          const SizedBox(height: 9),
          _chatTile(chat),
        ],
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () => setState(() => _section = 2),
        icon: const Icon(Icons.people_alt_outlined),
        label: const PlaneText('Encontrar amigos'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _chatGoldBright,
          side: BorderSide(color: _chatGold.withOpacity(0.55)),
          minimumSize: const Size.fromHeight(49),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    ];
  }

  Future<void> _openPrivateChat(Map<String, dynamic> friend) async {
    final uid = friend['uid']?.toString() ?? '';
    if (uid.isEmpty) return;
    try {
      final result = await PaperPlaneApi.instance.createChat(uid);
      if (!mounted) return;
      final conversation = result['conversation'] as Map<String, dynamic>? ?? const {};
      final id = conversation['id']?.toString() ?? '';
      if (id.isEmpty) {
        _notice('Não foi possível abrir o Chat.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChamaConversationScreen(
            conversationId: id,
            fallbackName: friend['pilot_name']?.toString() ?? 'Copiloto',
            fallbackHandle: friend['pilot_handle']?.toString() ?? 'piloto',
            fallbackCountry: friend['country_code']?.toString(),
            isChama: false,
          ),
        ),
      );
      await _refresh(silent: true);
    } catch (error) {
      if (!mounted) return;
      _notice(error is PaperPlaneApiException ? error.message : 'Não foi possível abrir o Chat.');
    }
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
                hintText: PaperPlaneLocale.translate('Pesquisar @nome_de_copiloto'),
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
            action: 'Abrir Chat',
            onTap: () => _openPrivateChat(friend),
            secondaryAction: 'Remover',
            secondaryTap: () => _removeFriend(
              friend['uid']?.toString() ?? '',
              friend['pilot_handle']?.toString() ?? 'copiloto',
            ),
            actionColor: _chatGoldBright,
          ),
        ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _copyInvite,
        icon: const Icon(Icons.link_rounded),
        label: const PlaneText('Copiar o meu link de convite'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _chatGoldBright,
          side: BorderSide(color: _chatGold.withOpacity(0.55)),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    ];
  }

  Widget _chatTile(Map<String, dynamic> chat, {bool chama = false}) {
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
                    isChama: chama,
                  ),
                ),
              ),
      borderRadius: BorderRadius.circular(18),
      child: _panel(
        highlight: true,
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PilotAvatar(url: chat['avatar_url']?.toString(), size: 52),
                if (chama)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFF263D66), shape: BoxShape.circle),
                      child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB66E), size: 15),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                PlaneText(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 3),
                PlaneText('@$handle${country == null ? '' : ' · ${_flag(country)} ${_country(country)}'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 5),
                PlaneText(last?.isNotEmpty == true ? last! : (chama ? 'A Chama está acesa. Continuem a trocar aviões.' : 'O vosso Chat está pronto.'),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _chatGoldBright, fontSize: 12)),
                if (chama) ...[
                  const SizedBox(height: 4),
                  PlaneText(
                    '${chat['plane_count'] ?? 0} aviões · ${chat['exchange_count'] ?? 0} respostas',
                    style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ],
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: PaperPlaneLocale.translate('Opções da conversa'),
              onSelected: (value) {
                if (value == 'delete' && conversationId.isNotEmpty) {
                  _deleteConversation(conversationId, chama: chama, name: name);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18),
                  SizedBox(width: 8),
                  PlaneText('Eliminar conversa'),
                ])),
              ],
              icon: const Icon(Icons.more_vert_rounded, color: _chatGold),
            ),
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
          PlaneText(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          PlaneText('@$handle${country == null ? '' : ' · ${_flag(country)} ${_country(country)}'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ])),
        IconButton(
          tooltip: PaperPlaneLocale.translate('Aceitar'),
          onPressed: id.isEmpty ? null : () => _respond(id, true),
          icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF8EE0B1)),
        ),
        IconButton(
          tooltip: PaperPlaneLocale.translate('Recusar'),
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
    String? secondaryAction,
    VoidCallback? secondaryTap,
  }) {
    final name = person['pilot_name']?.toString() ?? 'Copiloto';
    final handle = person['pilot_handle']?.toString() ?? 'piloto';
    final country = person['country_code']?.toString();
    return _panel(
      child: Row(children: [
        PilotAvatar(url: person['avatar_url']?.toString(), size: 42),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlaneText(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          PlaneText('@$handle${country == null ? '' : ' · ${_flag(country)} ${_country(country)}'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ])),
        if (secondaryAction != null)
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white60),
            onSelected: (_) => secondaryTap?.call(),
            itemBuilder: (_) => [PopupMenuItem(value: 'secondary', child: PlaneText(secondaryAction))],
          ),
        TextButton(
          onPressed: onTap,
          child: PlaneText(action, style: TextStyle(color: actionColor, fontWeight: FontWeight.w800, fontSize: 10)),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String title, String count) => Row(children: [
        Expanded(child: PlaneText(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
        PlaneText(count, style: const TextStyle(color: _chatGoldBright, fontWeight: FontWeight.w800)),
      ]);

  Widget _infoPanel({required IconData icon, required String title, required String body, bool highlight = false}) =>
      _panel(
        highlight: highlight,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _chatGoldBright, size: 28),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlaneText(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 6),
            PlaneText(body, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
          ])),
        ]),
      );

  Widget _emptyPanel({required IconData icon, required String title, required String body}) =>
      _panel(
        child: Column(children: [
          Icon(icon, color: _chatGoldBright, size: 32),
          const SizedBox(height: 8),
          PlaneText(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          PlaneText(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.45)),
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
    this.isChama = true,
  });

  final String conversationId;
  final String fallbackName;
  final String fallbackHandle;
  final String? fallbackCountry;
  final bool isChama;

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
  String? _avatarUrl;
  String? _otherUid;
  bool _chamaEnded = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];
  String _myLanguage = 'pt';
  static const Map<String, String> _chatLanguageNames = {
    'pt': 'Português',
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
  };
  final Map<String, String> _translatedMessages = {};
  final Set<String> _translatingMessages = {};
  Map<String, dynamic>? _chamaStats;
  List<Map<String, dynamic>> _chamaHistory = [];

  @override
  void initState() {
    super.initState();
    _name = widget.fallbackName;
    _handle = widget.fallbackHandle;
    _countryCode = widget.fallbackCountry;
    _loadPreferredLanguage();
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 4), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadPreferredLanguage() async {
    try {
      final data = await PaperPlaneApi.instance.getProfile();
      final pilot = data['pilot'] as Map<String, dynamic>? ?? const {};
      if (!mounted) return;
      final savedLanguage = pilot['preferred_language']?.toString() ?? pilot['language']?.toString() ?? 'pt';
      setState(() => _myLanguage =
          PaperPlaneLocale.supportedLanguages.contains(savedLanguage) ? savedLanguage : 'pt');
    } catch (_) {
      // Keep the conversation usable with Portuguese as the fallback.
    }
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
      final chamaData = data['chama'] is Map
          ? Map<String, dynamic>.from(data['chama'] as Map)
          : null;
      final history = (chamaData?['history'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      final hadNewMessages = messages.length > _messages.length;
      final wasNearBottom = !_scroll.hasClients ||
          _scroll.position.maxScrollExtent - _scroll.position.pixels < 90;
      setState(() {
        _name = conversation['pilot_name']?.toString() ?? _name;
        _handle = conversation['pilot_handle']?.toString() ?? _handle;
        _countryCode = conversation['country_code']?.toString() ?? _countryCode;
        _avatarUrl = conversation['avatar_url']?.toString() ?? _avatarUrl;
        _otherUid = conversation['other_uid']?.toString();
        _chamaEnded = conversation['ended_at'] != null;
        _messages = messages;
        _chamaStats = chamaData;
        _chamaHistory = history;
        _loading = false;
        _error = null;
      });
      if (messages.isNotEmpty && (! _scroll.hasClients || (hadNewMessages && wasNearBottom))) {
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


  Widget _chamaOverview() {
    final stats = _chamaStats ?? const <String, dynamic>{};
    final planes = int.tryParse(stats['planeCount']?.toString() ?? '') ?? 0;
    final exchanges = int.tryParse(stats['exchangeCount']?.toString() ?? '') ?? 0;
    final streak = int.tryParse(stats['streak']?.toString() ?? '') ?? 0;
    final last = DateTime.tryParse(stats['lastExchangeAt']?.toString() ?? '');
    final expiry = DateTime.tryParse(stats['expiresAt']?.toString() ?? '');
    final ended = _chamaEnded || stats['endedAt'] != null;
    final daysLeft = expiry == null ? 7 : expiry.difference(DateTime.now()).inHours <= 0
        ? 0 : (expiry.difference(DateTime.now()).inHours / 24).ceil();
    final lastLabel = last == null
        ? 'Ainda sem nova troca'
        : 'Última troca · ${last.toLocal().day.toString().padLeft(2, '0')}/${last.toLocal().month.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF263D66),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _chatGold.withOpacity(0.38)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB36F), size: 21),
          SizedBox(width: 7),
          PlaneText('A Chama do Deserto', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          Spacer(),
          PlaneText(ended ? 'ENCERRADA' : 'ACTIVA', style: TextStyle(color: ended ? Colors.white54 : _chatGoldBright, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _flameMetric(Icons.flight_rounded, planes.toString(), 'Aviões'),
          _flameMetric(Icons.swap_horiz_rounded, exchanges.toString(), 'Respostas'),
          _flameMetric(Icons.local_fire_department_rounded, streak.toString(), 'Dias seguidos'),
        ]),
        const SizedBox(height: 7),
        PlaneText(lastLabel, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ended ? Colors.white.withOpacity(0.06) : (daysLeft <= 2 ? const Color(0xFF754B42) : const Color(0xFF172844)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ended ? Colors.white12 : _chatGold.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(ended ? Icons.do_not_disturb_on_outlined : Icons.hourglass_bottom_rounded,
                color: ended ? Colors.white54 : _chatGoldBright, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: PlaneText(
                ended
                    ? 'Esta rota foi encerrada. O histórico permanece guardado.'
                    : daysLeft <= 0
                        ? 'A Chama está sem actividade e vai expirar.'
                        : daysLeft <= 2
                            ? 'A chama está a enfraquecer. Responde antes de apagar!'
                            : 'Chama apaga em $daysLeft dias sem resposta.',
                style: TextStyle(color: ended ? Colors.white60 : _chatGoldBright, fontSize: 10, height: 1.35, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _flameMetric(IconData icon, String value, String label) => Expanded(
    child: Column(children: [
      Icon(icon, color: _chatGoldBright, size: 17),
      const SizedBox(height: 3),
      PlaneText(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      PlaneText(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
    ]),
  );

  Widget _chamaHistoryPanel() => Container(
    margin: const EdgeInsets.only(bottom: 13),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF172844),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _chatGold.withOpacity(0.22)),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        iconColor: _chatGoldBright,
        collapsedIconColor: _chatGoldBright,
        title: const PlaneText('Histórico dos aviões', style: TextStyle(color: _chatGoldBright, fontWeight: FontWeight.w800, fontSize: 11)),
        subtitle: PlaneText('${_chamaHistory.length} aviões nesta Chama', style: const TextStyle(color: Colors.white54, fontSize: 9)),
        children: [
          for (final plane in _chamaHistory.reversed.take(12)) _chamaHistoryTile(plane),
        ],
      ),
    ),
  );

  Widget _chamaHistoryTile(Map<String, dynamic> plane) {
    final own = plane['sender_uid']?.toString() == FirebaseAuth.instance.currentUser?.uid;
    final date = DateTime.tryParse(plane['created_at']?.toString() ?? '');
    final time = date == null ? '' :
        '${date.toLocal().day.toString().padLeft(2, '0')}/${date.toLocal().month.toString().padLeft(2, '0')} · ${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), borderRadius: BorderRadius.circular(11)),
      child: Row(children: [
        Icon(own ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded, color: _chatGoldBright, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlaneText(own ? 'O teu avião' : 'Avião recebido', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _chatGoldBright)),
          PlaneText(plane['message_text']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ])),
        const SizedBox(width: 7),
        PlaneText(time, style: const TextStyle(fontSize: 8, color: Colors.white38)),
      ]),
    );
  }

  void _jumpToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _insertChatEmoji(String emoji) {
    final value = _message.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final next = value.text.replaceRange(selection.start, selection.end, emoji);
    final limit = widget.isChama ? 200 : 1000;
    if (next.runes.length > limit) return;
    _message.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: selection.start + emoji.length),
    );
  }

  Future<void> _openEmojiPicker() async {
    const emojis = ['😊', '😂', '🥹', '❤️', '💌', '🌍', '🌸', '✨', '🌙', '🙏', '🤝', '🕊️'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF142541),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 12,
            children: emojis.map((emoji) => InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(sheetContext, emoji),
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF203958),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _chatGold.withOpacity(0.2)),
                ),
                child: PlaneText(emoji, style: const TextStyle(fontSize: 25)),
              ),
            )).toList(),
          ),
        ),
      ),
    );
    if (selected != null) _insertChatEmoji(selected);
  }

  Future<void> _translateMessage(Map<String, dynamic> message) async {
    final id = message['id']?.toString() ?? '';
    if (id.isEmpty) return;
    if (_translatedMessages.containsKey(id)) {
      setState(() => _translatedMessages.remove(id));
      return;
    }
    if (_translatingMessages.contains(id)) return;
    setState(() => _translatingMessages.add(id));
    try {
      final result = id.startsWith('plane:')
          ? await PaperPlaneApi.instance.translatePlane(id.substring(6), _myLanguage)
          : await PaperPlaneApi.instance.translateChatMessage(widget.conversationId, id, _myLanguage);
      final translated = result['text']?.toString();
      if (translated == null || translated.isEmpty) {
        throw const PaperPlaneApiException('TRANSLATION_UNAVAILABLE', 'Não foi possível traduzir esta mensagem.');
      }
      if (!mounted) return;
      setState(() => _translatedMessages[id] = translated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: PlaneText(error is PaperPlaneApiException ? error.message : 'A tradução não está disponível neste momento.'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _translatingMessages.remove(id));
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (widget.isChama) {
        if (_chamaEnded) throw const PaperPlaneApiException('CHAMA_ENDED', 'Esta Chama foi encerrada.');
        final myUid = FirebaseAuth.instance.currentUser?.uid;
        Map<String, dynamic>? incoming;
        for (final plane in _chamaHistory.reversed) {
          final isMineToReceive = plane['recipient_uid']?.toString() == myUid;
          final status = plane['status']?.toString();
          if (isMineToReceive && (status == 'DELIVERED' || status == 'READ')) {
            incoming = plane;
            break;
          }
        }
        final planeId = incoming?['id']?.toString() ?? '';
        if (planeId.isEmpty) {
          throw const PaperPlaneApiException(
            'REPLY_NOT_ALLOWED',
            'Aguarda o avião da outra pessoa chegar. Depois podes lançar a tua resposta.',
          );
        }
        await PaperPlaneApi.instance.replyToPlane(
          planeId,
          message: text,
          language: _myLanguage,
          allowReply: true,
        );
      } else {
        await PaperPlaneApi.instance.sendChatMessage(widget.conversationId, text, language: _myLanguage);
      }
      _message.clear();
      await _refresh(silent: true);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToEnd());
      if (widget.isChama && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: PlaneText('A tua resposta está a voar pela rota da Chama — 3× mais rápida.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException
          ? error.message
          : 'Não foi possível enviar. Verifica a ligação e tenta novamente.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: PlaneText(message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reportLatestPlane() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    Map<String, dynamic>? latest;
    for (final plane in _chamaHistory.reversed) {
      if (plane['sender_uid']?.toString() != myUid) {
        latest = plane;
        break;
      }
    }
    final planeId = latest?['id']?.toString() ?? '';
    if (planeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: PlaneText('Ainda não há aviões nesta Chama para denunciar.')),
      );
      return;
    }
    await showReportDialog(context, planeId);
  }

  Future<void> _endChama() async {
    if (_chamaEnded) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF172844),
        title: const PlaneText('Encerrar esta Chama?'),
        content: const PlaneText('A troca de aviões nesta rota será encerrada. O histórico ficará guardado para consulta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const PlaneText('Continuar Chama')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC47A), foregroundColor: _chatNavy),
            child: const PlaneText('Encerrar rota'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await PaperPlaneApi.instance.endChama(widget.conversationId);
      if (!mounted) return;
      setState(() => _chamaEnded = true);
      await _refresh(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: PlaneText('Rota encerrada. O histórico continua disponível.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: PlaneText(error is PaperPlaneApiException ? error.message : 'Não foi possível encerrar a rota.')),
      );
    }
  }

  Future<void> _block() async {
    final uid = _otherUid;
    if (uid == null || uid.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF172844),
        title: const PlaneText('Bloquear copiloto?'),
        content: const PlaneText('Deixarás de receber aviões e mensagens desta conta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const PlaneText('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFB1A1), foregroundColor: _chatNavy),
            child: const PlaneText('Bloquear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await PaperPlaneApi.instance.blockPilot(uid);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: PlaneText('Copiloto bloqueado.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: PlaneText(error is PaperPlaneApiException ? error.message : 'Não foi possível bloquear.')),
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
          if (_avatarUrl?.isNotEmpty == true)
            PilotAvatar(url: _avatarUrl, size: 36)
          else
            Icon(widget.isChama ? Icons.local_fire_department_rounded : Icons.chat_bubble_rounded,
                color: widget.isChama ? const Color(0xFFFFB36F) : _chatGoldBright),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlaneText(_name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            PlaneText('@$_handle${_countryCode == null ? '' : ' · ${_countryFlag(_countryCode)} ${_countryName(_countryCode)}'}',
                style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ])),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'block') _block();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'block', child: PlaneText('Bloquear copiloto')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        if (widget.isChama && _chamaStats != null) _chamaOverview(),
        if (widget.isChama) Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 7),
          child: Row(children: [
            Expanded(child: _conversationAction(
              icon: Icons.flag_outlined,
              label: 'Denunciar',
              onTap: _reportLatestPlane,
            )),
            const SizedBox(width: 6),
            Expanded(child: _conversationAction(
              icon: Icons.shield_outlined,
              label: 'Bloquear',
              onTap: _block,
            )),
            const SizedBox(width: 6),
            Expanded(child: _conversationAction(
              icon: Icons.route_outlined,
              label: _chamaEnded ? 'Encerrada' : 'Encerrar rota',
              onTap: _chamaEnded ? null : _endChama,
              emphasis: true,
            )),
          ]),
        ),
        if (!widget.isChama) Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF263D66),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _chatGold.withOpacity(0.22)),
          ),
          child: const Row(children: [
            Icon(Icons.chat_bubble_outline_rounded, color: _chatGoldBright, size: 24),
            SizedBox(width: 9),
            Expanded(child: PlaneText(
              'Chat privado: esta conversa é independente da troca de aviões.',
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
                        PlaneText(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const PlaneText('Tentar novamente')),
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
                          if (widget.isChama && _chamaHistory.isNotEmpty) _chamaHistoryPanel(),
                          if (_messages.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 50, horizontal: 18),
                              child: PlaneText(
                                widget.isChama
                                    ? 'A vossa primeira conversa começa aqui. Escreve algo simpático e mantém a Chama viva.'
                                    : 'Este é o vosso espaço privado. Comecem a conversar quando quiserem.',
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
              IconButton(
                onPressed: widget.isChama && _chamaEnded ? null : _openEmojiPicker,
                tooltip: PaperPlaneLocale.translate('Adicionar emoji'),
                icon: const Icon(Icons.emoji_emotions_outlined, color: _chatGoldBright),
              ),
              Expanded(
                child: TextField(
                  controller: _message,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: widget.isChama ? 200 : 1000,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: PaperPlaneLocale.translate(widget.isChama ? (_chamaEnded ? 'Chama encerrada' : 'Enviar próximo avião…') : 'Mensagem instantânea…'),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFF1B2A43),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _send(),
                  enabled: !widget.isChama || !_chamaEnded,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _chatGold,
                child: IconButton(
                  onPressed: _sending || (widget.isChama && _chamaEnded) ? null : _send,
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

  Widget _conversationAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool emphasis = false,
  }) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: PlaneText(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: emphasis ? _chatGoldBright : Colors.white70,
          side: BorderSide(color: emphasis ? _chatGold.withOpacity(0.5) : Colors.white12),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      );

  Widget _messageBubble(Map<String, dynamic> message) {
    final isOwn = message['sender_uid']?.toString() == FirebaseAuth.instance.currentUser?.uid;
    final isOpeningPlane = message['id']?.toString().startsWith('plane:') == true;
    final original = message['message_text']?.toString() ?? '';
    final content = _translatedMessages[message['id']?.toString()] ?? original;
    final isTranslating = _translatingMessages.contains(message['id']?.toString());
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
          border: Border.all(color: isOpeningPlane ? _chatGold.withOpacity(0.55) : Colors.white.withOpacity(0.1)),
          boxShadow: isOpeningPlane ? [BoxShadow(color: _chatGold.withOpacity(0.08), blurRadius: 12)] : const [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (widget.isChama && isOpeningPlane) ...[
            Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.local_fire_department_rounded, color: _chatGoldBright, size: 13),
              SizedBox(width: 5),
              PlaneText('INÍCIO DA CHAMA', style: TextStyle(color: _chatGoldBright, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
            ]),
            const SizedBox(height: 6),
          ],
          if (widget.isChama) ...[
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.send_rounded, color: _chatGoldBright.withOpacity(0.9), size: 12),
              const SizedBox(width: 5),
              PlaneText(isOwn ? 'AVIÃO ENVIADO' : 'AVIÃO RECEBIDO',
                  style: const TextStyle(color: _chatGoldBright, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
            ]),
            const SizedBox(height: 6),
          ],
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.97, end: 1),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) => Opacity(
              opacity: scale.clamp(0.0, 1.0).toDouble(),
              child: Transform.scale(scale: scale, alignment: Alignment.topLeft, child: child),
            ),
            child: PlaneText(content, style: const TextStyle(fontSize: 14, height: 1.42)),
          ),
          if (content != original)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _translateMessage(message),
                icon: const Icon(Icons.visibility_outlined, size: 13),
                label: const PlaneText('Ver original', style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(foregroundColor: _chatGoldBright, padding: EdgeInsets.zero),
              ),
            )
          else if (!isOwn)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isTranslating ? null : () => _translateMessage(message),
                icon: isTranslating
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.8))
                    : const Icon(Icons.translate_rounded, size: 13),
                label: PlaneText(isTranslating ? 'A traduzir…' : 'Traduzir para ${_chatLanguageNames[_myLanguage] ?? _myLanguage}',
                    style: const TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(foregroundColor: _chatGoldBright, padding: EdgeInsets.zero),
              ),
            ),
          ChatLinkPreview(key: ValueKey(message['id']?.toString() ?? content), message: content),
          const SizedBox(height: 5),
          Row(mainAxisSize: MainAxisSize.min, children: [
            PlaneText(time, style: const TextStyle(color: Colors.white54, fontSize: 9)),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 27, height: 25),
              padding: EdgeInsets.zero,
              tooltip: PaperPlaneLocale.translate('Copiar mensagem'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: original));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: PlaneText('Mensagem copiada.'), behavior: SnackBarBehavior.floating),
                );
              },
              icon: const Icon(Icons.copy_rounded, color: Colors.white54, size: 12),
            ),
            if (isOwn && !widget.isChama) ...[
              const SizedBox(width: 6),
              Icon(
                message['read_at'] == null ? Icons.done_rounded : Icons.done_all_rounded,
                size: 13,
                color: message['read_at'] == null ? Colors.white54 : const Color(0xFF8BE0FF),
              ),
              const SizedBox(width: 3),
              PlaneText(
                message['read_at'] == null ? 'Enviada' : 'Lida',
                style: TextStyle(fontSize: 8, color: message['read_at'] == null ? Colors.white54 : const Color(0xFF8BE0FF)),
              ),
            ],
          ]),
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
