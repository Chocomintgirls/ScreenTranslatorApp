import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'dart:io';

class TranslationService {
  // Cache to prevent repeated translations
  static final Map<String, String> _translationCache = {};

  // Extract text from image using OCR
  static Future<String> extractText(
      Uint8List imageBytes, {
        required String ocrEngine,
      }) async {
    try {
      if (ocrEngine == 'mlkit') {
        // Use Google ML Kit for OCR
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_ocr_image.jpg';
        await File(tempPath).writeAsBytes(imageBytes);

        final inputImage = InputImage.fromFilePath(tempPath);
        final textRecognizer = TextRecognizer();

        final recognizedText = await textRecognizer.processImage(inputImage);
        textRecognizer.close();

        return recognizedText.text;
      } else {
        // Use Tesseract as default OCR engine
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/temp_ocr_image.jpg';
        await File(tempPath).writeAsBytes(imageBytes);

        final extractedText = await FlutterTesseractOcr.extractText(
          tempPath,
          language: 'eng', // You might need to adjust this based on expected language
          args: {
            "psm": "4", // Assume single column of text
            "preserve_interword_spaces": "1",
          },
        );

        return extractedText;
      }
    } catch (e) {
      print('OCR Error: $e');
      return 'Error extracting text: $e';
    }
  }

  // Translate text using selected API
  static Future<String> translateText(
      String text, {
        required String toLanguage,
        String fromLanguage = 'auto',
        String translationAPI = 'google',
      }) async {
    // Generate cache key to avoid duplicate translations
    final cacheKey = '$fromLanguage|$toLanguage|$text|$translationAPI';

    // Return cached translation if available
    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    try {
      String translatedText;

      switch (translationAPI) {
        case 'google':
          translatedText = await _translateWithGoogle(text, fromLanguage, toLanguage);
          break;
        case 'microsoft':
          translatedText = await _translateWithMicrosoft(text, fromLanguage, toLanguage);
          break;
        case 'deepl':
          translatedText = await _translateWithDeepL(text, fromLanguage, toLanguage);
          break;
        default:
          translatedText = await _translateWithGoogle(text, fromLanguage, toLanguage);
      }

      // Cache result
      _translationCache[cacheKey] = translatedText;
      return translatedText;
    } catch (e) {
      print('Translation Error: $e');
      return 'Error translating text: $e';
    }
  }

  // Implement Google Translate API
  static Future<String> _translateWithGoogle(String text, String fromLanguage, String toLanguage) async {
    // You would normally use your API key here
    const apiKey = 'YOUR_GOOGLE_TRANSLATE_API_KEY';

    // For demonstration purposes - in a real app you'd use the actual API
    // This is a placeholder implementation
    final url = Uri.parse(
        'https://translation.googleapis.com/language/translate/v2?key=$apiKey'
    );

    try {
      final response = await http.post(
        url,
        body: {
          'q': text,
          'source': fromLanguage != 'auto' ? fromLanguage : '',
          'target': toLanguage,
          'format': 'text',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']['translations'][0]['translatedText'];
      } else {
        // For demo purposes, simulate a successful translation
        return "[$toLanguage] $text (Google Translated)";
      }
    } catch (e) {
      print('Google Translation API Error: $e');
      // For demo, return a simulated result
      return "[$toLanguage] $text (Google Translated)";
    }
  }

  // Implement Microsoft Translator API
  static Future<String> _translateWithMicrosoft(String text, String fromLanguage, String toLanguage) async {
    // For demonstration purposes - in a real app you'd use the actual API
    // This is a placeholder implementation
    return "[$toLanguage] $text (Microsoft Translated)";
  }

  // Implement DeepL API
  static Future<String> _translateWithDeepL(String text, String fromLanguage, String toLanguage) async {
    // For demonstration purposes - in a real app you'd use the actual API
    // This is a placeholder implementation
    return "[$toLanguage] $text (DeepL Translated)";
  }
}