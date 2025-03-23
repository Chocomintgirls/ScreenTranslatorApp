import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// บริการจัดการการถ่ายภาพหน้าจอและสื่อสารระหว่าง overlay window กับ main app
class ScreenshotService {
  // Method channel สำหรับเรียกใช้ Native code
  static const MethodChannel _channel = MethodChannel('com.example.screentranslator');

  // คีย์สำหรับ shared preferences
  static const String COMMAND_KEY = 'overlay_command';
  static const String TIMESTAMP_KEY = 'command_timestamp';
  static const String RESULT_KEY = 'command_result';
  static const String SCREENSHOT_PATH_KEY = 'screenshot_path';

  // คำสั่ง
  static const String COMMAND_TAKE_SCREENSHOT = 'take_screenshot';
  static const String COMMAND_NONE = '';

  // สถานะ
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_PROCESSING = 'processing';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_FAILED = 'failed';

  static Future<SharedPreferences> _getSharedPrefs() async {
    return await SharedPreferences.getInstance().then((prefs) {
      print('Using SharedPreferences name: ${prefs.getString('pref_name') ?? 'default'}');
      return prefs;
    });
  }

  // Timer สำหรับตรวจสอบคำสั่ง
  static Timer? _commandCheckTimer;

  /// ขอสิทธิ์ถ่ายภาพหน้าจอจากผู้ใช้ (จะแสดง Dialog)
  static Future<bool> requestPermission() async {
    try {
      // ตรวจสอบว่ามีสิทธิ์อยู่แล้วหรือไม่
      final bool hasPermission = await _channel.invokeMethod('checkScreenshotPermission');

      // ถ้ายังไม่มีสิทธิ์ ให้ขอ
      if (!hasPermission) {
        return await _channel.invokeMethod('requestScreenshotPermission');
      }
      return true;
    } catch (e) {
      print('Error requesting screenshot permission: $e');
      return false;
    }
  }

  /// ถ่ายภาพหน้าจอทั้งหมดผ่าน Native API
  /// จะใช้ MediaProjection API ของ Android เพื่อถ่ายภาพหน้าจอทั้งหมด
  static Future<Uint8List?> captureScreen() async {
    try {
      // สร้างที่อยู่ไฟล์ชั่วคราว
      final directory = await getExternalStorageDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory!.path}/screenshot_$timestamp.png';

      // เรียกใช้ Method Channel เพื่อถ่ายภาพหน้าจอ
      final success = await _channel.invokeMethod('takeScreenshot', {'path': imagePath});

      if (success) {
        // อ่านไฟล์ที่บันทึกไว้
        final file = File(imagePath);
        if (await file.exists()) {
          // อ่านข้อมูลเป็น Uint8List
          final bytes = await file.readAsBytes();
          return bytes;
        }
      }
      return null;
    } catch (e) {
      print('Error capturing screen: $e');
      return null;
    }
  }

  /// บันทึกข้อมูลภาพถ่ายลงไฟล์
  static Future<String?> saveScreenshot(Uint8List bytes) async {
    try {
      final directory = await getExternalStorageDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory!.path}/screenshot_$timestamp.png';

      final file = File(imagePath);
      await file.writeAsBytes(bytes);

      return imagePath;
    } catch (e) {
      print('Error saving screenshot: $e');
      return null;
    }
  }

  //
  // ส่วนการสื่อสารระหว่าง overlay window และ main app
  //

  /// เริ่มตรวจสอบคำสั่งจาก overlay (เรียกจาก main app)
  static void startCommandChecker() {
    _commandCheckTimer?.cancel();
    _commandCheckTimer = Timer.periodic(
        const Duration(seconds: 1),
            (_) => _checkOverlayCommands()
    );
    print('Main: Started command checker');
  }

  /// หยุดตรวจสอบคำสั่งจาก overlay (เรียกจาก main app)
  static void stopCommandChecker() {
    _commandCheckTimer?.cancel();
    _commandCheckTimer = null;
    print('Main: Stopped command checker');
  }

  /// ตรวจสอบคำสั่งจาก overlay และดำเนินการ (เรียกภายในจาก timer)
