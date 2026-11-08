import 'dart:async';

import 'package:flutter/material.dart';

import '../services/paper_plane_api.dart';

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
  final _pilotHandle = TextEditingController(text: 'chuva_ocidental-07');
  final _birthYear = TextEditingController();
  Timer? _handleDebounce;

  List<Map<String, String>> _countries = [];
  String? _countryCode;
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
    _loadCountries();
  }

  @override
  void dispose() {
    _handleDebounce?.cancel();
    _pilotHandle.removeListener(_onHandleChanged);
    _pilotName.dispose();
    _pilotHandle.dispose();
    _birthYear.dispose();
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
    _handleDebounce?.cancel();
    setState(() {
      _handleAvailable = null;
      _handleMessage = null;
      _checkingHandle = true;
    });
    _handleDebounce = Timer(const Duration(milliseconds: 450), _checkHandle);
  }

  Future<void> _checkHandle() async {
    final handle = _pilotHandle.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[a-zA-Z0-9_]+(?:-[0-9]{2})?$').hasMatch(handle) ||
        handle.length < 4 || handle.length > 28) {
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
        birthYear: int.parse(_birthYear.text.trim()),
        countryCode: _countryCode!,
        language: 'pt',
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
                          'O teu nome de copiloto será único e aparecerá com @. O ano de nascimento é um dado de perfil, não substitui uma verificação de idade segura.',
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
                    decoration: _decoration('Nome único', Icons.alternate_email_rounded, hint: 'chuva_ocidental-07').copyWith(prefixText: '@'),
                  ),
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _birthYear,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    validator: (value) {
                      final year = int.tryParse((value ?? '').trim());
                      final current = DateTime.now().year;
                      if (year == null || year < 1900 || year > current) return 'Introduz um ano válido.';
                      return null;
                    },
                    decoration: _decoration('Ano de nascimento', Icons.cake_outlined, hint: 'Ex.: 2008'),
                  ),
                  const SizedBox(height: 14),
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
