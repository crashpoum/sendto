class FileOffer {
  FileOffer({
    required this.name,
    required this.size,
    this.path,
  });

  final String name;
  final int size;
  final String? path;

  Map<String, dynamic> toJson() => {'name': name, 'size': size};

  factory FileOffer.fromJson(Map<String, dynamic> json) => FileOffer(
        name: json['name'] as String,
        size: (json['size'] as num).toInt(),
      );
}

enum IncomingDecision { pending, accepted, rejected }

class IncomingOffer {
  IncomingOffer({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.files,
  });

  final String id;
  final String fromId;
  final String fromName;
  final List<FileOffer> files;
  IncomingDecision decision = IncomingDecision.pending;
}

enum SendPhase { waiting, transferring, done, failed, cancelled }

class OutgoingTransfer {
  OutgoingTransfer({
    required this.peerName,
    required this.files,
  });

  final String peerName;
  final List<FileOffer> files;
  SendPhase phase = SendPhase.waiting;
  int bytesSent = 0;
  int get bytesTotal => files.fold(0, (a, f) => a + f.size);
  String? error;

  double get progress {
    if (bytesTotal <= 0) return 0;
    return (bytesSent / bytesTotal).clamp(0.0, 1.0);
  }
}
