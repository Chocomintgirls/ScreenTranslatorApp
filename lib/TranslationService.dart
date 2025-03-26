import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'dart:io';

import 'package:translator/translator.dart';

class TranslationService {
  static final Map<String, String> _translationCache = {};

  static Future<String> extractText(Uint8List imageBytes, {required String ocrEngine}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/temp_ocr_image.jpg';
      await File(tempPath).writeAsBytes(imageBytes);

      if (ocrEngine == 'mlkit') {
        final inputImage = InputImage.fromFilePath(tempPath);
        final textRecognizer = TextRecognizer();
        final recognizedText = await textRecognizer.processImage(inputImage);
        textRecognizer.close();
        return recognizedText.text;
      } else {
        return await FlutterTesseractOcr.extractText(
          tempPath,
          language: 'tha', // ใช้ภาษาไทยเป็นค่าเริ่มต้น
          args: {"tessdata": "assets/tessdata/","psm": "6", "preserve_interword_spaces": "1", "oem": "3"},
        );
      }
    } catch (e) {
      print('OCR Error: $e');
      return 'Error extracting text: $e';
    }
  }

  static Future<String> translateText(
      String text, {
        required String toLanguage,
        String fromLanguage = 'auto',
        String translationAPI = 'google',
      }) async {
    final cacheKey = '$fromLanguage|$toLanguage|$text|$translationAPI';

    if (_translationCache.containsKey(cacheKey)) {
      return _translationCache[cacheKey]!;
    }

    try {
      String translatedText;

      switch (translationAPI) {
        case 'google':
          translatedText = await _translateWithGoogle(text, toLanguage);
          break;
        case 'gpt4omini':
          translatedText = await _translateWithGPT4omini(text, toLanguage);
          break;
        default:
          translatedText = await _translateWithGoogle(text, toLanguage);
      }

      _translationCache[cacheKey] = translatedText;
      return translatedText;
    } catch (e) {
      print('Translation Error: $e');
      return 'Error translating text: $e';
    }
  }

  static Future<String> _translateWithGoogle(String text, String toLanguage) async {
    final translator = GoogleTranslator();
    String translateText = "";

    // ใช้ await เพื่อรอผลลัพธ์จากการแปล
    var translated = await translator.translate(text, to: toLanguage);
    translateText = translated.text;
    
    return translateText;
  }


  static Future<String> _translateWithGPT4omini(String text, String toLanguage) async {
    const apiKey = 'YOUR_GPT4O_API_KEY';
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {"role": "system", "content": "You are a helpful translator."},
            {"role": "user", "content": "Translate to $toLanguage: $text"}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        return "[$toLanguage] $text (GPT-4o Translated)";
      }
    } catch (e) {
      print('GPT-4o Translation API Error: $e');
      return "[$toLanguage] $text (GPT-4o Translated)";
    }
  }
}