// ใน screenshot_service.dart เพิ่ม logging ในเมธอดต่างๆ
  static Future<void> _checkOverlayCommands() async {
    try {
      final command = await checkForCommands();
      print('Main: Checking for commands, found: $command');

      if (command == COMMAND_TAKE_SCREENSHOT) {
        print('Main: Processing screenshot command');
        await _takeScreenshotFromCommand();
      }
    } catch (e) {
      print('Main: Error checking commands: $e');
    }
  }

  /// ส่งคำสั่งถ่ายภาพหน้าจอจาก overlay ไปยัง main app
  static Future<void> requestScreenshotFromMain() async {
    final prefs = await _getSharedPrefs();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    print('Overlay: Setting command key: $COMMAND_KEY to value: $COMMAND_TAKE_SCREENSHOT');

    await prefs.setString(COMMAND_KEY, COMMAND_TAKE_SCREENSHOT);
    await prefs.setInt(TIMESTAMP_KEY, timestamp);
    await prefs.setString(RESULT_KEY, STATUS_PENDING);

    // เพิ่มการตรวจสอบว่าบันทึกสำเร็จ
    final savedCommand = prefs.getString(COMMAND_KEY);
    print('Overlay: Verified saved command: $savedCommand');
  }


  /// เช็คคำสั่งจาก overlay (เรียกจาก main app)
  static Future<String?> checkForCommands() async {
    final prefs = await _getSharedPrefs();
    final command = prefs.getString(COMMAND_KEY);
    final status = prefs.getString(RESULT_KEY);

    print('Main: Command check - command: $command, status: $status');

    if (command == COMMAND_TAKE_SCREENSHOT && status == STATUS_PENDING) {
      // อัปเดตสถานะเป็นกำลังประมวลผล
      await prefs.setString(RESULT_KEY, STATUS_PROCESSING);
      return command;
    }

    return null;
  }

  /// ถ่ายภาพหน้าจอเมื่อได้รับคำสั่ง (เรียกภายใน)
  static Future<void> _takeScreenshotFromCommand() async {
    try {
      // สร้างที่อยู่ไฟล์
      final directory = await getExternalStorageDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory!.path}/screenshot_$timestamp.png';

      // เรียกใช้ native method เพื่อถ่ายภาพหน้าจอ
      final success = await _channel.invokeMethod('takeScreenshot', {'path': imagePath});

      if (success) {
        print('Main: Screenshot taken and saved at: $imagePath');
      } else {
        print('Main: Failed to take screenshot');
      }

      // แจ้งผลลัพธ์กลับไปยัง overlay
      await notifyScreenshotComplete(success, success ? imagePath : null);
    } catch (e) {
      print('Error taking screenshot: $e');
      await notifyScreenshotComplete(false, null);
    }
  }

  /// แจ้งว่าถ่ายภาพเสร็จแล้ว (เรียกจาก main app)
  static Future<void> notifyScreenshotComplete(bool success, String? imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (success && imagePath != null) {
        await prefs.setString(RESULT_KEY, STATUS_COMPLETED);
        await prefs.setString(SCREENSHOT_PATH_KEY, imagePath);
        print('Main: Notified completion with path: $imagePath');
      } else {
        await prefs.setString(RESULT_KEY, STATUS_FAILED);
        print('Main: Notified failure');
      }
    } catch (e) {
      print('Error notifying completion: $e');
    }
  }

  /// รอผลลัพธ์จาก main app (เรียกจาก overlay)
  static Future<String?> waitForScreenshotResult(int timeoutSeconds) async {
    final stopwatch = Stopwatch()..start();
    print('Overlay: Waiting for screenshot result');

    while (stopwatch.elapsed.inSeconds < timeoutSeconds) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final status = prefs.getString(RESULT_KEY);

        if (status == STATUS_COMPLETED) {
          final path = prefs.getString(SCREENSHOT_PATH_KEY);
          print('Overlay: Screenshot completed, path: $path');

          // รีเซ็ตสถานะ
          await prefs.setString(COMMAND_KEY, COMMAND_NONE);
          await prefs.setString(RESULT_KEY, '');

          return path;
        } else if (status == STATUS_FAILED) {
          print('Overlay: Screenshot failed');

          // รีเซ็ตสถานะ
          await prefs.setString(COMMAND_KEY, COMMAND_NONE);
          await prefs.setString(RESULT_KEY, '');

          return null;
        }

        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Error waiting for result: $e');
      }
    }

    print('Overlay: Timeout waiting for screenshot');

    // รีเซ็ตสถานะเมื่อหมดเวลา
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(COMMAND_KEY, COMMAND_NONE);
      await prefs.setString(RESULT_KEY, '');
    } catch (e) {
      print('Error resetting status: $e');
    }

    return null;
  }

  /// เคลียร์คำสั่งทั้งหมด
  static Future<void> clearCommands() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(COMMAND_KEY, COMMAND_NONE);
      await prefs.setString(RESULT_KEY, '');
      print('Command status cleared');
    } catch (e) {
      print('Error clearing commands: $e');
    }
  }
}