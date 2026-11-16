import 'package:flutter/material.dart';

import '../services/paper_plane_api.dart';

class PilotAvatar extends StatefulWidget {
  const PilotAvatar({
    super.key,
    required this.url,
    this.size = 48,
    this.borderColor,
    this.iconSize,
    this.fallbackLabel,
  });

  final String? url;
  final double size;
  final Color? borderColor;
  final double? iconSize;
  final String? fallbackLabel;

  @override
  State<PilotAvatar> createState() => _PilotAvatarState();
}

class _PilotAvatarState extends State<PilotAvatar> {
  static final Map<String, Future<String?>> _imageCache = {};
  late Future<String?> _image;

  @override
  void initState() {
    super.initState();
    _image = _resolve(widget.url);
  }

  @override
  void didUpdateWidget(covariant PilotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _image = _resolve(widget.url);
  }

  Future<String?> _resolve(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return Future.value(null);
    return _imageCache.putIfAbsent(url, () async {
      try {
        final result = await PaperPlaneApi.instance.getLinkPreview(url);
        final preview = result['preview'] as Map<String, dynamic>? ?? const {};
        final image = preview['imageUrl']?.toString() ?? '';
        return image.startsWith('https://') ? image : null;
      } catch (_) {
        return null;
      }
    });
  }

  String _initials() {
    final label = (widget.fallbackLabel ?? '').trim();
    if (label.isEmpty) return 'PP';
    final parts = label.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return String.fromCharCode(parts.first.runes.first) +
          String.fromCharCode(parts[1].runes.first);
    }
    final runes = label.runes.take(2).toList();
    return String.fromCharCodes(runes).toUpperCase();
  }

  Widget _fallback() {
    final hasName = (widget.fallbackLabel ?? '').trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF168BFF), Color(0xFF493FCA), Color(0xFF111F4A)],
        ),
      ),
      child: Center(
        child: hasName
            ? Text(
                _initials(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.size * 0.30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              )
            : Icon(
                Icons.flight_takeoff_rounded,
                color: const Color(0xFFB8F1FF),
                size: widget.iconSize ?? widget.size * 0.54,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = widget.borderColor ?? const Color(0x9957D6FF);
    return FutureBuilder<String?>(
      future: _image,
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;
        return Container(
          width: widget.size,
          height: widget.size,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [border, const Color(0x664D90FF), const Color(0x22F0CE7C)],
            ),
            boxShadow: [
              BoxShadow(color: border.withOpacity(0.16), blurRadius: 13),
            ],
          ),
          child: ClipOval(
            child: ColoredBox(
              color: const Color(0xFF142541),
              child: imageUrl == null
                  ? Center(child: _fallback())
                  : Image.network(
                      imageUrl,
                      width: widget.size,
                      height: widget.size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(child: _fallback()),
                    ),
            ),
          ),
        );
      },
    );
  }
}
