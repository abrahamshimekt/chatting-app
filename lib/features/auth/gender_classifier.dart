// lib/features/auth/gender_classifier.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Helper to extract ARGB channels from an int pixel (Image package v4+).
int _r(int pixel) => (pixel >> 24) & 0xFF;
int _g(int pixel) => (pixel >> 16) & 0xFF;
int _b(int pixel) => (pixel >> 8) & 0xFF;
int _a(int pixel) => pixel & 0xFF; // not used, but here if needed

class GenderClassifier {
  /// Path to your TFLite gender model (float / non-quantized).
  final String modelAsset;

  /// Labels file with exactly 2 lines (e.g., "male" and "female").
  final String labelsAsset;

  /// Model input size (width == height). Use 128 for many lite MobileNet models.
  final int inputSize;

  /// If your model expects [-1,1] normalization, set this to true.
  /// Most non-quant MobileNet variants take [0,1], so keep false by default.
  final bool normalizeToMinusOneToOne;

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _loaded = false;

  GenderClassifier({
    this.modelAsset = 'assets/ml/model_lite_gender_nonq.tflite',
    this.labelsAsset = 'assets/ml/labels.txt',
    this.inputSize = 128,
    this.normalizeToMinusOneToOne = false,
  });

  /// Load labels + model into the interpreter.
  Future<void> load() async {
    // Load labels
    final raw = await rootBundle.loadString(labelsAsset);
    _labels = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (_labels.length < 2) {
      throw Exception(
        'labels.txt must contain at least two lines (e.g., male, female)',
      );
    }

    // Load model into memory
    final model = await rootBundle.load(modelAsset);
    _interpreter = Interpreter.fromBuffer(model.buffer.asUint8List());
    _loaded = true;
  }

  void close() {
    if (_loaded) {
      _interpreter.close();
      _loaded = false;
    }
  }

  /// Classify an image file (ideally a face crop). Returns (label, confidence 0..1).
  ///
  /// If you pass a full selfie, we still center-crop to square as a safety net,
  /// but for best results crop tightly to the face beforehand.
  Future<(String, double)> classifyImageFile(String imagePath) async {
    if (!_loaded) {
      throw Exception('GenderClassifier not loaded. Call load() first.');
    }

    // Decode image
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode image: $imagePath');
    }

    // Center-crop to square (if not already)
    final side = math.min(decoded.width, decoded.height);
    final sx = ((decoded.width - side) / 2).floor();
    final sy = ((decoded.height - side) / 2).floor();
    final square = img.copyCrop(
      decoded,
      x: sx,
      y: sy,
      width: side,
      height: side,
    );

    // Resize to model input
    final resized = img.copyResize(square, width: inputSize, height: inputSize);

    // Build NHWC float32 tensor: [1, H, W, 3]
    final floats = Float32List(inputSize * inputSize * 3);
    int i = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        final rr = pixel.r / 255.0;
        final gg = pixel.g / 255.0;
        final bb = pixel.b / 255.0;

        if (normalizeToMinusOneToOne) {
          floats[i++] = (rr * 2.0) - 1.0;
          floats[i++] = (gg * 2.0) - 1.0;
          floats[i++] = (bb * 2.0) - 1.0;
        } else {
          floats[i++] = rr;
          floats[i++] = gg;
          floats[i++] = bb;
        }
      }
    }
    final input = floats.reshape([1, inputSize, inputSize, 3]);

    // Allocate output [1, numLabels]
    final output = List.filled(
      _labels.length,
      0.0,
    ).reshape([1, _labels.length]);

    // Run inference
    _interpreter.run(input, output);

    final scores = (output[0] as List<double>);
    final probs = _softmax(scores);

    // Argmax
    int best = 0;
    for (int j = 1; j < probs.length; j++) {
      if (probs[j] > probs[best]) best = j;
    }
    final label = _labels[best].toLowerCase().trim();
    final confidence = probs[best];

    return (label, confidence);
  }

  // Stable softmax that handles logits or unnormalized scores
  List<double> _softmax(List<double> x) {
    final m = x.reduce(math.max);
    final exps = x.map((v) => math.exp(v - m)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}
