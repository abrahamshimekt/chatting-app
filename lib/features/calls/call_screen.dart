import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call_controller.dart';

class CallScreen extends StatefulWidget {
  final String peerId;
  const CallScreen({super.key, required this.peerId});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final CallController ctrl = CallController(peerId: widget.peerId);
  final _local = RTCVideoRenderer();
  final _remote = RTCVideoRenderer();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _local.initialize();
    await _remote.initialize();
    await ctrl.init();
    setState(() {
      _local.srcObject = ctrl.local;
      _remote.srcObject = ctrl.remote;
      ready = true;
    });
  }

  @override
  void dispose() {
    _local.dispose();
    _remote.dispose();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call')),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: RTCVideoView(
                    _remote,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  width: 120,
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(
                      _local,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ctrl.startOffer(),
        label: const Text('Call'),
        icon: const Icon(Icons.call),
      ),
    );
  }
}
