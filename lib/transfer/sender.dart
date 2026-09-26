import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../models/peer.dart';
import '../models/transfer.dart';

class Sender {
  Future<void> send({
    required Peer peer,
    required String fromId,
    required String fromName,
    required OutgoingTransfer transfer,
    required void Function() onUpdate,
    required bool Function() isCancelled,
  }) async {
    final id = const Uuid().v4();
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final offerReq = await client.postUrl(peer.baseUri.replace(path: '/offer'));
      offerReq.headers.contentType = ContentType.json;
      offerReq.add(utf8.encode(jsonEncode({
        'id': id,
        'fromId': fromId,
        'fromName': fromName,
        'files': transfer.files.map((f) => f.toJson()).toList(),
      })));
      final offerRes = await offerReq.close();
      if (offerRes.statusCode != 202) {
        throw Exception('The other machine did not accept the offer');
      }
      await offerRes.drain<void>();

      transfer.phase = SendPhase.waiting;
      onUpdate();

      IncomingDecision decision = IncomingDecision.pending;
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (DateTime.now().isBefore(deadline)) {
        if (isCancelled()) {
          transfer.phase = SendPhase.cancelled;
          onUpdate();
          return;
        }
        final statusReq =
            await client.getUrl(peer.baseUri.replace(path: '/offer/$id/status'));
        final statusRes = await statusReq.close();
        final body = jsonDecode(await utf8.decodeStream(statusRes))
            as Map<String, dynamic>;
        final raw = body['status'] as String? ?? 'pending';
        final needPin = body['needPin'] == true;
        if (needPin) {
          transfer.needsPin = true;
          onUpdate();
          final pin = transfer.pin;
          if (pin != null && pin.length >= 4) {
            transfer.pin = null;
            try {
              final pinReq = await client.postUrl(
                peer.baseUri.replace(path: '/offer/$id/pin'),
              );
              final payload = utf8.encode(jsonEncode({'pin': pin}));
              pinReq.headers.contentType = ContentType.json;
              pinReq.contentLength = payload.length;
              pinReq.add(payload);
              final pinRes = await pinReq.close();
              await pinRes.drain<void>();
              if (pinRes.statusCode != 200) {
                transfer.error = 'Wrong PIN';
                onUpdate();
              }
            } catch (e) {
              transfer.error = e.toString();
              onUpdate();
            }
          }
        }
        if (raw == 'accepted') {
          decision = IncomingDecision.accepted;
          break;
        }
        if (raw == 'rejected' || raw == 'missing') {
          decision = IncomingDecision.rejected;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

      if (decision != IncomingDecision.accepted) {
        transfer.phase = SendPhase.cancelled;
        transfer.error = 'Declined';
        onUpdate();
        return;
      }

      transfer.phase = SendPhase.transferring;
      onUpdate();

      for (final file in transfer.files) {
        if (isCancelled()) {
          transfer.phase = SendPhase.cancelled;
          onUpdate();
          return;
        }
        if (file.path == null) continue;
        final onDisk = File(file.path!);
        var length = file.size;
        try {
          final diskLen = await onDisk.length();
          if (diskLen > 0) length = diskLen;
        } catch (_) {}
        final req =
            await client.postUrl(peer.baseUri.replace(path: '/offer/$id/file'));
        req.headers.set('x-filename', Uri.encodeComponent(file.name));
        if (length > 0) {
          req.headers.contentLength = length;
        }
        final stream = onDisk.openRead();
        await for (final chunk in stream) {
          if (isCancelled()) {
            req.abort();
            transfer.phase = SendPhase.cancelled;
            onUpdate();
            return;
          }
          req.add(chunk);
          transfer.bytesSent += chunk.length;
          onUpdate();
        }
        final res = await req.close();
        if (res.statusCode != 201) {
          throw Exception('Transfer failed (${res.statusCode})');
        }
        await res.drain<void>();
      }

      transfer.phase = SendPhase.done;
      onUpdate();
    } catch (e) {
      transfer.phase = SendPhase.failed;
      final raw = e.toString();
      transfer.error = raw.length > 180 ? '${raw.substring(0, 180)}…' : raw;
      onUpdate();
    } finally {
      client.close(force: true);
    }
  }
}
