/// Abstraction so you can swap in a real SDK later.
abstract class FaceScanner {
  /// Should perform a liveness/face scan and return the detected gender.
  /// Return values MUST be 'male' or 'female'.
  Future<String> detectGender();
}

/// DEV mock: simulates a short scan delay and returns a value.
/// Replace with a real implementation (e.g., platform channel or vendor SDK).
class MockFaceScanner implements FaceScanner {
  final String demoDetectedGender;
  MockFaceScanner({required this.demoDetectedGender});
  @override
  Future<String> detectGender() async {
    await Future.delayed(const Duration(seconds: 1)); // simulate scan time
    return demoDetectedGender; // for demo/dev only
  }
}
