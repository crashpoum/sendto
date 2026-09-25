import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/peer.dart';

const int kBeaconPort = 47821;
const int kTransferPort = 47822;
const String kBeaconPrefix = 'SENDTO/1';
const String kKnownPeersKey = 'sendto.known_peers';

/// UDP broadcast + multicast presence. Known machines are kept after they drop off.
class DiscoveryService extends ChangeNotifier {
  DiscoveryService({
    required this.self,
  });

  final Peer self;

  RawDatagramSocket? _socket;
  Timer? _announce;
  Timer? _reap;
  Timer? _probe;
  bool _running = false;
  SharedPreferences? _prefs;

  final Map<String, Peer> _peers = {};

  List<Peer> get peers {
    final list = _peers.values.where((p) => p.id != self.id).toList()
      ..sort((a, b) {
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  Future<void> start(SharedPreferences prefs) async {
    _prefs = prefs;
    if (_peers.isEmpty) _loadKnown();
    await _bind();
  }

  Future<void> restart() async {
    final prefs = _prefs;
    await stop();
    if (prefs != null) await start(prefs);
  }

  Future<void> _bind() async {
    _announce?.cancel();
    _reap?.cancel();
    _probe?.cancel();
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    _running = false;

    RawDatagramSocket? sock;
    Object? lastErr;
    for (var i = 0; i < 4; i++) {
      try {
        sock = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          kBeaconPort,
          reuseAddress: true,
          reusePort: Platform.isLinux,
          ttl: 32,
        );
        lastErr = null;
        break;
      } catch (e) {
        lastErr = e;
        await Future<void>.delayed(Duration(milliseconds: 200 * (i + 1)));
      }
    }
    if (sock == null) {
      debugPrint('SendTo discovery bind failed: $lastErr');
      return;
    }

    _socket = sock
      ..broadcastEnabled = true
      ..readEventsEnabled = true
      ..listen(_onDatagram);

    try {
      _socket!.joinMulticast(InternetAddress('239.255.42.42'));
    } catch (_) {}

    _running = true;
    _announce = Timer.periodic(const Duration(seconds: 2), (_) => _sendBeacon());
    _reap = Timer.periodic(const Duration(seconds: 2), (_) {
      notifyListeners();
    });
    _probe?.cancel();
    _probe = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_probeKnown());
    });
    await _sendBeacon();
    notifyListeners();
  }

  Future<void> stop() async {
    _running = false;
    _announce?.cancel();
    _reap?.cancel();
    _probe?.cancel();
    _announce = null;
    _reap = null;
    _probe = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  void forget(String id) {
    if (_peers.remove(id) == null) return;
    _saveKnown();
    notifyListeners();
  }

  Future<void> refresh() async {
    await restart();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _sendBeacon();
    await _probeKnown();
    notifyListeners();
  }

  Future<void> _sendBeacon() async {
    final sock = _socket;
    if (sock == null) return;
    final payload = utf8.encode('$kBeaconPrefix${jsonEncode(self.toBeacon())}');
    try {
      sock.send(payload, InternetAddress('255.255.255.255'), kBeaconPort);
    } catch (_) {}
    try {
      sock.send(payload, InternetAddress('239.255.42.42'), kBeaconPort);
    } catch (_) {}
    for (final peer in _peers.values) {
      if (peer.id == self.id) continue;
      final ip = peer.ip;
      if (ip.isEmpty || ip == '0.0.0.0') continue;
      try {
        sock.send(payload, InternetAddress(ip), kBeaconPort);
      } catch (_) {}
    }
  }

  Future<void> _probeKnown() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      for (final peer in _peers.values.toList()) {
        if (peer.id == self.id) continue;
        if (peer.ip.isEmpty || peer.ip == '0.0.0.0') continue;
        try {
          final req = await client.getUrl(
            Uri.parse('http://${peer.ip}:${peer.port}/health'),
          );
          final res = await req.close().timeout(const Duration(seconds: 2));
          await res.drain<void>();
          if (res.statusCode == 200) {
            peer.lastSeen = DateTime.now();
          }
        } catch (_) {}
      }
    } finally {
      client.close(force: true);
    }
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _socket?.receive();
    if (dg == null) return;
    final text = utf8.decode(dg.data, allowMalformed: true);
    if (!text.startsWith(kBeaconPrefix)) return;
    try {
      final json = jsonDecode(text.substring(kBeaconPrefix.length))
          as Map<String, dynamic>;
      final id = json['id'] as String?;
      if (id == null || id == self.id) return;
      final seen = Peer.fromBeacon(json, dg.address.address);
      _peers[id] = seen;
      _saveKnown();
      notifyListeners();
    } catch (_) {}
  }

  void _loadKnown() {
    final raw = _prefs?.getString(kKnownPeersKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final peer = Peer.fromStore(item as Map<String, dynamic>);
        if (peer.id == self.id) continue;
        _peers[peer.id] = peer;
      }
    } catch (_) {}
  }

  void _saveKnown() {
    final list = _peers.values.map((p) => p.toStore()).toList();
    _prefs?.setString(kKnownPeersKey, jsonEncode(list));
  }
}
