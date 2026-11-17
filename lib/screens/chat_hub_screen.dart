import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/paper_plane_localization.dart';
import 'package:flutter/services.dart';

import '../services/paper_plane_api.dart';
import '../widgets/chat_link_preview.dart';
import '../widgets/pilot_avatar.dart';
import '../widgets/report_dialog.dart';

const Color _chatNavy = Color(0xFF050B19);
const Color _chatGold = Color(0xFF42D9FF);
const Color _chatGoldBright = Color(0xFFB8F1FF);
const Color _chatPanel = Color(0xDD0E203B);

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key, required this.onExplore});
  final VoidCallback onExplore;

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  int _filter = 0;
  bool _loading = true;
  bool _searchOpen = false;
  bool _searching = false;
  String? _error;
  String _myHandle = '';
  String _myLanguage = 'pt';
  final TextEditingController _search = TextEditingController();
  Timer? _poller;
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _chamas = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _searchResults = [];
  final Map<String, String> _translatedPreviews = {};
  final Set<String> _translatingPreviews = {};

  @override
  void initState() {
    super.initState();
    _myLanguage = PaperPlaneLocale.current.value.languageCode;
    PaperPlaneLocale.current.addListener(_onLocaleChanged);
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 12), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refresh(silent: true);
      }
    });
  }

  void _onLocaleChanged() {
    final next = PaperPlaneLocale.current.value.languageCode;
    if (!mounted || next == _myLanguage) return;
    setState(() {
      _myLanguage = next;
      _translatedPreviews.clear();
      _translatingPreviews.clear();
    });
    _translateConversationPreviews();
  }

  @override
  void dispose() {
    _poller?.cancel();
    PaperPlaneLocale.current.removeListener(_onLocaleChanged);
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data, String key) =>
      (data[key] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  List<Map<String, dynamic>> get _conversations {
    final rows = <Map<String, dynamic>>[
      ..._chats.map((item) => {...item, 'kind': 'CHAT'}),
      ..._chamas.map((item) => {...item, 'kind': 'CHAMA'}),
    ];
    rows.sort((a, b) {
      final aDate = DateTime.tryParse(a['last_message_at']?.toString() ??
          a['last_plane_at']?.toString() ?? a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['last_message_at']?.toString() ??
          b['last_plane_at']?.toString() ?? b['created_at']?.toString() ?? '');
      return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
    });
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((item) {
      final name = (item['pilot_name']?.toString() ?? '').toLowerCase();
      final handle = (item['pilot_handle']?.toString() ?? '').toLowerCase();
      final message = (item['last_message']?.toString() ?? '').toLowerCase();
      return name.contains(query) || handle.contains(query) || message.contains(query);
    }).toList();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() { _loading = true; _error = null; });
    try {
      final responses = await Future.wait([
        PaperPlaneApi.instance.getChats(),
        PaperPlaneApi.instance.getChamas(),
        PaperPlaneApi.instance.getFriends(),
        PaperPlaneApi.instance.getFriendRequests(),
        PaperPlaneApi.instance.getProfile(),
      ]);
      final pilot = responses[4]['pilot'] as Map<String, dynamic>? ?? const {};
      final savedLanguage = pilot['preferred_language']?.toString() ??
          pilot['language']?.toString() ??
          PaperPlaneLocale.current.value.languageCode;
      if (!mounted) return;
      setState(() {
        _chats = _items(responses[0], 'items');
        _chamas = _items(responses[1], 'items');
        _friends = _items(responses[2], 'items');
        _requests = _items(responses[3], 'incoming');
        _myHandle = pilot['pilot_handle']?.toString() ?? '';
        _myLanguage = PaperPlaneLocale.supportedLanguages.contains(savedLanguage)
            ? savedLanguage
            : PaperPlaneLocale.current.value.languageCode;
        _loading = false;
        _error = null;
      });
      _translateConversationPreviews();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PaperPlaneApiException
            ? error.message
            : PaperPlaneLocale.translate('Não foi possível carregar as conversas.');
      });
    }
  }

  Future<void> _translateConversationPreviews() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final ids = _chats
        .where((chat) =>
            chat['last_message_id'] != null &&
            chat['last_message_sender_uid']?.toString() != myUid &&
            (chat['last_message_language_tag']?.toString().split('-').first ?? 'pt') != _myLanguage)
        .map((chat) => chat['last_message_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty && !_translatedPreviews.containsKey(id) && !_translatingPreviews.contains(id))
        .take(20)
        .toList();
    if (ids.isEmpty) return;
    setState(() => _translatingPreviews.addAll(ids));
    try {
      final result = await PaperPlaneApi.instance.translateChatMessages('inbox', ids, _myLanguage);
      final items = _items(result, 'items');
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          final id = item['id']?.toString() ?? '';
          final text = item['text']?.toString() ?? '';
          if (id.isNotEmpty && text.isNotEmpty) _translatedPreviews[id] = text;
        }
      });
    } catch (_) {
      // Keep the source preview visible when automatic translation is unavailable.
    } finally {
      if (mounted) setState(() => _translatingPreviews.removeAll(ids));
    }
  }

  Future<void> _searchPilots() async {
    final query = _search.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (query.length < 2) {
      _notice(PaperPlaneLocale.translate('Escreve pelo menos duas letras do nome de copiloto.'));
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await PaperPlaneApi.instance.searchFriends(query);
      if (!mounted) return;
      setState(() => _searchResults = _items(result, 'items'));
      if (_searchResults.isEmpty) _notice(PaperPlaneLocale.translate('Não encontrámos copilotos com esse nome.'));
    } catch (error) {
      if (!mounted) return;
      _notice(error is PaperPlaneApiException ? error.message : PaperPlaneLocale.translate('A pesquisa falhou. Tenta novamente.'));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFriend(String handle) async {
    try {
      final result = await PaperPlaneApi.instance.requestFriend(handle);
      if (!mounted) return;
      _notice(PaperPlaneLocale.translate(
        result['status']?.toString() == 'ACCEPTED' ? 'Amizade confirmada.' : 'Pedido de amizade enviado.',
      ));
      await _refresh(silent: true);
      if (_search.text.trim().length >= 2) await _searchPilots();
    } catch (error) {
      if (!mounted) return;
      _notice(error is PaperPlaneApiException ? error.message : PaperPlaneLocale.translate('Não foi possível enviar o pedido.'));
    }
  }

  Future<void> _respond(String id, bool accept) async {
    try {
      await PaperPlaneApi.instance.respondFriendRequest(id, accept: accept);
      if (!mounted) return;
      _notice(PaperPlaneLocale.translate(accept ? 'Pedido aceite.' : 'Pedido recusado.'));
      await _refresh(silent: true);
    } catch (error) {
      if (!mounted) return;
      _notice(error is PaperPlaneApiException ? error.message : PaperPlaneLocale.translate('Não foi possível atualizar o pedido.'));
    }
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
        _notice(PaperPlaneLocale.translate('Não foi possível abrir a conversa.'));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChamaConversationScreen(
          conversationId: id,
          fallbackName: friend['pilot_name']?.toString() ?? 'Copiloto',
          fallbackHandle: friend['pilot_handle']?.toString() ?? 'piloto',
          fallbackCountry: friend['country_code']?.toString(),
          fallbackAvatarUrl: friend['avatar_url']?.toString(),
          isChama: false,
        ),
      ));
      await _refresh(silent: true);
    } catch (error) {
      if (!mounted) return;
      _notice(error is PaperPlaneApiException ? error.message : PaperPlaneLocale.translate('Não foi possível abrir a conversa.'));
    }
  }

  void _openConversation(Map<String, dynamic> item) {
    final id = item['conversation_id']?.toString() ?? '';
    if (id.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChamaConversationScreen(
        conversationId: id,
        fallbackName: item['pilot_name']?.toString() ?? 'Copiloto',
        fallbackHandle: item['pilot_handle']?.toString() ?? 'piloto',
        fallbackCountry: item['country_code']?.toString(),
        fallbackAvatarUrl: item['avatar_url']?.toString(),
        isChama: item['kind']?.toString() == 'CHAMA',
      ),
    )).then((_) => _refresh(silent: true));
  }

  Future<void> _deleteConversation(Map<String, dynamic> item) async {
    final id = item['conversation_id']?.toString() ?? '';
    if (id.isEmpty) return;
    final name = item['pilot_name']?.toString() ?? 'Copiloto';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF10213E),
        title: PlaneText('Eliminar conversa?'),
        content: PlaneText(PaperPlaneLocale.translate('A conversa com ') + name + PaperPlaneLocale.translate(' será removida da tua lista.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: PlaneText('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF668C)),
            child: PlaneText('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PaperPlaneApi.instance.deleteConversation(id, chama: item['kind']?.toString() == 'CHAMA');
      await _refresh(silent: true);
    } catch (error) {
      _notice(error is PaperPlaneApiException ? error.message : PaperPlaneLocale.translate('Não foi possível eliminar a conversa.'));
    }
  }

  Future<void> _removeFriend(Map<String, dynamic> friend) async {
    final uid = friend['uid']?.toString() ?? '';
    final handle = friend['pilot_handle']?.toString() ?? '';
    if (uid.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF10213E),
        title: PlaneText('Remover amigo?'),
        content: PlaneText(PaperPlaneLocale.translate('Queres remover ') + '@' + handle + PaperPlaneLocale.translate(' da tua lista de amigos?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: PlaneText('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF668C)),
            child: PlaneText('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await PaperPlaneApi.instance.removeFriend(uid);
      await _refresh(silent: true);
    } catch (error) {
      _notice(error is PaperPlaneApiException ? error.message : PaperPlaneLocale.translate('Não foi possível remover o amigo.'));
    }
  }

  Future<void> _copyInvite() async {
    if (_myHandle.isEmpty) {
      _notice(PaperPlaneLocale.translate('Completa primeiro o teu perfil de copiloto.'));
      return;
    }
    await Clipboard.setData(ClipboardData(text: PaperPlaneApi.instance.buildFriendInviteLink(_myHandle)));
    if (mounted) _notice(PaperPlaneLocale.translate('Link de convite copiado.'));
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: PlaneText(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _isOnline(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    return date != null && DateTime.now().difference(date).inMinutes < 2;
  }

  String _presenceLabel(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return PaperPlaneLocale.translate('Offline');
    final age = DateTime.now().difference(date);
    if (age.inMinutes < 2) return PaperPlaneLocale.translate('Online');
    if (age.inMinutes < 60) {
      return PaperPlaneLocale.translate('Ativo há ') + age.inMinutes.toString() + ' ' + PaperPlaneLocale.translate('min');
    }
    if (age.inHours < 24) {
      return PaperPlaneLocale.translate('Ativo há ') + age.inHours.toString() + ' ' + PaperPlaneLocale.translate('h');
    }
    if (age.inDays == 1) return PaperPlaneLocale.translate('Ativo ontem');
    return PaperPlaneLocale.translate('Ativo há ') + age.inDays.toString() + ' ' + PaperPlaneLocale.translate('dias');
  }

  String _timeLabel(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    if (now.year == date.year && now.month == date.month && now.day == date.day) {
      return date.hour.toString().padLeft(2, '0') + ':' + date.minute.toString().padLeft(2, '0');
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day) {
      return PaperPlaneLocale.translate('Ontem');
    }
    return date.day.toString().padLeft(2, '0') + '/' + date.month.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 15, 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PlaneText('Inbox', style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
              PlaneText('Mensagens, amigos e ligações pelo mundo', style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
            IconButton(
              onPressed: () => setState(() => _searchOpen = !_searchOpen),
              tooltip: PaperPlaneLocale.translate('Pesquisar'),
              icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded, color: _chatGoldBright, size: 25),
            ),
            IconButton(
              onPressed: _copyInvite,
              tooltip: PaperPlaneLocale.translate('Copiar link de convite'),
              icon: const Icon(Icons.link_rounded, color: _chatGoldBright, size: 24),
            ),
            IconButton(
              onPressed: () => _refresh(),
              tooltip: PaperPlaneLocale.translate('Atualizar'),
              icon: const Icon(Icons.refresh_rounded, color: _chatGoldBright, size: 23),
            ),
          ]),
        ),
        if (_searchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              autofocus: true,
              decoration: InputDecoration(
                hintText: PaperPlaneLocale.translate('Pesquisar conversas ou amigos'),
                prefixIcon: const Icon(Icons.search_rounded, color: _chatGoldBright),
                filled: true,
                fillColor: const Color(0xFF11233F),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: Colors.white.withOpacity(0.09))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: const BorderSide(color: _chatGold)),
              ),
            ),
          ),
        SizedBox(
          height: 45,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip(0, 'All', Icons.all_inbox_rounded),
              _filterChip(1, 'Messages', Icons.chat_bubble_outline_rounded),
              _filterChip(2, 'Friends', Icons.people_alt_outlined),
              _filterChip(3, 'Open Sky', Icons.public_rounded),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _chatGoldBright))
              : _error != null && _chats.isEmpty && _friends.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cloud_off_outlined, color: _chatGoldBright, size: 36),
                        const SizedBox(height: 10),
                        PlaneText(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(onPressed: () => _refresh(), icon: const Icon(Icons.refresh_rounded), label: PlaneText('Tentar novamente')),
                      ]),
                    ))
                  : RefreshIndicator(
                      color: _chatGoldBright,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(17, 5, 17, 28),
                        children: _filter == 0
                            ? _buildAll()
                            : _filter == 1
                                ? _buildMessages()
                                : _filter == 2
                                    ? _buildFriends()
                                    : _buildOpenSky(),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _filterChip(int index, String label, IconData icon) {
    final active = _filter == index;
    final count = index == 0
        ? _conversations.length + _requests.length
        : index == 1
            ? _conversations.length
            : index == 2
                ? _friends.length
                : null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          if (index == 3) {
            widget.onExplore();
          } else {
            setState(() => _filter = index);
          }
        },
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _chatGold.withOpacity(0.19) : const Color(0xFF10223F),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: active ? _chatGold : Colors.white.withOpacity(0.11)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: active ? _chatGoldBright : Colors.white60),
            const SizedBox(width: 6),
            PlaneText(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: active ? _chatGoldBright : Colors.white70)),
            if (count != null) ...[
              const SizedBox(width: 6),
              PlaneText(count.toString(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: active ? _chatGoldBright : Colors.white38)),
            ],
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildAll() {
    final conversations = _conversations.take(8).toList();
    final online = _friends.where((friend) => _isOnline(friend['last_seen_at']?.toString())).take(8).toList();
    return [
      _sectionTitle('Conversas recentes', _conversations.length.toString()),
      const SizedBox(height: 9),
      if (conversations.isEmpty)
        _emptyPanel(icon: Icons.chat_bubble_outline_rounded, title: 'Ainda não tens mensagens',
          body: 'Quando começares um Chat com um amigo, a conversa aparecerá aqui.')
      else
        for (final item in conversations) ...[
          _conversationTile(item),
          const SizedBox(height: 9),
        ],
      if (_requests.isNotEmpty) ...[
        const SizedBox(height: 8),
        _sectionTitle('Pedidos de amizade', _requests.length.toString()),
        const SizedBox(height: 8),
        for (final request in _requests) ...[
          _requestTile(request),
          const SizedBox(height: 8),
        ],
      ],
      if (online.isNotEmpty) ...[
        const SizedBox(height: 10),
        _sectionTitle('Amigos online', online.length.toString()),
        const SizedBox(height: 9),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: online.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _onlineFriend(online[index]),
          ),
        ),
      ],
      const SizedBox(height: 12),
      _invitePanel(),
    ];
  }

  List<Widget> _buildMessages() {
    final conversations = _conversations;
    return [
      _sectionTitle('As tuas conversas', conversations.length.toString()),
      const SizedBox(height: 9),
      if (conversations.isEmpty)
        _emptyPanel(icon: Icons.forum_outlined, title: 'Ainda não tens conversas',
          body: 'Adiciona um amigo e abre uma conversa privada. As Chamas também aparecem nesta lista.')
      else
        for (final item in conversations) ...[
          _conversationTile(item),
          const SizedBox(height: 9),
        ],
    ];
  }

  List<Widget> _buildFriends() {
    final query = _search.text.trim().toLowerCase();
    final friends = query.isEmpty
        ? _friends
        : _friends.where((friend) {
            final name = (friend['pilot_name']?.toString() ?? '').toLowerCase();
            final handle = (friend['pilot_handle']?.toString() ?? '').toLowerCase();
            return name.contains(query) || handle.contains(query);
          }).toList();
    return [
      _infoPanel(icon: Icons.public_rounded, title: 'Os teus amigos pelo mundo',
        body: 'Mantém contacto, vê quem está online e abre uma conversa privada.'),
      const SizedBox(height: 12),
      if (_requests.isNotEmpty) ...[
        _sectionTitle('Pedidos recebidos', _requests.length.toString()),
        const SizedBox(height: 8),
        for (final request in _requests) ...[
          _requestTile(request),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
      ],
      Row(children: [
        Expanded(child: _sectionTitle('Lista de amigos', friends.length.toString())),
        TextButton.icon(onPressed: _copyInvite, icon: const Icon(Icons.link_rounded, size: 15),
          label: PlaneText('Convidar'), style: TextButton.styleFrom(foregroundColor: _chatGoldBright)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _searchPilots(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: PaperPlaneLocale.translate('Pesquisar amigos ou @nome'),
              prefixIcon: const Icon(Icons.search_rounded, color: _chatGoldBright),
              filled: true,
              fillColor: const Color(0xFF11233F),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _chatGold)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _searching ? null : _searchPilots,
            style: FilledButton.styleFrom(backgroundColor: _chatGold, foregroundColor: _chatNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: _searching
                ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: _chatNavy))
                : const Icon(Icons.search_rounded),
          ),
        ),
      ]),
      if (_searchResults.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionTitle('Resultados da pesquisa', _searchResults.length.toString()),
        const SizedBox(height: 8),
        for (final person in _searchResults) ...[
          _personTile(person, action: 'Adicionar', onTap: () => _addFriend(person['pilot_handle']?.toString() ?? '')),
          const SizedBox(height: 8),
        ],
      ],
      const SizedBox(height: 11),
      if (friends.isEmpty && _searchResults.isEmpty)
        _emptyPanel(icon: Icons.people_outline_rounded, title: 'A tua lista ainda está vazia',
          body: 'Procura um @nome ou partilha o teu link de convite.')
      else
        for (final friend in friends) ...[
          _friendTile(friend),
          const SizedBox(height: 8),
        ],
    ];
  }

  List<Widget> _buildOpenSky() => [
    _infoPanel(icon: Icons.public_rounded, title: 'Open Sky',
      body: 'Explora mensagens públicas de pessoas de todo o mundo.', highlight: true),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: widget.onExplore,
      icon: const Icon(Icons.explore_rounded),
      label: PlaneText('Explorar mensagens públicas'),
      style: OutlinedButton.styleFrom(foregroundColor: _chatGoldBright,
        side: BorderSide(color: _chatGold.withOpacity(0.5)),
        minimumSize: const Size.fromHeight(52)),
    ),
  ];

  Widget _sectionTitle(String title, String count) => Row(children: [
    Expanded(child: PlaneText(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
    PlaneText(count, style: const TextStyle(color: _chatGoldBright, fontWeight: FontWeight.w900)),
  ]);

  Widget _conversationTile(Map<String, dynamic> item) {
    final name = item['pilot_name']?.toString() ?? 'Copiloto';
    final handle = item['pilot_handle']?.toString() ?? 'piloto';
    final chama = item['kind']?.toString() == 'CHAMA';
    final id = item['last_message_id']?.toString() ?? '';
    final ownLast = item['last_message_sender_uid']?.toString() == FirebaseAuth.instance.currentUser?.uid;
    final unread = int.tryParse(item['unread_count']?.toString() ?? '') ?? 0;
    final online = _isOnline(item['last_seen_at']?.toString());
    final preview = id.isNotEmpty ? (_translatedPreviews[id] ?? item['last_message']?.toString() ?? '') : '';
    final time = _timeLabel(item['last_message_at']?.toString() ?? item['last_plane_at']?.toString() ?? item['created_at']?.toString());
    return InkWell(
      onTap: () => _openConversation(item),
      borderRadius: BorderRadius.circular(19),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [const Color(0xFF102541), chama ? const Color(0xFF15264A) : const Color(0xFF0C1B34)]),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: unread > 0 ? _chatGold.withOpacity(0.55) : Colors.white.withOpacity(0.10)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            PilotAvatar(fallbackLabel: name, imageUrl: item['avatar_url']?.toString(), size: 53),
            if (online) const Positioned(right: -1, bottom: 0, child: _PresenceDot()),
            if (chama) Positioned(right: -4, top: -3,
              child: Container(padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Color(0xFF263D66), shape: BoxShape.circle),
                child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB66E), size: 13))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: PlaneText(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
              PlaneText(time, style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ]),
            const SizedBox(height: 3),
            PlaneText('@' + handle + ' · ' + _presenceLabel(item['last_seen_at']?.toString()),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: online ? const Color(0xFF55E5AE) : Colors.white54, fontSize: 10)),
            const SizedBox(height: 5),
            Row(children: [
              if (ownLast && !chama) ...[
                Icon(item['last_message_read_at'] == null ? Icons.done_rounded : Icons.done_all_rounded,
                  size: 14, color: item['last_message_read_at'] == null ? Colors.white54 : _chatGoldBright),
                const SizedBox(width: 4),
              ],
              Expanded(child: PlaneText(
                preview.isEmpty ? PaperPlaneLocale.translate(chama ? 'A Chama continua ativa.' : 'Começa uma conversa.') : preview,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: unread > 0 ? Colors.white : Colors.white60,
                  fontSize: 11, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w500))),
              if (unread > 0) Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const BoxDecoration(color: Color(0xFF35BFFF), shape: BoxShape.circle),
                child: PlaneText(unread > 99 ? '99+' : unread.toString(),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
            ]),
          ])),
          PopupMenuButton<String>(
            tooltip: PaperPlaneLocale.translate('Opções da conversa'),
            onSelected: (value) { if (value == 'delete') _deleteConversation(item); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: PlaneText('Eliminar conversa'))],
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 21),
          ),
        ]),
      ),
    );
  }

  Widget _requestTile(Map<String, dynamic> request) {
    final id = request['id']?.toString() ?? '';
    final name = request['pilot_name']?.toString() ?? 'Copiloto';
    final handle = request['pilot_handle']?.toString() ?? 'piloto';
    final online = _isOnline(request['last_seen_at']?.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF102541), borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _chatGold.withOpacity(0.24))),
      child: Row(children: [
        Stack(children: [
          PilotAvatar(fallbackLabel: name, imageUrl: request['avatar_url']?.toString(), size: 43),
          if (online) const Positioned(right: 0, bottom: 0, child: _PresenceDot()),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlaneText(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          PlaneText('@' + handle + ' · ' + _presenceLabel(request['last_seen_at']?.toString()),
            style: TextStyle(color: online ? const Color(0xFF55E5AE) : Colors.white54, fontSize: 10)),
        ])),
        IconButton(onPressed: id.isEmpty ? null : () => _respond(id, true),
          tooltip: PaperPlaneLocale.translate('Aceitar'), icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF55E5AE))),
        IconButton(onPressed: id.isEmpty ? null : () => _respond(id, false),
          tooltip: PaperPlaneLocale.translate('Recusar'), icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF8FAD))),
      ]),
    );
  }

  Widget _friendTile(Map<String, dynamic> friend) {
    final name = friend['pilot_name']?.toString() ?? 'Copiloto';
    final handle = friend['pilot_handle']?.toString() ?? 'piloto';
    final online = _isOnline(friend['last_seen_at']?.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF0F213C), borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(0.10))),
      child: Row(children: [
        Stack(children: [
          PilotAvatar(fallbackLabel: name, imageUrl: friend['avatar_url']?.toString(), size: 48),
          if (online) const Positioned(right: 0, bottom: 0, child: _PresenceDot()),
        ]),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlaneText(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 2),
          PlaneText('@' + handle, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 3),
          PlaneText(_presenceLabel(friend['last_seen_at']?.toString()),
            style: TextStyle(color: online ? const Color(0xFF55E5AE) : Colors.white54, fontSize: 9)),
        ])),
        TextButton(onPressed: () => _openPrivateChat(friend),
          child: PlaneText('Mensagem', style: const TextStyle(color: _chatGoldBright, fontWeight: FontWeight.w900, fontSize: 10))),
        PopupMenuButton<String>(
          onSelected: (_) => _removeFriend(friend),
          itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: PlaneText('Remover amigo'))],
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
        ),
      ]),
    );
  }

  Widget _personTile(Map<String, dynamic> person, {required String action, required VoidCallback onTap}) {
    final name = person['pilot_name']?.toString() ?? 'Copiloto';
    final handle = person['pilot_handle']?.toString() ?? 'piloto';
    final online = _isOnline(person['last_seen_at']?.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF102541), borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withOpacity(0.10))),
      child: Row(children: [
        Stack(children: [
          PilotAvatar(fallbackLabel: name, imageUrl: person['avatar_url']?.toString(), size: 43),
          if (online) const Positioned(right: 0, bottom: 0, child: _PresenceDot()),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PlaneText(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          PlaneText('@' + handle + ' · ' + _presenceLabel(person['last_seen_at']?.toString()),
            style: TextStyle(color: online ? const Color(0xFF55E5AE) : Colors.white54, fontSize: 10)),
        ])),
        TextButton(onPressed: onTap, child: PlaneText(action,
          style: const TextStyle(color: _chatGoldBright, fontWeight: FontWeight.w900))),
      ]),
    );
  }

  Widget _onlineFriend(Map<String, dynamic> friend) {
    final name = friend['pilot_name']?.toString() ?? 'Copiloto';
    return InkWell(
      onTap: () => _openPrivateChat(friend),
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(width: 69, child: Column(children: [
        Stack(children: [
          PilotAvatar(fallbackLabel: name, imageUrl: friend['avatar_url']?.toString(), size: 54),
          const Positioned(right: 0, bottom: 0, child: _PresenceDot()),
        ]),
        const SizedBox(height: 5),
        PlaneText(name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white80, fontSize: 9, fontWeight: FontWeight.w700)),
      ])),
    );
  }

  Widget _invitePanel() => InkWell(
    onTap: _copyInvite,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(color: const Color(0xFF09172C), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _chatGold.withOpacity(0.48))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.link_rounded, color: _chatGoldBright, size: 19),
        const SizedBox(width: 9),
        PlaneText('Copiar o meu link de convite',
          style: const TextStyle(color: _chatGoldBright, fontWeight: FontWeight.w900, fontSize: 12)),
      ]),
    ),
  );

  Widget _infoPanel({required IconData icon, required String title, required String body, bool highlight = false}) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF102541), borderRadius: BorderRadius.circular(19),
          border: Border.all(color: highlight ? _chatGold.withOpacity(0.48) : Colors.white.withOpacity(0.12))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _chatGoldBright, size: 27),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlaneText(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            const SizedBox(height: 5),
            PlaneText(body, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
          ])),
        ]),
      );

  Widget _emptyPanel({required IconData icon, required String title, required String body}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        decoration: BoxDecoration(color: const Color(0xFF0F213B), borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withOpacity(0.10))),
        child: Column(children: [
          Icon(icon, color: _chatGoldBright, size: 33),
          const SizedBox(height: 9),
          PlaneText(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          PlaneText(body, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.45)),
        ]),
      );
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: const Color(0xFF35E4A0), shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF0F213B), width: 2),
      boxShadow: const [BoxShadow(color: Color(0x5535E4A0), blurRadius: 6)]),
  );
}

