import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/parsed_receipt.dart';
import 'receipt_heuristic_parser.dart';

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  TextRecognizer? _textRecognizer;

  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  /// Processes an image file using Google ML Kit on-device Text Recognition,
  /// then applies heuristic regex parsing.
  Future<ParsedReceipt> recognizeReceipt(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _recognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      // Feed extracted text to heuristic regex parser
      final parsed = ReceiptHeuristicParser.parse(rawText);
      return parsed;
    } catch (e) {
      // In case ML Kit is running on an unsupported desktop target or device without ML Kit binaries,
      // fallback gracefully to standard heuristic parsing
      return ParsedReceipt(
        rawText: 'OCR Error: ${e.toString()}',
        suggestedCategory: ReceiptHeuristicParser.parse('').suggestedCategory,
        overallConfidence: 0.0,
      );
    }
  }

  /// Direct string parsing utility for testing or mock data
  ParsedReceipt parseRawText(String text) {
    return ReceiptHeuristicParser.parse(text);
  }

  /// Disposes the underlying native TextRecognizer
  void dispose() {
    _textRecognizer?.close();
    _textRecognizer = null;
  }
}

