import 'dart:async';

import 'package:flutter/material.dart';

import '../services/paper_plane_api.dart';
import '../widgets/pilot_avatar.dart';

const Color _setupNavy = Color(0xFF071225);
const Color _setupGold = Color(0xFFF0CE7C);
const Color _setupGoldLight = Color(0xFFFFE7A8);

class PilotProfileSetupScreen extends StatefulWidget {
  const PilotProfileSetupScreen({super.key});

  @override
  State<PilotProfileSetupScreen> createState() => _PilotProfileSetupScreenState();
}

class _PilotProfileSetupScreenState extends State<PilotProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pilotName = TextEditingController();
  final _pilotHandle = TextEditingController();
  final _avatarUrl = TextEditingController();
  DateTime? _selectedBirthDate;
  final _birthDateDisplay = TextEditingController();
  Timer? _handleDebounce;
  bool _handleManuallyEdited = false;
  bool _updatingSuggestedHandle = false;

  List<Map<String, String>> _countries = [];
  String? _countryCode;
  String _preferredLanguage = 'pt';
  static const Map<String, String> _languages = {
    'pt': 'Português',
    'en': 'English',
    'ja': '日本語 · Japonês',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'zh': '中文 · Chinês',
    'ko': '한국어 · Coreano',
    'ar': 'العربية · Árabe',
    'ru': 'Русский · Russo',
    'hi': 'हिन्दी · Hindi',
    'id': 'Bahasa Indonesia',
  };
  bool _loadingCountries = true;
  bool _saving = false;
  bool _checkingHandle = false;
  bool? _handleAvailable;
  String? _handleMessage;
  String? _countryError;

  @override
  void initState() {
    super.initState();
    _pilotHandle.addListener(_onHandleChanged);
    _pilotName.addListener(_suggestHandleFromName);
    _loadCountries();
  }

  @override
  void dispose() {
    _handleDebounce?.cancel();
    _pilotHandle.removeListener(_onHandleChanged);
    _pilotName.removeListener(_suggestHandleFromName);
    _pilotName.dispose();
    _pilotHandle.dispose();
    _avatarUrl.dispose();
    _birthDateDisplay.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final result = await PaperPlaneApi.instance.getCountries();
      final items = (result['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => {
                'code': item['code']?.toString() ?? '',
                'name': item['name']?.toString() ?? '',
              })
          .where((item) => item['code']!.isNotEmpty && item['name']!.isNotEmpty)
          .toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));
      if (!mounted) return;
      setState(() {
        _countries = items;
        _loadingCountries = false;
        _countryCode = null;
      });
      _checkHandle();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCountries = false;
        _countryError = error is PaperPlaneApiException
            ? error.message
            : 'Não foi possível carregar os países. Verifica a ligação.';
      });
    }
  }

  void _onHandleChanged() {
    if (!_updatingSuggestedHandle) _handleManuallyEdited = true;
    _handleDebounce?.cancel();
    setState(() {
      _handleAvailable = null;
      _handleMessage = null;
      _checkingHandle = true;
    });
    _handleDebounce = Timer(const Duration(milliseconds: 450), _checkHandle);
  }


  void _suggestHandleFromName() {
    if (_handleManuallyEdited) return;
    final suggested = _pilotName.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (suggested.length < 3 || suggested == _pilotHandle.text) return;
    final value = suggested.substring(0, suggested.length > 28 ? 28 : suggested.length);
    _updatingSuggestedHandle = true;
    _pilotHandle.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _updatingSuggestedHandle = false;
    _handleDebounce?.cancel();
    _handleDebounce = Timer(const Duration(milliseconds: 450), _checkHandle);
  }

  Future<void> _checkHandle() async {
    final handle = _pilotHandle.text.trim().replaceFirst(RegExp(r'^@'), '');
    final parts = handle.split('-');
    final suffixValid = parts.length == 1 ||
        (parts.length == 2 && parts[1].length == 2 && int.tryParse(parts[1]) != null);
    final nameParts = parts.first.split('_');
    final nameValid = nameParts.isNotEmpty &&
        nameParts.every((part) => part.isNotEmpty && part.codeUnits.every((unit) =>
            (unit >= 48 && unit <= 57) ||
            (unit >= 65 && unit <= 90) ||
            (unit >= 97 && unit <= 122)));
    if (!suffixValid || !nameValid || handle.length < 4 || handle.length > 28) {
      if (!mounted) return;
      setState(() {
        _checkingHandle = false;
        _handleAvailable = false;
        _handleMessage = 'Usa letras, números, _ e opcionalmente -07 (4–28 caracteres).';
      });
      return;
    }

    if (mounted) setState(() => _checkingHandle = true);
    try {
      final result = await PaperPlaneApi.instance.checkPilotHandle(handle);
      if (!mounted || _pilotHandle.text.trim().replaceFirst(RegExp(r'^@'), '') != handle) return;
      final available = result['available'] == true && result['valid'] == true;
      setState(() {
        _checkingHandle = false;
        _handleAvailable = available;
        _handleMessage = available
            ? 'Este nome está disponível.'
            : 'Esse nome já existe. Escolhe outro.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingHandle = false;
        _handleAvailable = null;
        _handleMessage = 'Não foi possível verificar agora. A ligação é obrigatória para guardar.';
      });
    }
  }

  String _formatBirthDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final earliestAllowed = DateTime(now.year - 120, now.month, now.day);
    final latestAllowed = DateTime(now.year - 13, now.month, now.day);
    final initial = _selectedBirthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(latestAllowed) ? latestAllowed : initial,
      firstDate: earliestAllowed,
      lastDate: latestAllowed,
      helpText: 'Seleciona a tua data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: _setupGold,
            onPrimary: _setupNavy,
            surface: const Color(0xFF142541),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedBirthDate = DateTime(picked.year, picked.month, picked.day);
        _birthDateDisplay.text = _formatBirthDate(_selectedBirthDate!);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_countryCode == null) {
      setState(() => _countryError = 'Escolhe o teu país.');
      return;
    }
    if (_handleAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolhe um nome de copiloto disponível.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await PaperPlaneApi.instance.savePilotProfile(
        pilotName: _pilotName.text.trim(),
        pilotHandle: _pilotHandle.text.trim().replaceFirst(RegExp(r'^@'), ''),
        birthDate: _selectedBirthDate!,
        countryCode: _countryCode!,
        language: _preferredLanguage,
        avatarUrl: _avatarUrl.text.trim().isEmpty ? null : _avatarUrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is PaperPlaneApiException
          ? error.message
          : 'Não foi possível guardar o perfil. Confirma a internet e tenta novamente.';
      if (error is PaperPlaneApiException && error.code == 'PILOT_HANDLE_TAKEN') {
        setState(() {
          _handleAvailable = false;
          _handleMessage = 'Esse nome já foi escolhido por outro piloto.';
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _setupGoldLight),
      filled: true,
      fillColor: const Color(0xFF0C1A30),
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white38),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _setupGold, width: 1.4),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: _setupNavy,
        appBar: AppBar(
          backgroundColor: _setupNavy,
          foregroundColor: _setupGoldLight,
          title: const Text('Criar perfil de copiloto'),
          automaticallyImplyLeading: !_saving,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_setupNavy, Color(0xFF0B1B35), Color(0xFF040A15)],
            ),
          ),
          child: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xCC172844),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _setupGold.withOpacity(0.35)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.flight_takeoff_rounded, color: _setupGoldLight, size: 34),
                        SizedBox(height: 10),
                        Text('Escolhe a tua identidade', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        SizedBox(height: 6),
                        Text(
                          'O teu nome de copiloto será único e aparecerá com @. A tua data de nascimento é declarada por ti. O servidor calcula a faixa etária, mas não verifica a tua identidade.',
                          style: TextStyle(color: Colors.white70, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _pilotName,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 40,
                    validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Introduz um nome com pelo menos 2 caracteres.' : null,
                    decoration: _decoration('Nome de copiloto', Icons.person_outline_rounded, hint: 'Como queres ser chamado?'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pilotHandle,
                    autocorrect: false,
                    maxLength: 28,
                    decoration: _decoration('O teu @nome', Icons.alternate_email_rounded, hint: 'ana_maria').copyWith(prefixText: '@'),

                  ),
                  const SizedBox(height: 5),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Cria o teu próprio @nome. Não precisas de números aleatórios no fim.',
                      style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_checkingHandle)
                        const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: _setupGold)),
                      if (_checkingHandle) const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _handleMessage ?? 'Vamos verificar se o teu nome está livre.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _handleAvailable == true
                                ? const Color(0xFF8DE0AF)
                                : _handleAvailable == false
                                    ? const Color(0xFFFF9B9B)
                                    : Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Foto de perfil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _setupGoldLight)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PilotAvatar(url: _avatarUrl.text.trim(), size: 58),
                      const SizedBox(width: 11),
                      Expanded(
                        child: TextFormField(
                          controller: _avatarUrl,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          onChanged: (_) => setState(() {}),
                          decoration: _decoration('Link da foto ou perfil público', Icons.link_rounded, hint: 'https://…'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Cola um link HTTPS de uma imagem ou de um perfil público. Tentaremos encontrar a foto automaticamente. Não precisas de carregar ficheiros.',
                      style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    readOnly: true,
                    controller: _birthDateDisplay,
                    onTap: _saving ? null : _pickBirthDate,
                    validator: (_) => _selectedBirthDate == null
                        ? 'Seleciona a tua data de nascimento.'
                        : null,
                    decoration: _decoration(
                      'Data de nascimento',
                      Icons.cake_outlined,
                      hint: 'Dia / mês / ano',
                    ).copyWith(
                      suffixIcon: IconButton(
                        onPressed: _saving ? null : _pickBirthDate,
                        icon: const Icon(Icons.calendar_month_rounded, color: _setupGoldLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Usamos a data para calcular a faixa etária. O dia e o mês não ficam guardados; o servidor conserva apenas o ano e a faixa declarada.',
                      style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Idioma preferido',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _setupGoldLight),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _preferredLanguage,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF142541),
                    decoration: _decoration('Idioma para receber aviões e traduções', Icons.translate_rounded),
                    items: _languages.entries.map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: _saving ? null : (value) {
                      if (value != null) setState(() => _preferredLanguage = value);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6, left: 8, right: 8, bottom: 10),
                    child: Text(
                      'Os aviões recebidos podem ser apresentados automaticamente neste idioma. A mensagem original continua disponível.',
                      style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                    ),
                  ),
                  if (_loadingCountries)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: _setupGold),
                    ))
                  else if (_countries.isEmpty)
                    Text(_countryError ?? 'A lista de países não está disponível.', style: const TextStyle(color: Colors.redAccent))
                  else
                    DropdownButtonFormField<String>(
                      value: _countryCode,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF142541),
                      decoration: _decoration('País', Icons.public_rounded),
                      items: _countries.map((country) => DropdownMenuItem(
                        value: country['code'],
                        child: Text(country['name']!, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: _saving ? null : (value) => setState(() {
                        _countryCode = value;
                        _countryError = null;
                      }),
                    ),
                  if (_countryError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 12),
                      child: Text(_countryError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _saving || _loadingCountries || _checkingHandle || _handleAvailable != true || _countries.isEmpty
                          ? null
                          : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _setupNavy))
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(_saving ? 'A guardar perfil…' : 'Guardar perfil'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _setupGold,
                        foregroundColor: _setupNavy,
                        disabledBackgroundColor: Colors.white12,
                        disabledForegroundColor: Colors.white38,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}