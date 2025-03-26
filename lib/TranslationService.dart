import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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
          language: "eng+tha+chi_sim+chi_tra+kor+fra+deu+por+jpn", // ใช้ภาษาไทยเป็นค่าเริ่มต้น
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
        case 'gemini':
          translatedText = await _translateWithGemini(text, toLanguage);
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

    try {
      // ตรวจสอบว่ามีภาษาผสมกันหรือไม่ และจัดการตามความเหมาะสม
      // หากมีภาษาผสมกัน ให้แบ่งข้อความเป็นส่วน ๆ และแปลแต่ละส่วนแยกกัน
      // หรือระบุภาษาต้นทางให้ชัดเจน
      var translated = await translator.translate(text, to: toLanguage);
      translateText = translated.text;
    } catch (e) {
      print('Translation Error: $e');
      return 'Error translating text: $e';
    }

    return translateText;
  }
  

  static Future<String> _translateWithGemini(String text, String toLanguage) async {
    const apiKey = 'AIzaSyDwBMED4tDbyG18wLcITg3kMCMV6OHFBwE'; // แทนที่ด้วย API key ของคุณ
    final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
    if(toLanguage == 'th'){
      toLanguage = 'thai';
    }

    try {
      final prompt = 'Translate $text to $toLanguage and provide only the translation without any explanation.';
      final result = await model.generateContent([Content.text(prompt)]);
      final translatedText = result.text;
      print('target language GEMINI: $toLanguage\n Text gemini : $text');

      if (translatedText != null && translatedText.isNotEmpty) {
        return translatedText.trim();
      } else {
        return "[$toLanguage] $text (Gemini Translation Failed)";
      }
    } catch (e) {
      print('Gemini Translation API Error: $e');
      return "[$toLanguage] $text (Gemini Translation Failed)";
    }
  }

  static Future<String> _translateWithGPT4omini(String text, String toLanguage) async {
    const apiKey = 'chat_API';  // Replace with your actual OpenAI API key (stored securely)
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": "You are a helpful translator."},
            {"role": "user", "content": "Translate \"$text\" to $toLanguage."}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Ensure the correct data is returned from the response
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'].trim();
        } else {
          return "Translation failed: No response from GPT-4o Mini.";
        }
      } else {
        return "Error: Unable to translate [$text] to $toLanguage. Status: ${response.statusCode}.";
      }
    } catch (e) {
      print('GPT-4o Mini Translation API Error: $e');
      return "Error: Translation failed for [$text] to $toLanguage.";
    }
  }
}

