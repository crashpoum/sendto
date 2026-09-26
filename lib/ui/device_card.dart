import 'package:flutter/material.dart';

import '../models/peer.dart';
import '../theme/app_theme.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.peer,
    required this.onTap,
    this.onLongPress,
    this.onClipboard,
    this.onFolder,
  });

  final Peer peer;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onClipboard;
  final VoidCallback? onFolder;

  @override
  Widget build(BuildContext context) {
    final t = SendToTheme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: peer.tileColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(peer.glyph, color: const Color(0xFF1A1A1A), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: peer.isOnline ? t.ink : t.muted,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  peer.isOnline ? peer.osLabel : '${peer.osLabel} · offline',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (peer.isOnline && onFolder != null)
            IconButton(
              tooltip: 'Send folder',
              visualDensity: VisualDensity.compact,
              onPressed: onFolder,
              icon: Icon(Icons.folder_outlined, color: t.muted, size: 20),
            ),
          if (peer.isOnline && onClipboard != null)
            IconButton(
              tooltip: 'Send clipboard',
              visualDensity: VisualDensity.compact,
              onPressed: onClipboard,
              icon: Icon(Icons.content_paste_outlined, color: t.muted, size: 20),
            ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: peer.isOnline ? t.live : t.line,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );

    if (!t.useCards) {
      return Column(
        children: [
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTap: onLongPress,
            child: row,
          ),
          Divider(height: 1, color: t.line),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.line),
            ),
            child: row,
          ),
        ),
      ),
    );
  }
}
