import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/transfer.dart';

Future<FileOffer> zipFolder(String dirPath) async {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    throw Exception('Folder not found');
  }
  final name = p.basename(dir.path);
  final tmp = await getTemporaryDirectory();
  final out = File(p.join(tmp.path, 'sendto-$name.zip'));
  if (out.existsSync()) out.deleteSync();
  final encoder = ZipFileEncoder();
  encoder.create(out.path);
  encoder.addDirectory(dir, includeDirName: true);
  encoder.close();
  return FileOffer(
    name: '$name.zip',
    size: out.lengthSync(),
    path: out.path,
  );
}
