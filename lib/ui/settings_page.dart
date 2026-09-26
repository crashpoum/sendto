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
            const SizedBox(height: 40),
            Text('About', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'SendTo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '0.1.2',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Text(
              'Tap a machine on this network and send any file. Select the clipboard icon to send your clipboard.Easy, local, simple.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
