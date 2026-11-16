import 'package:flutter/material.dart';

/// A generated Paper Plane identity mark. Profile photos are intentionally not used.
class PilotAvatar extends StatelessWidget {
  const PilotAvatar({
    super.key,
    required this.url,
    this.size = 48,
    this.borderColor,
    this.iconSize,
    this.fallbackLabel,
  });

  /// Kept for compatibility with older callers; the value is never loaded or displayed.
  final String? url;
  final double size;
  final Color? borderColor;
  final double? iconSize;
  final String? fallbackLabel;

  static const List<List<Color>> _palettes = [
    [Color(0xFF21C8FF), Color(0xFF1765E8), Color(0xFF172A78)],
    [Color(0xFF7D65FF), Color(0xFF4935C8), Color(0xFF1B245F)],
    [Color(0xFF30D6B4), Color(0xFF087C9B), Color(0xFF123B69)],
    [Color(0xFFFFB454), Color(0xFFEF6B52), Color(0xFF653C9C)],
    [Color(0xFFEF74C8), Color(0xFF9A45D4), Color(0xFF34347E)],
    [Color(0xFF72C9FF), Color(0xFF3869C8), Color(0xFF192C58)],
  ];

  int _stableIndex(String value) {
    var hash = 17;
    for (final rune in value.toLowerCase().runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    return hash % _palettes.length;
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length >= 2) {
      return String.fromCharCode(parts.first.runes.first) +
          String.fromCharCode(parts.last.runes.first);
    }
    return String.fromCharCodes(parts.first.runes.take(2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final label = (fallbackLabel ?? '').trim();
    final palette = _palettes[_stableIndex(label.isEmpty ? 'paper-plane' : label)];
    final border = borderColor ?? const Color(0x9957D6FF);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [border, palette.first, palette.last]),
        boxShadow: [
          BoxShadow(color: border.withOpacity(0.18), blurRadius: 13),
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
            child: label.isEmpty
                ? Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: iconSize ?? size * 0.52)
                : Text(
                    _initials(label),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      shadows: const [Shadow(color: Color(0x66000000), blurRadius: 6)],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
