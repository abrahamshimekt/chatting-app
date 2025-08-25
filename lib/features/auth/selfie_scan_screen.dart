import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show WriteBuffer; // for WriteBuffer
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart'
    show
        InputImage,
        InputImageFormat,
        InputImageFormatValue,
        InputImageMetadata,
        InputImageRotation;
import 'package:path_provider/path_provider.dart';

class SelfieScanScreen extends StatefulWidget {
  const SelfieScanScreen({super.key});

  @override
  State<SelfieScanScreen> createState() => _SelfieScanScreenState();
}

class _SelfieScanScreenState extends State<SelfieScanScreen> {
  CameraController? _controller;
  late final FaceDetector _detector;
  bool _initializing = true;
  bool _detecting = false;
  bool _faceOk = false;

  @override
  void initState() {
    super.initState();
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
        enableTracking: false,
        minFaceSize: 0.15, // face should occupy at least 15% of the frame
      ),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    // Prefer front camera if available
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _controller!.startImageStream(_onFrame);
    setState(() => _initializing = false);
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_detecting || _controller == null) return;
    _detecting = true;
    try {
      final input = _cameraImageToInputImage(
        img,
        _controller!.description.sensorOrientation,
      );
      final faces = await _detector.processImage(input);

      setState(() {
        _faceOk = faces.length == 1; // simple rule: exactly one face
      });
    } catch (_) {
      // ignore frame errors
    } finally {
      _detecting = false;
    }
  }

  InputImage _cameraImageToInputImage(CameraImage image, int rotation) {
    // Concatenate YUV planes
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final size = Size(image.width.toDouble(), image.height.toDouble());

    final inputRotation = _rotationIntToImageRotation(rotation);

    final inputFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    // New API: only one bytesPerRow is required
    final metadata = InputImageMetadata(
      size: size,
      rotation: inputRotation,
      format: inputFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _capture() async {
    if (!(_controller?.value.isInitialized ?? false)) return;
    if (!_faceOk) return; // enforce face presence before capture

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _controller!.stopImageStream(); // stop stream before taking a photo
    final shot = await _controller!.takePicture();
    await shot.saveTo(path);

    if (!mounted) return;
    Navigator.pop(context, path); // return the saved selfie path
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing || !(_controller?.value.isInitialized ?? false)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Selfie verification')),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Text(
                  _faceOk
                      ? 'Face detected, hold steady.'
                      : 'Center your face in the frame.',
                  style: TextStyle(
                    color: _faceOk ? Colors.greenAccent : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _faceOk ? _capture : null,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
