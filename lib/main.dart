import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'WelcomeScreen.dart';
import 'FloatingButton.dart';
import 'ipc_service.dart';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  print('Main: Starting application');

  // เริ่มการตรวจสอบคำสั่งจาก overlay ทุก 1 วินาที
  Timer.periodic(const Duration(seconds: 1), (_) async {
    final command = await IPCService.checkCommand();
    if (command == IPCService.COMMAND_TAKE_SCREENSHOT) {
      await _takeScreenshot();
    }
  });

  runApp(const MyApp());
}

Future<void> _takeScreenshot() async {
  print("Main: Starting screenshot process");
  try {
    final directory = await getExternalStorageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final imagePath = '${directory!.path}/screenshot_$timestamp.png';
    print("Main: Screenshot will be saved to: $imagePath");

    // เรียกใช้ Method Channel เพื่อเริ่ม Service โดยตรง
    bool success = false;
    try {
      final methodChannel = MethodChannel('com.yourapp.screenshot');
      print("Main: Starting screenshot service");

      // เรียกใช้ startScreenshotService แทน takeScreenshot
      success = await methodChannel.invokeMethod('startScreenshotService', {'path': imagePath});
      print("Main: Service start result: $success");

      // รอสักครู่เพื่อให้ Service มีเวลาทำงาน
      await Future.delayed(Duration(seconds: 5));

      // ตรวจสอบว่าไฟล์ถูกสร้างขึ้นมาหรือไม่
      final file = File(imagePath);
      final fileExists = await file.exists();
      print("Main: Screenshot file exists: $fileExists");

      success = fileExists;
    } catch (e) {
      print('Main: Error starting screenshot service: $e');
    }

    // แจ้งผลลัพธ์กลับไปยัง overlay
    print("Main: Sending result back to overlay: $success");
    await IPCService.sendResult(success, success ? imagePath : null);
  } catch (e) {
    print('Main: Error in _takeScreenshot: $e');
    await IPCService.sendResult(false, null);
  }
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