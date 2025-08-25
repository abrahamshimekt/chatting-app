import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/supa.dart';

class CallController {
  RTCPeerConnection? pc;
  MediaStream? local;
  MediaStream? remote;
  final String peerId;

  CallController({required this.peerId});

  late final RealtimeChannel channel = supa.channel('call_${_roomKey()}');

  String _roomKey() {
    final me = supa.auth.currentUser!.id;
    final ids = [me, peerId]..sort();
    return ids.join('_');
  }

  Future<void> init() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    pc = await createPeerConnection(config);

    // Local media
    local = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
    // Prefer addTrack in newer webrtc versions
    for (final t in local!.getTracks()) {
      await pc!.addTrack(t, local!);
    }

    // Remote stream
    pc!.onAddStream = (s) =>
        remote = s; // if deprecated in your version, use pc!.onTrack

    // ICE candidates -> broadcast
    pc!.onIceCandidate = (c) {
      if (c.candidate != null) {
        channel.sendBroadcastMessage(
          event: 'ice',
          payload: {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          },
        );
      }
    };

    // Listen for ICE from peer
    channel.onBroadcast(
      event: 'ice',
      callback: (payload) async {
        final cand = RTCIceCandidate(
          payload['candidate'] as String?,
          payload['sdpMid'] as String?,
          payload['sdpMLineIndex'] as int?,
        );
        await pc!.addCandidate(cand);
      },
    );

    // Listen for SDP (offer/answer)
    channel.onBroadcast(
      event: 'sdp',
      callback: (payload) async {
        final type = payload['type'] as String;
        final sdp = payload['sdp'] as String;
        final desc = RTCSessionDescription(sdp, type);
        await pc!.setRemoteDescription(desc);

        if (type == 'offer') {
          final answer = await pc!.createAnswer();
          await pc!.setLocalDescription(answer);
          await channel.sendBroadcastMessage(
            event: 'sdp',
            payload: {'type': 'answer', 'sdp': answer.sdp},
          );
        }
      },
    );

    await channel.subscribe();
  }

  // Caller starts here
  Future<void> startOffer() async {
    final offer = await pc!.createOffer();
    await pc!.setLocalDescription(offer);
    await channel.sendBroadcastMessage(
      event: 'sdp',
      payload: {'type': 'offer', 'sdp': offer.sdp},
    );
  }

  void dispose() {
    channel.unsubscribe();
    local?.getTracks().forEach((t) => t.stop());
    remote?.getTracks().forEach((t) => t.stop());
    pc?.close();
  }
}
