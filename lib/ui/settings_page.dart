import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.app});

  final AppController app;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _name;
  late String _folder;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.app.self.name);
    _folder = widget.app.saveFolder ?? 'Downloads';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    try {
      final path = await FilePicker.getDirectoryPath();
      if (path == null || path.trim().isEmpty) return;
      setState(() => _folder = path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick a folder')),
      );
    }
  }

  Future<void> _useDefault() async {
    final path = await widget.app.receiver.defaultSaveFolder();
    setState(() => _folder = path);
  }

  Future<void> _save() async {
    await widget.app.renameSelf(_name.text);
    if (_folder.isNotEmpty && _folder != 'Downloads') {
      await widget.app.setSaveFolder(_folder);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = SendToTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: t.ink),
                ),
                const SizedBox(width: 4),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 32,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('This device', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Name other machines see on the network.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Device name',
                filled: true,
                fillColor: t.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.line),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Save incoming files to',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'New transfers land in this folder.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.line),
              ),
              child: Text(
                _folder,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _pickFolder,
                  child: const Text('Change folder'),
                ),
                TextButton(
                  onPressed: _useDefault,
                  child: const Text('Use default'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: t.ink,
                  foregroundColor: t.canvas,
                  shape: const StadiumBorder(),
                ),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 36),
            Text('Advanced', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Optional. Most people can leave this closed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require PIN to receive'),
              subtitle: Text(
                widget.app.receiver.requirePin
                    ? 'PIN ${widget.app.receiver.pinCode}. The sender types this when they send you files.'
                    : 'Off. Anyone on this network who can see you can offer a file.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: widget.app.receiver.requirePin,
              onChanged: (v) async {
                await widget.app.setRequirePin(v);
                setState(() {});
              },
            ),
            if (widget.app.receiver.requirePin)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    await widget.app.rotatePin();
                    setState(() {});
                  },
                  child: const Text('New PIN'),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Add a host (Tailscale / IP)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Use this when two machines cannot see each other on the local network. Type a Tailscale name, a 100.x address, or a LAN IP. SendTo must already be open on that machine. Port 47822.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _HostField(onAdd: (host) async {
              final err = await widget.app.addManualHost(host);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(err ?? 'Added $host')),
              );
            }),
            const SizedBox(height: 40),
            Text('About', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'SendTo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '0.1.3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Text(
              'Send files, folders, or clipboard to another machine on the network. No account.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _HostField extends StatefulWidget {
  const _HostField({required this.onAdd});
  final Future<void> Function(String host) onAdd;

  @override
  State<_HostField> createState() => _HostFieldState();
}

class _HostFieldState extends State<_HostField> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: '100.x.x.x or pc-name',
            ),
            onSubmitted: (_) => _go(),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _busy ? null : _go,
          child: Text(_busy ? '…' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _go() async {
    final host = _ctrl.text.trim();
    if (host.isEmpty) return;
    setState(() => _busy = true);
    await widget.onAdd(host);
    if (mounted) setState(() => _busy = false);
  }
}
