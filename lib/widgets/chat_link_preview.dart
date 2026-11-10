import 'package:flutter/material.dart';
import '../services/paper_plane_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/paper_plane_api.dart';

class ChatLinkPreview extends StatefulWidget {
  const ChatLinkPreview({super.key, required this.message});
  final String message;

  @override
  State<ChatLinkPreview> createState() => _ChatLinkPreviewState();
}

class _ChatLinkPreviewState extends State<ChatLinkPreview> {
  static final Map<String, Future<Map<String, dynamic>?>> _cache = {};
  late final String? _url;
  late final Future<Map<String, dynamic>?> _preview;

  @override
  void initState() {
    super.initState();
    _url = _extractUrl(widget.message);
    _preview = _load(_url);
  }

  static String? _extractUrl(String text) {
    final match = RegExp(r'https?://[^\s<>" ]+', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    return match.group(0)?.replaceFirst(RegExp(r'[.,!?;:)\]]+$'), '');
  }

  Future<Map<String, dynamic>?> _load(String? value) {
    if (value == null || value.isEmpty) return Future.value(null);
    return _cache.putIfAbsent(value, () async {
      try {
        final result = await PaperPlaneApi.instance.getLinkPreview(value);
        final data = result['preview'];
        return data is Map ? Map<String, dynamic>.from(data) : null;
      } catch (_) {
        return null;
      }
    });
  }

  Future<void> _open() async {
    final value = _url;
    if (value == null) return;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>?>(
      future: _preview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 58,
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Color(0xFFFFE7A8),
                ),
              ),
              SizedBox(width: 9),
              PlaneText('A ler o link…', style: TextStyle(color: Colors.white60, fontSize: 10)),
            ]),
          );
        }

        final preview = snapshot.data;
        if (preview == null) return const SizedBox.shrink();
        final title = preview['title']?.toString() ?? '';
        final description = preview['description']?.toString() ?? '';
        final site = preview['siteName']?.toString() ?? '';
        final image = preview['imageUrl']?.toString() ?? '';

        return InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            margin: const EdgeInsets.only(top: 9),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF10233D),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x66F0CE7C)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 82,
                  height: 82,
                  child: image.startsWith('https://')
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallback(),
                        )
                      : _fallback(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlaneText(
                          site.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFE7A8),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 3),
                        PlaneText(
                          title.isEmpty ? _url! : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          PlaneText(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 9,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 9, right: 8),
                  child: Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFFFFE7A8)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallback() => Container(
        color: const Color(0xFF1C365A),
        alignment: Alignment.center,
        child: const Icon(Icons.link_rounded, color: Color(0xFFFFE7A8), size: 25),
      );
}
