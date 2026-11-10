import 'package:flutter/material.dart';
import '../services/paper_plane_localization.dart';

import '../services/paper_plane_api.dart';

const _reportOptions = <String, String>{
  'HARASSMENT': 'Assédio ou perseguição',
  'THREATS': 'Ameaças ou violência',
  'SEXUAL_CONTENT': 'Conteúdo sexual impróprio',
  'GROOMING': 'Abordagem suspeita ou aliciamento',
  'SPAM': 'Spam ou mensagens repetidas',
  'PERSONAL_INFO': 'Exposição de dados pessoais',
  'IMPERSONATION': 'Falsificação de identidade',
  'OTHER': 'Outro motivo',
};

Future<bool> showReportDialog(BuildContext context, String airplaneId) async {
  final details = TextEditingController();
  var category = 'HARASSMENT';
  var sending = false;
  var submitted = false;

  try {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !sending,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF142541),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFFFFE7A8)),
              SizedBox(width: 10),
              Expanded(child: PlaneText('Denunciar avião')),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PlaneText(
                    'Escolhe o motivo que melhor descreve o problema. A denúncia será enviada para análise.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: category,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF203653),
                    decoration: InputDecoration(
                      labelText: PaperPlaneLocale.translate('Categoria'),
                      border: OutlineInputBorder(),
                    ),
                    items: _reportOptions.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: PlaneText(entry.value, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: sending
                        ? null
                        : (value) {
                            if (value != null) setDialogState(() => category = value);
                          },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: details,
                    enabled: !sending,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: PaperPlaneLocale.translate('Detalhes (opcional)'),
                      hintText: PaperPlaneLocale.translate('Conta-nos o que aconteceu…'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.of(dialogContext).pop(false),
              child: const PlaneText('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      setDialogState(() => sending = true);
                      try {
                        await PaperPlaneApi.instance.reportPlane(
                          airplaneId,
                          reason: category,
                          details: details.text.trim().isEmpty ? null : details.text.trim(),
                        );
                        submitted = true;
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                      } catch (error) {
                        setDialogState(() => sending = false);
                        final message = error is PaperPlaneApiException
                            ? error.message
                            : 'Não foi possível enviar a denúncia. Tenta novamente.';
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: PlaneText(message)),
                          );
                        }
                      }
                    },
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: PlaneText(sending ? 'A enviar…' : 'Enviar denúncia'),
            ),
          ],
        ),
      ),
    );
    if (result == true && submitted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: PlaneText('Denúncia enviada para análise. Obrigado por ajudares a manter o céu seguro.')),
      );
    }
    return result == true;
  } finally {
    details.dispose();
  }
}
