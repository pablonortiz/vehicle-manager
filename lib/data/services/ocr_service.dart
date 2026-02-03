import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final double? value;
  final String? rawText;
  final String? fullText; // Full OCR text for debugging
  final bool success;

  OcrResult({
    this.value,
    this.rawText,
    this.fullText,
    required this.success,
  });

  factory OcrResult.failure([String? fullText]) => OcrResult(success: false, fullText: fullText);

  factory OcrResult.found(double value, String rawText, [String? fullText]) =>
      OcrResult(value: value, rawText: rawText, fullText: fullText, success: true);
}

class OcrService {
  static final OcrService instance = OcrService._internal();
  OcrService._internal();

  TextRecognizer? _textRecognizer;

  TextRecognizer get textRecognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
  }

  // Extract liters from a pump display photo
  Future<OcrResult> extractLiters(File imageFile) async {
    try {
      debugPrint('OCR: Starting liters extraction from ${imageFile.path}');

      if (!await imageFile.exists()) {
        debugPrint('OCR Error: File does not exist');
        return OcrResult.failure();
      }

      final inputImage = InputImage.fromFile(imageFile);
      debugPrint('OCR: InputImage created, processing...');

      final recognizedText = await textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text;

      debugPrint('OCR Text for liters (${fullText.length} chars): $fullText');

      // Try different patterns for liters
      final patterns = [
        // "45.50 L" or "45,50 L"
        RegExp(r'(\d{1,3}[.,]\d{1,3})\s*[Ll](?:itros?)?', caseSensitive: false),
        // "Litros: 45.50" or "Litros 45,50"
        RegExp(r'[Ll]itros?:?\s*(\d{1,3}[.,]\d{1,3})', caseSensitive: false),
        // "Vol: 45.50" or "VOL 45,50"
        RegExp(r'[Vv][Oo][Ll](?:umen)?:?\s*(\d{1,3}[.,]\d{1,3})'),
        // Standalone decimal number that looks like liters (typically 10-100 range)
        RegExp(r'\b(\d{1,2}[.,]\d{1,3})\b'),
      ];

      if (fullText.isEmpty) {
        debugPrint('OCR: No text recognized in image');
        return OcrResult.failure(fullText);
      }

      for (final pattern in patterns) {
        final match = pattern.firstMatch(fullText);
        if (match != null) {
          final rawValue = match.group(1)!;
          final normalizedValue = rawValue.replaceAll(',', '.');
          final value = double.tryParse(normalizedValue);

          debugPrint('OCR: Pattern matched "$rawValue", parsed as $value');

          if (value != null && value > 0 && value <= 200) {
            debugPrint('OCR: Liters extracted: $value from "$rawValue"');
            return OcrResult.found(value, rawValue, fullText);
          }
        }
      }

      debugPrint('OCR: No valid liters pattern found in text');
      return OcrResult.failure(fullText);
    } catch (e, stack) {
      debugPrint('OCR Error extracting liters: $e');
      debugPrint('OCR Stack trace: $stack');
      return OcrResult.failure();
    }
  }

  // Extract price from a receipt photo
  Future<OcrResult> extractPrice(File imageFile) async {
    try {
      debugPrint('OCR: Starting price extraction from ${imageFile.path}');

      if (!await imageFile.exists()) {
        debugPrint('OCR Error: File does not exist');
        return OcrResult.failure();
      }

      final inputImage = InputImage.fromFile(imageFile);
      debugPrint('OCR: InputImage created, processing...');

      final recognizedText = await textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text;

      debugPrint('OCR Text for price (${fullText.length} chars): $fullText');

      if (fullText.isEmpty) {
        debugPrint('OCR: No text recognized in image');
        return OcrResult.failure(fullText);
      }

      // Try different patterns for Argentine prices
      final patterns = [
        // "Total: $45.000,50" or "TOTAL $45.000,50"
        RegExp(r'[Tt][Oo][Tt][Aa][Ll]:?\s*\$?\s*([\d.,]+)'),
        // "Importe: $45.000,50" or "IMPORTE 45.000,50"
        RegExp(r'[Ii]mporte:?\s*\$?\s*([\d.,]+)'),
        // "A Pagar: $45.000,50"
        RegExp(r'[Pp]agar:?\s*\$?\s*([\d.,]+)'),
        // "$45.000,50" - any price with $ sign
        RegExp(r'\$\s*([\d.,]+)'),
        // Large number that looks like a price (4+ digits)
        RegExp(r'\b(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)\b'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(fullText);
        if (match != null) {
          final rawValue = match.group(1)!;
          final value = _parseArgentinePrice(rawValue);

          debugPrint('OCR: Pattern matched "$rawValue", parsed as $value');

          if (value != null && value > 100) {
            debugPrint('OCR: Price extracted: $value from "$rawValue"');
            return OcrResult.found(value, rawValue, fullText);
          }
        }
      }

      debugPrint('OCR: No valid price pattern found in text');
      return OcrResult.failure(fullText);
    } catch (e, stack) {
      debugPrint('OCR Error extracting price: $e');
      debugPrint('OCR Stack trace: $stack');
      return OcrResult.failure();
    }
  }

  // Parse Argentine price format: "45.000,50" -> 45000.50
  double? _parseArgentinePrice(String priceStr) {
    // Remove spaces
    String cleaned = priceStr.trim();

    // Check if it has comma as decimal separator (Argentine format)
    // Format: "45.000,50" means 45000.50
    if (cleaned.contains(',')) {
      // Split by comma to separate integer and decimal parts
      final parts = cleaned.split(',');
      if (parts.length == 2) {
        // Remove dots from integer part (thousand separators)
        final integerPart = parts[0].replaceAll('.', '');
        final decimalPart = parts[1];
        cleaned = '$integerPart.$decimalPart';
      } else {
        // Just comma, no decimal part
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (cleaned.contains('.')) {
      // Check if dots are thousand separators or decimal
      // If there's only one dot and it's followed by 2 digits, it might be decimal
      final dotCount = '.'.allMatches(cleaned).length;
      if (dotCount > 1) {
        // Multiple dots = thousand separators, no decimal
        cleaned = cleaned.replaceAll('.', '');
      } else {
        // One dot - check if it's a thousand separator or decimal
        final afterDot = cleaned.split('.').last;
        if (afterDot.length == 3) {
          // Likely a thousand separator
          cleaned = cleaned.replaceAll('.', '');
        }
        // else keep it as decimal separator
      }
    }

    return double.tryParse(cleaned);
  }
}
