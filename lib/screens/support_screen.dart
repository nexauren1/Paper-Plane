import 'package:flutter/material.dart';

import '../services/paper_plane_api.dart';

const _navy = Color(0xFF071225);
const _panel = Color(0xFF142541);
const _gold = Color(0xFFF0CE7C);
const _goldLight = Color(0xFFFFE7A8);

const _supportCategories = <String, String>{
  'TECHNICAL': 'Problema técnico',
  'ACCOUNT': 'Conta e perfil',
  'DELIVERY': 'Envio e entrega de aviões',
  'SAFETY': 'Segurança',
  'SUGGESTION': 'Sugestão',
  'OTHER': 'Outro assunto',
};

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _subject = TextEditingController();
  final _details = TextEditingController();
  String _category = 'TECHNICAL';
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _subject.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await PaperPlaneApi.instance.getSupportTickets();
      final items = (result['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _tickets = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is PaperPlaneApiException
            ? error.message
            : 'Não foi possível carregar os pedidos anteriores.';
      });
    }
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final details = _details.text.trim();
    if (subject.length < 3 || details.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preenche o assunto e descreve o problema com pelo menos 10 caracteres.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await PaperPlaneApi.instance.createSupportTicket(
        category: _category,
        subject: subject,
        details: details,
      );
      if (!mounted) return;
      _subject.clear();
      _details.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido enviado. Podes acompanhar o estado nesta página.')),
      );
      await _loadTickets();
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException
          ? error.message
          : 'Não foi possível enviar o pedido. Verifica a ligação e tenta novamente.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _statusLabel(String? status) => switch (status) {
        'IN_REVIEW' => 'Em análise',
        'RESOLVED' => 'Resolvido',
        'CLOSED' => 'Fechado',
        _ => 'Recebido',
      };

  Color _statusColor(String? status) => switch (status) {
        'RESOLVED' => const Color(0xFF8DD9B2),
        'CLOSED' => Colors.white54,
        'IN_REVIEW' => _goldLight,
        _ => const Color(0xFF8FC4FF),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        title: const Text('Ajuda e suporte', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _gold,
          onRefresh: _loadTickets,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withOpacity(0.25)),
                ),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.support_agent_rounded, color: _goldLight, size: 34),
                  SizedBox(height: 10),
                  Text('Estamos aqui para ajudar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text(
                    'Comunica falhas, dificuldades com a conta ou entrega, questões de segurança e sugestões. Não incluas palavras-passe nem documentos pessoais.',
                    style: TextStyle(color: Colors.white70, height: 1.45),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              const Text('Novo pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _category,
                isExpanded: true,
                dropdownColor: _panel,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  filled: true,
                  fillColor: _panel,
                  border: OutlineInputBorder(),
                ),
                items: _supportCategories.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: _sending ? null : (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subject,
                enabled: !_sending,
                maxLength: 100,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Assunto',
                  filled: true,
                  fillColor: _panel,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                enabled: !_sending,
                minLines: 4,
                maxLines: 7,
                maxLength: 1200,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Descreve o problema',
                  hintText: 'O que aconteceu? Em que ecrã? O que esperavas que acontecesse?',
                  filled: true,
                  fillColor: _panel,
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? 'A enviar pedido…' : 'Enviar pedido'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Os teus pedidos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _gold)))
              else if (_loadError != null)
                _TicketNotice(message: _loadError!, onRetry: _loadTickets)
              else if (_tickets.isEmpty)
                const _TicketNotice(message: 'Ainda não enviaste pedidos de suporte.')
              else
                for (final ticket in _tickets) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(ticket['subject']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text(_statusLabel(ticket['status']?.toString()), style: TextStyle(color: _statusColor(ticket['status']?.toString()), fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 5),
                      Text(_supportCategories[ticket['category']?.toString()] ?? 'Outro assunto', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 7),
                      Text(ticket['details']?.toString() ?? '', style: const TextStyle(color: Colors.white70, height: 1.4)),
                    ]),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketNotice extends StatelessWidget {
  const _TicketNotice({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
          ],
        ]),
      );
}
