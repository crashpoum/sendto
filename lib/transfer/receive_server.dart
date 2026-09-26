import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../discovery/discovery_service.dart';
import '../models/transfer.dart';

/// Local HTTP receiver. Starts with the app. No port picker.
class ReceiveServer extends ChangeNotifier {
  HttpServer? _server;
  final Map<String, IncomingOffer> _offers = {};
  final _waiters = <String, Completer<IncomingDecision>>{};

  IncomingOffer? incoming;
  String? saveFolder;
  String? lastSavedPath;
  String? lastFromName;
  String? lastSavedName;
  int lastSavedSize = 0;
  bool requirePin = false;
  String pinCode = '0000';

  Future<void> start() async {
    saveFolder ??= await defaultSaveFolder();
    if (_server != null) return;
    await _bind();
  }

  Future<void> restart() async {
    await stop();
    await _bind();
  }

  Future<void> _bind() async {
    Object? lastErr;
    for (var i = 0; i < 4; i++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, kTransferPort);
        _server!.listen(_handle);
        return;
      } catch (e) {
        lastErr = e;
        await Future<void>.delayed(Duration(milliseconds: 200 * (i + 1)));
      }
    }
    debugPrint('SendTo receiver bind failed: $lastErr');
  }

  Future<void> stop() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
  }

  void decide(IncomingDecision decision) {
    final offer = incoming;
    if (offer == null) return;
    offer.decision = decision;
    _waiters.remove(offer.id)?.complete(decision);
    if (decision == IncomingDecision.rejected) {
      incoming = null;
    }
    notifyListeners();
  }

  void clearIncoming() {
    incoming = null;
    notifyListeners();
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      _cors(req.response);
      if (req.method == 'OPTIONS') {
        req.response.statusCode = 204;
        await req.response.close();
        return;
      }

      final path = req.uri.path.replaceAll(RegExp(r'/+$'), '');

      if (req.method == 'GET' && path == '/health') {
        req.response
          ..statusCode = 200
          ..write('ok');
        await req.response.close();
        return;
      }

      if (req.method == 'GET' && path == '/clipboard') {
        req.response
          ..statusCode = 200
          ..write('clipboard');
        await req.response.close();
        return;
      }

      if (req.method == 'POST' && path == '/offer') {
        await _onOffer(req);
        return;
      }

      if (req.method == 'POST' && path.endsWith('clipboard')) {
        await _onClipboard(req);
        return;
      }

      if (req.method == 'GET' &&
          path.startsWith('/offer/') &&
          path.endsWith('/status')) {
        final id = path.split('/')[2];
        final offer = _offers[id];
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'status': offer?.decision.name ?? 'missing',
            'needPin': requirePin && offer != null && !offer.pinOk,
          }));
        await req.response.close();
        return;
      }

      if (req.method == 'POST' &&
          path.startsWith('/offer/') &&
          path.endsWith('/pin')) {
        await _onPin(req);
        return;
      }

      if (req.method == 'POST' &&
          path.startsWith('/offer/') &&
          path.endsWith('/file')) {
        await _onFile(req);
        return;
      }

      req.response.statusCode = 404;
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = 500;
        req.response.write('$e');
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _onOffer(HttpRequest req) async {
    final body =
        jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
    final id = body['id'] as String;
    final offer = IncomingOffer(
      id: id,
      fromId: body['fromId'] as String? ?? '',
      fromName: body['fromName'] as String? ?? 'Someone',
      files: (body['files'] as List)
          .map((e) => FileOffer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    _offers[id] = offer;
    incoming = offer;
    notifyListeners();

    final waiter = Completer<IncomingDecision>();
    _waiters[id] = waiter;

    req.response
      ..statusCode = 202
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'id': id}));
    await req.response.close();

    unawaited(Future<void>.delayed(const Duration(minutes: 2), () {
      if (!waiter.isCompleted) {
        waiter.complete(IncomingDecision.rejected);
        if (incoming?.id == id) {
          incoming = null;
          notifyListeners();
        }
      }
    }));
  }

  Future<void> _onPin(HttpRequest req) async {
    final id = req.uri.path.split('/')[2];
    final offer = _offers[id];
    if (offer == null) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
    } catch (_) {
      req.response.statusCode = 400;
      await req.response.close();
      return;
    }
    final pin = '${body['pin'] ?? ''}'.trim();
    if (requirePin && pin == pinCode) {
      offer.pinOk = true;
      offer.decision = IncomingDecision.accepted;
      _waiters.remove(id)?.complete(IncomingDecision.accepted);
      incoming = offer;
      notifyListeners();
      req.response.statusCode = 200;
      await req.response.close();
      return;
    }
    req.response.statusCode = 403;
    req.response.write('bad pin');
    await req.response.close();
  }

  Future<void> _onClipboard(HttpRequest req) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
    } catch (_) {
      req.response.statusCode = 400;
      req.response.write('bad json');
      await req.response.close();
      return;
    }
    final text = (body['text'] as String?) ?? '';
    if (text.isEmpty || text.length > 1000000) {
      req.response.statusCode = 400;
      req.response.write('empty');
      await req.response.close();
      return;
    }
    incoming = IncomingOffer(
      id: 'clip-${DateTime.now().millisecondsSinceEpoch}',
      fromId: body['fromId'] as String? ?? '',
      fromName: body['fromName'] as String? ?? 'Someone',
      files: const [],
      clipboardText: text,
    );
    notifyListeners();
    req.response.statusCode = 202;
    await req.response.close();
  }

  Future<void> _onFile(HttpRequest req) async {
    final id = req.uri.path.split('/')[2];
    final offer = _offers[id];
    if (offer == null || offer.decision != IncomingDecision.accepted) {
      req.response.statusCode = 403;
      await req.response.close();
      return;
    }

    final rawName = req.headers.value('x-filename') ?? 'file';
    final name = Uri.decodeComponent(rawName);
    final safe = p.basename(name);
    final destDir = Directory(saveFolder ?? await defaultSaveFolder());
    if (!destDir.existsSync()) destDir.createSync(recursive: true);
    final dest = File(p.join(destDir.path, _uniqueName(destDir.path, safe)));
    final sink = dest.openWrite();
    await sink.addStream(req);
    await sink.close();

    lastSavedPath = dest.path;
    lastSavedName = safe;
    lastFromName = offer.fromName;
    try {
      lastSavedSize = dest.lengthSync();
    } catch (_) {
      lastSavedSize = 0;
    }
    incoming = null;
    notifyListeners();

    req.response.statusCode = 201;
    await req.response.close();
  }

  String _uniqueName(String dir, String name) {
    var candidate = name;
    var i = 1;
    while (File(p.join(dir, candidate)).existsSync()) {
      final ext = p.extension(name);
      final stem = p.basenameWithoutExtension(name);
      candidate = '$stem ($i)$ext';
      i++;
    }
    return candidate;
  }

  Future<void> setSaveFolder(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    saveFolder = dir.path;
    notifyListeners();
  }

  Future<String> defaultSaveFolder() async {
    if (Platform.isAndroid) {
      const public = '/storage/emulated/0/Download/SendTo';
      try {
        final dir = Directory(public);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final probe = File(p.join(public, '.sendto_write'));
        await probe.writeAsString('ok');
        await probe.delete();
        return public;
      } catch (_) {}
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final dir = Directory(p.join(ext.path, 'SendTo'));
          if (!dir.existsSync()) dir.createSync(recursive: true);
          return dir.path;
        }
      } catch (_) {}
    }
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        final dir = Directory(p.join(downloads.path, 'SendTo'));
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir.path;
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docs.path, 'SendTo'));
    if (!folder.existsSync()) folder.createSync(recursive: true);
    return folder.path;
  }

  void _cors(HttpResponse res) {
    res.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Headers', '*')
      ..set('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  }
}
