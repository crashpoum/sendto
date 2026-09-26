import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> revealPath(String path) async {
  final file = File(path);
  final dir = Directory(path);
  final target = file.existsSync()
      ? path
      : dir.existsSync()
          ? path
          : p.dirname(path);
  try {
    if (Platform.isWindows) {
      if (File(target).existsSync()) {
        await Process.run('explorer.exe', ['/select,', target.replaceAll('/', r'\')]);
      } else {
        await Process.run('explorer.exe', [target.replaceAll('/', r'\')]);
      }
    } else if (Platform.isMacOS) {
      await Process.run('open', File(target).existsSync() ? ['-R', target] : [target]);
    } else if (Platform.isLinux) {
      final folder = File(target).existsSync() ? p.dirname(target) : target;
      await Process.run('xdg-open', [folder]);
    }
  } catch (_) {}
}
