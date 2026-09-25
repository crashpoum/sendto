import 'package:flutter/material.dart';

/// Muted identity tiles — stable per device id, same on every theme.
const List<Color> kIdentityTiles = [
  Color(0xFFC9D7E8), // dusty blue
  Color(0xFFD3E2D4), // sage
  Color(0xFFE8DCC8), // sand
  Color(0xFFE2D4E8), // lilac
  Color(0xFFD8E4E0), // mist
  Color(0xFFE8D0D0), // rose
  Color(0xFFD4DCEC), // periwinkle
  Color(0xFFE4E0D0), // khaki
];

class Peer {
  Peer({
    required this.id,
    required this.name,
    required this.os,
    required this.ip,
    required this.port,
    required this.colorIndex,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  final String id;
  String name;
  final String os;
  String ip;
  final int port;
  final int colorIndex;
  DateTime lastSeen;

  Color get tileColor =>
      kIdentityTiles[colorIndex.abs() % kIdentityTiles.length];

  IconData get glyph {
    switch (os) {
      case 'android':
      case 'ios':
        return Icons.smartphone_outlined;
      case 'linux':
        return Icons.laptop_outlined;
      case 'macos':
        return Icons.laptop_mac_outlined;
      default:
        return Icons.desktop_windows_outlined;
    }
  }

  String get osLabel {
    switch (os) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'linux':
        return 'Linux';
      case 'macos':
        return 'macOS';
      default:
        return 'Windows';
    }
  }

  Uri get baseUri => Uri.parse('http://$ip:$port');

  bool get isOnline =>
      DateTime.now().difference(lastSeen) < const Duration(seconds: 8);

  factory Peer.fromBeacon(Map<String, dynamic> json, String ip) {
    return Peer(
      id: json['id'] as String,
      name: prettyDeviceName(json['name'] as String?, json['os'] as String?),
      os: json['os'] as String? ?? 'windows',
      ip: ip,
      port: (json['port'] as num?)?.toInt() ?? 47822,
      colorIndex: (json['color'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toBeacon() => {
        'id': id,
        'name': name,
        'os': os,
        'port': port,
        'color': colorIndex,
      };

  Map<String, dynamic> toStore() => {
        'id': id,
        'name': name,
        'os': os,
        'ip': ip,
        'port': port,
        'color': colorIndex,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory Peer.fromStore(Map<String, dynamic> json) {
    return Peer(
      id: json['id'] as String,
      name: prettyDeviceName(json['name'] as String?, json['os'] as String?),
      os: json['os'] as String? ?? 'windows',
      ip: json['ip'] as String? ?? '0.0.0.0',
      port: (json['port'] as num?)?.toInt() ?? 47822,
      colorIndex: (json['color'] as num?)?.toInt() ?? 0,
      lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

String prettyDeviceName(String? raw, String? os) {
  final name = (raw ?? '').trim();
  if (!isGenericDeviceName(name)) return name;
  switch (os) {
    case 'android':
      return 'Phone';
    case 'ios':
      return 'iPhone';
    case 'linux':
      return 'Linux box';
    case 'macos':
      return 'Mac';
    default:
      return 'Windows PC';
  }
}

bool isGenericDeviceName(String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
  return n.isEmpty ||
      n == 'localhost' ||
      n == 'localhost.localdomain' ||
      n == 'android' ||
      n == 'androidphone' ||
      n == 'androidtablet' ||
      n == 'unknown' ||
      n.startsWith('android');
}

int colorIndexForId(String id) {
  var hash = 0;
  for (final u in id.codeUnits) {
    hash = 0x1fffffff & (hash + u);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return hash.abs() % kIdentityTiles.length;
}
