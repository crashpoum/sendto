import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../models/peer.dart';
import '../models/transfer.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'device_card.dart';
import 'settings_page.dart';
import 'theme_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.app,
    required this.themes,
  });

  final AppController app;
  final ThemeController themes;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _seenSaved;

  AppController get app => widget.app;
  ThemeController get themes => widget.themes;

  @override
  Widget build(BuildContext context) {
    final t = SendToTheme.of(context);
    final saved = app.receiver.lastSavedPath;
    if (saved != null && saved != _seenSaved) {
      _seenSaved = saved;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to $saved'),
            duration: const Duration(seconds: 6),
          ),
        );
      });
    }
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([app, themes]),
          builder: (context, _) {
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, box) {
                          final stacked = box.maxWidth < 560;
                          final title = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SendTo',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                      fontSize: stacked ? 34 : 42,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'On this network',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          );
                          final tools = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ToolbarIcon(
                                tooltip: 'Refresh',
                                icon: Icons.refresh,
                                color: t.muted,
                                onPressed: app.refreshPeers,
                              ),
                              _ToolbarIcon(
                                tooltip: 'Settings',
                                icon: Icons.settings_outlined,
                                color: t.muted,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => SettingsPage(app: app),
                                    ),
                                  );
                                },
                              ),
                              _ToolbarIcon(
                                tooltip: 'Theme',
                                icon: themeIconFor(themes.mode),
                                color: t.muted,
                                label: stacked ? null : 'Theme',
                                onPressed: () =>
                                    showThemeSheet(context, themes),
                              ),
                            ],
                          );
                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title,
                                const SizedBox(height: 12),
                                tools,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: title),
                              tools,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Expanded(child: _PeerList(app: app)),
                    ],
                  ),
                ),
                if (app.outgoing != null)
                  _SendingOverlay(app: app, transfer: app.outgoing!),
                if (app.incoming != null &&
                    app.incoming!.decision == IncomingDecision.pending)
                  _IncomingSheet(app: app, offer: app.incoming!),
              ],
            );
          },
        ),
      ),
    );
  }

}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.label,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(label!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Tooltip(message: tooltip, child: child),
      ),
    );
  }
}

class _PeerList extends StatelessWidget {
  const _PeerList({required this.app});
  final AppController app;

  Future<void> _pickAndSend(BuildContext context, Peer peer) async {
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty) return;
    final files = <FileOffer>[];
    for (final f in picked) {
      final path = f.path;
      if (path == null) continue;
      var size = 0;
      try {
        size = File(path).lengthSync();
      } catch (_) {
        size = f.lengthSync() ?? 0;
      }
      files.add(FileOffer(name: f.name, size: size, path: path));
    }
    if (files.isEmpty) return;
    await app.sendTo(peer, files);
  }

  Future<void> _forget(BuildContext context, Peer peer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Remove ${peer.name}?'),
          content: Text(
            peer.isOnline
                ? 'It will show up again while the app is open on that machine.'
                : 'You can add it back when it comes online.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (ok == true) app.forgetPeer(peer);
  }

  @override
  Widget build(BuildContext context) {
    final peers = app.peers;
    return RefreshIndicator(
      onRefresh: app.refreshPeers,
      child: peers.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(
                    'Waiting for another machine…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: peers.length,
              itemBuilder: (context, i) {
                final peer = peers[i];
                return DeviceCard(
                  peer: peer,
                  onLongPress: () => _forget(context, peer),
                  onTap: () {
                    if (!peer.isOnline) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not on the network right now'),
                        ),
                      );
                      return;
                    }
                    _pickAndSend(context, peer);
                  },
                );
              },
            ),
    );
  }
}

class _SendingOverlay extends StatelessWidget {
  const _SendingOverlay({required this.app, required this.transfer});
  final AppController app;
  final OutgoingTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final t = SendToTheme.of(context);
    final title = switch (transfer.phase) {
      SendPhase.waiting => 'Waiting on ${transfer.peerName}',
      SendPhase.transferring => 'Sending to ${transfer.peerName}',
      SendPhase.done => 'Saved on ${transfer.peerName}',
      SendPhase.failed => 'Could not send',
      SendPhase.cancelled => 'Cancelled',
    };

    return Positioned.fill(
      child: ColoredBox(
        color: t.canvas.withValues(alpha: 0.55),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: t.card,
              elevation: t.useCards ? 8 : 0,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    for (final f in transfer.files)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          f.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: transfer.phase == SendPhase.waiting
                            ? null
                            : transfer.progress,
                        minHeight: 8,
                        color: t.live,
                        backgroundColor: t.line,
                      ),
                    ),
                    if (transfer.error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        transfer.error!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: transfer.phase == SendPhase.transferring ||
                                transfer.phase == SendPhase.waiting
                            ? app.cancelSend
                            : app.dismissOutgoing,
                        child: Text(
                          transfer.phase == SendPhase.transferring ||
                                  transfer.phase == SendPhase.waiting
                              ? 'Cancel'
                              : 'Done',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingSheet extends StatelessWidget {
  const _IncomingSheet({required this.app, required this.offer});
  final AppController app;
  final IncomingOffer offer;

  @override
  Widget build(BuildContext context) {
    final t = SendToTheme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: t.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'From ${offer.fromName}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 16),
              for (final f in offer.files)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${f.name}  ·  ${_size(f.size)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.ink,
                    foregroundColor: t.canvas,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: app.acceptIncoming,
                  child: const Text('Save here'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: app.rejectIncoming,
                  child: Text(
                    'Not now',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
