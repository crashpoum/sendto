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

  Future<void> start() async {
    saveFolder ??= await defaultSaveFolder();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, kTransferPort);
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void decide(IncomingDecision decision) {
    final offer = incoming;
    if (offer == null) return;
    offer.decision = decision;
    _waiters.remove(offer.id)?.complete(decision);
    if (decision == IncomingDecision.rejected) {
      incoming = null;
      notifyListeners();
    } else {
      notifyListeners();
    }
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

      final path = req.uri.path;
      if (req.method == 'GET' && path == '/health') {
        req.response
          ..statusCode = 200
          ..write('ok');
        await req.response.close();
        return;
      }

      if (req.method == 'POST' && path == '/offer') {
        await _onOffer(req);
        return;
      }

      if (req.method == 'GET' && path.startsWith('/offer/') && path.endsWith('/status')) {
        final id = path.split('/')[2];
        final offer = _offers[id];
        req.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'status': offer?.decision.name ?? 'missing',
          }));
        await req.response.close();
        return;
      }

      if (req.method == 'POST' && path.startsWith('/offer/') && path.endsWith('/file')) {
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
    final body = jsonDecode(await utf8.decodeStream(req)) as Map<String, dynamic>;
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

    // Sender polls /status. We just ack that the offer landed.
    req.response
      ..statusCode = 202
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'id': id}));
    await req.response.close();

    // Don't leak waiters if the user never answers.
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
    final destDir = Directory(saveFolder!);
    if (!destDir.existsSync()) destDir.createSync(recursive: true);
    final dest = File(p.join(destDir.path, _uniqueName(destDir.path, safe)));
    final sink = dest.openWrite();
    await sink.addStream(req);
    await sink.close();

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
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads.path;
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
