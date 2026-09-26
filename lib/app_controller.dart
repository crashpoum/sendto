import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'android_permissions.dart';
import 'discovery/discovery_service.dart';
import 'models/peer.dart';
import 'models/transfer.dart';
import 'transfer/receive_server.dart';
import 'transfer/sender.dart';

class AppController extends ChangeNotifier {
  AppController();

  late Peer self;
  late DiscoveryService discovery;
  final ReceiveServer receiver = ReceiveServer();
  final Sender sender = Sender();

  OutgoingTransfer? outgoing;
  bool _cancelSend = false;

  IncomingOffer? get incoming => receiver.incoming;
  List<Peer> get peers => discovery.peers;
  String? get saveFolder => receiver.saveFolder;

  Future<void> start() async {
    await requestAndroidPermissions();
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('sendto.id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('sendto.id', id);
    }
    final os = _osName();
    final name = await _deviceName(prefs, os);
    self = Peer(
      id: id,
      name: name,
      os: os,
      ip: '0.0.0.0',
      port: kTransferPort,
      colorIndex: colorIndexForId(id),
    );
    discovery = DiscoveryService(self: self);
    discovery.addListener(notifyListeners);
    receiver.addListener(notifyListeners);

    final savedFolder = prefs.getString('sendto.save_folder');
    if (savedFolder != null && savedFolder.trim().isNotEmpty) {
      receiver.saveFolder = savedFolder.trim();
    }
    await receiver.start();
    await discovery.start(prefs);
    notifyListeners();
  }

  Future<void> refreshPeers() async {
    await receiver.restart();
    await discovery.refresh();
  }

  void forgetPeer(Peer peer) => discovery.forget(peer.id);

  Future<void> chooseSaveFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null || path.trim().isEmpty) return;
    await setSaveFolder(path);
  }

  Future<void> setSaveFolder(String path) async {
    await receiver.setSaveFolder(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sendto.save_folder', receiver.saveFolder ?? path);
    notifyListeners();
  }

  Future<void> resetSaveFolder() async {
    final path = await receiver.defaultSaveFolder();
    await setSaveFolder(path);
  }

  Future<void> renameSelf(String next) async {
    final trimmed = next.trim();
    if (trimmed.isEmpty || trimmed == self.name) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sendto.name', trimmed);
    self.name = trimmed;
    notifyListeners();
  }

  Future<void> sendTo(Peer peer, List<FileOffer> files) async {
    _cancelSend = false;
    outgoing = OutgoingTransfer(peerName: peer.name, files: files);
    notifyListeners();
    await sender.send(
      peer: peer,
      fromId: self.id,
      fromName: self.name,
      transfer: outgoing!,
      onUpdate: notifyListeners,
      isCancelled: () => _cancelSend,
    );
  }

  void cancelSend() {
    _cancelSend = true;
    notifyListeners();
  }

  void dismissOutgoing() {
    outgoing = null;
    notifyListeners();
  }

  void acceptIncoming() {
    final clip = receiver.incoming?.clipboardText;
    receiver.decide(IncomingDecision.accepted);
    if (clip != null) {
      Clipboard.setData(ClipboardData(text: clip));
      receiver.clearIncoming();
    }
  }

  void rejectIncoming() => receiver.decide(IncomingDecision.rejected);

  Future<String?> sendClipboard(Peer peer) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return 'Clipboard is empty';
    if (text.length > 1000000) return 'Clipboard is too large';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final payload = utf8.encode(jsonEncode({
        'fromId': self.id,
        'fromName': self.name,
        'text': text,
      }));
      final req = await client.postUrl(peer.baseUri.replace(path: '/clipboard'));
      req.headers.contentType = ContentType.json;
      req.contentLength = payload.length;
      req.add(payload);
      final res = await req.close();
      await res.drain<void>();
      if (res.statusCode != 200 && res.statusCode != 202) {
        return 'The other machine did not accept it (${res.statusCode})';
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _deviceName(SharedPreferences prefs, String os) async {
    final saved = prefs.getString('sendto.name');
    if (saved != null &&
        saved.trim().isNotEmpty &&
        !isGenericDeviceName(saved)) {
      return saved.trim();
    }
    var host = '';
    try {
      host = Platform.localHostname.trim();
    } catch (_) {}
    final pretty = prettyDeviceName(host, os);
    await prefs.setString('sendto.name', pretty);
    return pretty;
  }

  String _osName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'windows';
  }
}
