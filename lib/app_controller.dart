import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'android_permissions.dart';
import 'discovery/discovery_service.dart';
import 'models/history.dart';
import 'models/peer.dart';
import 'models/transfer.dart';
import 'transfer/receive_server.dart';
import 'transfer/sender.dart';
import 'util/zip_folder.dart';

class AppController extends ChangeNotifier {
  AppController();

  late Peer self;
  late DiscoveryService discovery;
  final ReceiveServer receiver = ReceiveServer();
  final Sender sender = Sender();

  OutgoingTransfer? outgoing;
  bool _cancelSend = false;
  SharedPreferences? _prefs;
  final List<HistoryItem> history = [];
  String? _recordedSave;

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
    _prefs = prefs;
    _loadHistory();
    discovery = DiscoveryService(self: self);
    discovery.addListener(notifyListeners);
    receiver.addListener(() {
      notifyListeners();
      final saved = receiver.lastSavedPath;
      if (saved != null && saved != _recordedSave) {
        _recordedSave = saved;
        addHistory(HistoryItem(
          id: const Uuid().v4(),
          outgoing: false,
          peerName: receiver.lastFromName ?? 'Someone',
          label: receiver.lastSavedName ?? p.basename(saved),
          size: receiver.lastSavedSize,
          at: DateTime.now(),
          path: saved,
        ));
      }
    });

    final savedFolder = prefs.getString('sendto.save_folder');
    if (savedFolder != null && savedFolder.trim().isNotEmpty) {
      receiver.saveFolder = savedFolder.trim();
    }
    receiver.requirePin = prefs.getBool('sendto.require_pin') ?? false;
    receiver.pinCode = prefs.getString('sendto.pin') ?? _freshPin();
    if (prefs.getString('sendto.pin') == null) {
      await prefs.setString('sendto.pin', receiver.pinCode);
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

  Future<String?> addManualHost(String raw) => discovery.addManualHost(raw);

  void submitOutgoingPin(String pin) {
    outgoing?.pin = pin.trim();
    outgoing?.error = null;
    notifyListeners();
  }

  Future<void> setRequirePin(bool value) async {
    receiver.requirePin = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sendto.require_pin', value);
    notifyListeners();
  }

  Future<void> rotatePin() async {
    receiver.pinCode = _freshPin();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sendto.pin', receiver.pinCode);
    notifyListeners();
  }

  String _freshPin() {
    final n = DateTime.now().millisecondsSinceEpoch % 10000;
    return n.toString().padLeft(4, '0');
  }

  Future<String?> sendFolder(Peer peer, String dir) async {
    try {
      final zip = await zipFolder(dir);
      await sendTo(peer, [zip]);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

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
    final result = outgoing;
    if (result != null && result.phase == SendPhase.done) {
      addHistory(HistoryItem(
        id: const Uuid().v4(),
        outgoing: true,
        peerName: peer.name,
        label: result.files.map((f) => f.name).join(', '),
        size: result.bytesTotal,
        at: DateTime.now(),
        path: result.files.isEmpty ? null : result.files.first.path,
      ));
    }
  }

  void addHistory(HistoryItem item) {
    history.insert(0, item);
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    _saveHistory();
    notifyListeners();
  }

  void clearHistory() {
    history.clear();
    _saveHistory();
    notifyListeners();
  }

  void _loadHistory() {
    final raw = _prefs?.getString('sendto.history');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      history
        ..clear()
        ..addAll(list.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>)));
    } catch (_) {}
  }

  void _saveHistory() {
    _prefs?.setString(
      'sendto.history',
      jsonEncode(history.map((e) => e.toJson()).toList()),
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
      addHistory(HistoryItem(
        id: const Uuid().v4(),
        outgoing: false,
        peerName: receiver.incoming?.fromName ?? 'Someone',
        label: 'Clipboard',
        size: clip.length,
        at: DateTime.now(),
      ));
      receiver.clearIncoming();
    }
  }

  void rejectIncoming() => receiver.decide(IncomingDecision.rejected);

  Future<String?> sendClipboard(Peer peer) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      try {
        final bytes = await Pasteboard.image;
        if (bytes != null && bytes.isNotEmpty) {
          final tmp = await getTemporaryDirectory();
          final file = File(p.join(tmp.path, 'clipboard.png'));
          await file.writeAsBytes(bytes, flush: true);
          await sendTo(peer, [
            FileOffer(
              name: 'clipboard.png',
              size: bytes.length,
              path: file.path,
            ),
          ]);
          return null;
        }
      } catch (_) {}
      return 'Clipboard is empty';
    }
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
      final raw = await utf8.decodeStream(res);
      if (res.statusCode != 200 && res.statusCode != 202) {
        return 'Clipboard failed ${res.statusCode} ${peer.ip}$raw';
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
