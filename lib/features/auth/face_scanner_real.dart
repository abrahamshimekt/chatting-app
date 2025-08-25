import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'gender_classifier.dart';
import 'selfie_scan_screen.dart';
import 'face_scanner.dart';

class RealFaceScanner implements FaceScanner {
  RealFaceScanner({
    required this.context,
    this.minConfidence = 0.60,
  });

  final BuildContext context;
  final double minConfidence;

  @override
  Future<String> detectGender() async {
    // 1) open selfie capture UI
    final imagePath = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const SelfieScanScreen()),
    );
    if (imagePath == null) {
      throw Exception('Selfie cancelled');
    }

    // 2) detect face on the final photo and crop tightly
    final cropped = await _cropFace(imagePath);

    // 3) run TFLite classifier
    final clf = GenderClassifier(
      modelAsset: 'assets/ml/model_lite_gender_nonq.tflite',
      labelsAsset: 'assets/ml/labels.txt',
      inputSize: 128,
      normalizeToMinusOneToOne: false,
    );
    await clf.load();
    final (label, conf) = await clf.classifyImageFile(cropped);
    clf.close();

    if (conf < minConfidence) {
      throw Exception('Low confidence (${(conf * 100).toStringAsFixed(1)}%). Retake selfie in better light.');
    }

    final normalized = label.trim().toLowerCase();
    if (normalized != 'male' && normalized != 'female') {
      throw Exception('Model returned unknown label: $label');
    }
    return normalized;
  }

  Future<String> _cropFace(String imagePath) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableContours: false,
        minFaceSize: 0.15,
      ),
    );

    final input = InputImage.fromFilePath(imagePath);
    final faces = await detector.processImage(input);
    await detector.close();

    if (faces.isEmpty) throw Exception('No face found. Try again.');
    // Choose the largest face (in case of multiple)
    faces.sort((a, b) => b.boundingBox.width.compareTo(a.boundingBox.width));
    final box = faces.first.boundingBox;

    final fileBytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(fileBytes);
    if (decoded == null) throw Exception('Failed to decode selfie');

    // Convert ML Kit rect to image coordinates safely
    final x = box.left.clamp(0, decoded.width.toDouble()).floor();
    final y = box.top.clamp(0, decoded.height.toDouble()).floor();
    final w = box.width.clamp(1, (decoded.width - x).toDouble()).floor();
    final h = box.height.clamp(1, (decoded.height - y).toDouble()).floor();

    // Pad a bit around the face
    final pad = (0.15 * math.min(w, h)).floor();
    final cx = math.max(0, x - pad);
    final cy = math.max(0, y - pad);
    final cw = math.min(decoded.width - cx, w + 2 * pad);
    final ch = math.min(decoded.height - cy, h + 2 * pad);

    final cropped = img.copyCrop(decoded, x: cx, y: cy, width: cw, height: ch);

    final outPath = '${(await getTemporaryDirectory()).path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(outPath).writeAsBytes(img.encodeJpg(cropped, quality: 95));
    return outPath;
  }
}
