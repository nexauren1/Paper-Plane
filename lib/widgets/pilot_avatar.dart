import 'package:flutter/material.dart';

/// Paper Plane identity mark. Avatars are generated locally from the pilot name;
/// this widget intentionally never downloads or displays profile photographs.
class PilotAvatar extends StatelessWidget {
  const PilotAvatar({
    super.key,
    this.size = 48,
    this.borderColor,
    this.iconSize,
    this.fallbackLabel,
  });

  final double size;
  final Color? borderColor;
  final double? iconSize;
  final String? fallbackLabel;

  String _initials() {
    final label = (fallbackLabel ?? '').trim();
    if (label.isEmpty) return '';
    final parts = label.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (String.fromCharCode(parts.first.runes.first) +
              String.fromCharCode(parts[1].runes.first))
          .toUpperCase();
    }
    return String.fromCharCodes(label.runes.take(2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const palettes = <List<Color>>[
      [Color(0xFF168BFF), Color(0xFF493FCA), Color(0xFF111F4A)],
      [Color(0xFF08A6C8), Color(0xFF1553A6), Color(0xFF10234A)],
      [Color(0xFF6554E8), Color(0xFF294EAE), Color(0xFF111C45)],
      [Color(0xFF087E8B), Color(0xFF2256B5), Color(0xFF101B3D)],
      [Color(0xFF2865D5), Color(0xFF6A3BC4), Color(0xFF171B48)],
    ];
    final label = (fallbackLabel ?? '').trim();
    var stableHash = 0;
    for (final rune in label.toLowerCase().runes) {
      stableHash = (stableHash * 31 + rune) & 0x7fffffff;
    }
    final paletteIndex = label.isEmpty ? 0 : stableHash % palettes.length;
    final palette = palettes[paletteIndex];
    final initials = _initials();

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            borderColor ?? const Color(0xFF57D6FF),
            const Color(0xFF377CEB),
            const Color(0xFF7652D7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: (borderColor ?? const Color(0xFF57D6FF)).withOpacity(0.22),
            blurRadius: 14,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette,
            ),
          ),
          child: Center(
            child: initials.isEmpty
                ? Icon(
                    Icons.flight_takeoff_rounded,
                    color: const Color(0xFFB8F1FF),
                    size: iconSize ?? size * 0.52,
                  )
                : Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
