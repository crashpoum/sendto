class HistoryItem {
  HistoryItem({
    required this.id,
    required this.outgoing,
    required this.peerName,
    required this.label,
    required this.size,
    required this.at,
    this.path,
  });

  final String id;
  final bool outgoing;
  final String peerName;
  final String label;
  final int size;
  final DateTime at;
  final String? path;

  Map<String, dynamic> toJson() => {
        'id': id,
        'outgoing': outgoing,
        'peerName': peerName,
        'label': label,
        'size': size,
        'at': at.toIso8601String(),
        'path': path,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String? ?? '',
        outgoing: json['outgoing'] as bool? ?? false,
        peerName: json['peerName'] as String? ?? '',
        label: json['label'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        path: json['path'] as String?,
      );
}
