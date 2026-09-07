import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

// Uses Google ML Kit's on-device image labeling to guess what an item
// photo shows (e.g. "Bag", "Wallet", "Mobile phone"). This runs entirely
// on the device — no API key, no internet connection needed, and no
// data ever leaves the phone.
class ImageRecognitionService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.6),
  );

  Future<List<String>> recognizeLabels(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final labels = await _labeler.processImage(inputImage);

      // Sort by confidence, highest first, and just return the label
      // text — the confidence score itself isn't shown to the user,
      // it's only used internally to decide what's worth suggesting.
      labels.sort((a, b) => b.confidence.compareTo(a.confidence));
      return labels.map((label) => label.label).toList();
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _labeler.close();
  }
}