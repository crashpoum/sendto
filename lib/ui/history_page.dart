import 'dart:io';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme/app_theme.dart';
import '../util/reveal.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final t = SendToTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: app,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: t.ink),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'History',
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(fontSize: 32),
                      ),
                      const Spacer(),
                      if (app.history.isNotEmpty)
                        TextButton(
                          onPressed: app.clearHistory,
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: app.history.isEmpty
                      ? Center(
                          child: Text(
                            'Nothing sent or received yet.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                          itemCount: app.history.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: t.line),
                          itemBuilder: (context, i) {
                            final item = app.history[i];
                            final when = _ago(item.at);
                            final desktop = Platform.isWindows ||
                                Platform.isLinux ||
                                Platform.isMacOS;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${item.outgoing ? 'To' : 'From'} ${item.peerName}  ·  ${_size(item.size)}  ·  $when',
                              ),
                              trailing: desktop && item.path != null
                                  ? IconButton(
                                      tooltip: 'Show in folder',
                                      onPressed: () => revealPath(item.path!),
                                      icon: Icon(
                                        Icons.folder_open_outlined,
                                        color: t.muted,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _ago(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  }

  static String _size(int n) {
    if (n < 1000) return '$n B';
    if (n < 1000 * 1000) return '${(n / 1000).toStringAsFixed(0)} KB';
    return '${(n / 1000000).toStringAsFixed(1)} MB';
  }
}
