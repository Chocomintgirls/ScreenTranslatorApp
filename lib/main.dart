// 

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:screentranslator/TranslationService.dart';

import 'FloatingButton.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  print("overlayMain started");
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: FloatingButton(),
      ),
    ),
  );
}

  // Future<void> checkTrainedDataFile() async {
  //   final filePath = 'assets/tessdata/eng.traineddata';

  //   try {
  //     final file = await rootBundle.load(filePath);
  //     print("✅ ไฟล์ $filePath ถูกโหลดสำเร็จ!");
  //   } catch (e) {
  //     print("❌ ไม่พบไฟล์ $filePath! ตรวจสอบ pubspec.yaml และโครงสร้างโฟลเดอร์อีกครั้ง");
  //   }
  // }

  // Future<void> copyTessData() async {
  //   try {
  //     // ดึงที่เก็บข้อมูลในเครื่อง
  //     final appDocDir = await getApplicationDocumentsDirectory();
  //     final tessDataDir = Directory('${appDocDir.path}/tessdata');

  //     // สร้าง directory tessdata ถ้ายังไม่มี
  //     if (!await tessDataDir.exists()) {
  //       await tessDataDir.create(recursive: true);
  //     }

  //     // คัดลอกไฟล์จาก assets ไปยัง tessdata directory
  //     final byteData = await rootBundle.load('assets/tessdata/eng.traineddata');
  //       if (byteData != null) {
  //         final file = File('${tessDataDir.path}/eng.traineddata');
  //         await file.writeAsBytes(byteData.buffer.asUint8List());
  //       } else {
  //         print("❌ ไม่พบไฟล์ eng.traineddata ใน assets");
  //       }

  //     print('✅ ไฟล์ tessdata คัดลอกสำเร็จ');
  //   } catch (e) {
  //     print('❌ ไม่สามารถคัดลอกไฟล์ tessdata: $e');
  //   }
  // }

void main() {
  WidgetsFlutterBinding.ensureInitialized(); //เพื่อให้copy tessdata เข้าเครื่อง emu ได้
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF24315B),
        scaffoldBackgroundColor: const Color(0xFFF8E7D5),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String extractedText = "กดปุ่มด้านล่างเพื่อสแกนข้อความ";
  String translatedText = "แปลข้อความจะปรากฏที่นี่";
  String selectedTranslationAPI = "google"; // ค่าเริ่มต้นเป็น Google Translate
  String selectedTargetLanguage = "th"; // ค่าเริ่มต้นเป็นภาษาไทย

  Future<void> pickImageAndExtractText(String ocrEngine) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final imageBytes = await File(pickedFile.path).readAsBytes();
    final text = await TranslationService.extractText(Uint8List.fromList(imageBytes), ocrEngine: ocrEngine);

    setState(() {
      extractedText = text;
    });
  }

  Future<void> translateExtractedText() async {
    if (extractedText.isEmpty || extractedText == "กดปุ่มด้านล่างเพื่อสแกนข้อความ") {
      return;
    }

    String translated = await TranslationService.translateText(
      extractedText,
      toLanguage: selectedTargetLanguage,
      translationAPI: selectedTranslationAPI,
    );

    setState(() {
      translatedText = translated;
    });
  }

  static Future<String> extractText(Uint8List imageBytes, {required String ocrEngine}) async {
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
      final extractedText = await FlutterTesseractOcr.extractText(
        tempPath,
        language: 'eng',
        args: {"psm": "4", "preserve_interword_spaces": "1"},
      );
      return extractedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("OCR และแปลภาษา")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              extractedText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => pickImageAndExtractText('mlkit'),
              child: Text("ทดสอบ ML Kit OCR"),
            ),
            ElevatedButton(
              onPressed: () => pickImageAndExtractText('tesseract'),
              child: Text("ทดสอบ Tesseract OCR"),
            ),
            SizedBox(height: 20),

            // Dropdown สำหรับเลือก API แปลภาษา
            DropdownButton<String>(
              value: selectedTranslationAPI,
              items: [
                DropdownMenuItem(value: "google", child: Text("Google Translate")),
                DropdownMenuItem(value: "gpt4o", child: Text("GPT-4o Mini")),
              ],
              onChanged: (value) {
                setState(() {
                  selectedTranslationAPI = value!;
                });
              },
            ),

            // Dropdown สำหรับเลือกภาษาปลายทาง
            DropdownButton<String>(
              value: selectedTargetLanguage,
              items: [
                DropdownMenuItem(value: "th", child: Text("แปลเป็นภาษาไทย")),
                DropdownMenuItem(value: "en", child: Text("แปลเป็นภาษาอังกฤษ")),
              ],
              onChanged: (value) {
                setState(() {
                  selectedTargetLanguage = value!;
                });
              },
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: translateExtractedText,
              child: Text("แปลข้อความ"),
            ),
            SizedBox(height: 20),
            Text(
              translatedText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }
}