class ChamaConversationScreen extends StatefulWidget {
  const ChamaConversationScreen({
    super.key,
    required this.conversationId,
    required this.fallbackName,
    required this.fallbackHandle,
    this.fallbackCountry,
    this.fallbackAvatarUrl,
    this.isChama = true,
  });

  final String conversationId;
  final String fallbackName;
  final String fallbackHandle;
  final String? fallbackCountry;
  final String? fallbackAvatarUrl;
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
  String? _otherUid;
  String? _otherLastSeenAt;
  bool _chamaEnded = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];
  String _myLanguage = 'pt';
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
    _myLanguage = PaperPlaneLocale.current.value.languageCode;
    PaperPlaneLocale.current.addListener(_onLocaleChanged);
    _refresh();
    _poller = Timer.periodic(const Duration(seconds: 4), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    PaperPlaneLocale.current.removeListener(_onLocaleChanged);
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onLocaleChanged() {
    final next = PaperPlaneLocale.current.value.languageCode;
    if (!mounted || next == _myLanguage) return;
    setState(() {
      _myLanguage = next;
      _translatedMessages.clear();
      _translatingMessages.clear();
    });
    _translateIncomingMessages(_messages);
  }

  String _presenceStatus() {
    final lastSeen = DateTime.tryParse(_otherLastSeenAt ?? '')?.toLocal();
    if (lastSeen == null) return PaperPlaneLocale.translate('Offline');
    final elapsed = DateTime.now().difference(lastSeen);
    if (elapsed.inMinutes < 2) return PaperPlaneLocale.translate('Online');
    if (elapsed.inMinutes < 60) {
      return PaperPlaneLocale.translate('Ativo há ') + elapsed.inMinutes.toString() + ' ' + PaperPlaneLocale.translate('min');
    }
    if (elapsed.inHours < 24) {
      return PaperPlaneLocale.translate('Ativo há ') + elapsed.inHours.toString() + ' ' + PaperPlaneLocale.translate('h');
    }
    if (elapsed.inDays == 1) return PaperPlaneLocale.translate('Ativo ontem');
    return PaperPlaneLocale.translate('Ativo há ') + elapsed.inDays.toString() + ' ' + PaperPlaneLocale.translate('dias');
  }

  bool get _otherIsOnline {
    final lastSeen = DateTime.tryParse(_otherLastSeenAt ?? '')?.toLocal();
    return lastSeen != null && DateTime.now().difference(lastSeen).inMinutes < 2;
  }

  Future<void> _translateIncomingMessages(List<Map<String, dynamic>> messages) async {
    if (widget.isChama) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final ids = <String>[];
    for (final message in messages) {
      if (message['sender_uid']?.toString() == myUid) continue;
      final id = message['id']?.toString() ?? '';
      if (id.isEmpty || _translatedMessages.containsKey(id) || _translatingMessages.contains(id)) continue;
      final source = (message['message_language_tag']?.toString() ?? 'pt').toLowerCase().split('-').first;
      if (source == _myLanguage) continue;
      ids.add(id);
      if (ids.length >= 20) break;
    }
    if (ids.isEmpty) return;
    if (mounted) setState(() => _translatingMessages.addAll(ids));
    try {
      final result = await PaperPlaneApi.instance.translateChatMessages(
        widget.conversationId,
        ids,
        _myLanguage,
      );
      final items = (result['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item));
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          final id = item['id']?.toString() ?? '';
          final translated = item['text']?.toString() ?? '';
          if (id.isNotEmpty && translated.isNotEmpty) _translatedMessages[id] = translated;
        }
      });
    } catch (_) {
      // If translation is unavailable, show the original message without interrupting chat.
    } finally {
      if (mounted) setState(() => _translatingMessages.removeAll(ids));
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
        _otherUid = conversation['other_uid']?.toString();
        _otherLastSeenAt = conversation['last_seen_at']?.toString();
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
      unawaited(_translateIncomingMessages(messages));
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
          Stack(children: [
            PilotAvatar(fallbackLabel: _name, imageUrl: widget.fallbackAvatarUrl, size: 38),
            if (_otherIsOnline)
              Positioned(right: 0, bottom: 0, child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF35E4A0),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0B1B31), width: 2),
                ),
              )),
          ]),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlaneText(_name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            PlaneText(
              _presenceStatus() + (_countryCode == null ? '' : ' · ' + _countryFlag(_countryCode) + ' ' + _countryName(_countryCode)),
              style: TextStyle(fontSize: 10, color: _otherIsOnline ? const Color(0xFF55E5AE) : Colors.white60),
            ),
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
                await Clipboard.setData(ClipboardData(text: content));
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
