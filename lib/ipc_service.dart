import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// บริการสำหรับการสื่อสารระหว่างโปรเซส (Inter-Process Communication)
class IPCService {
  // คำสั่งต่างๆ
  static const String COMMAND_TAKE_SCREENSHOT = 'take_screenshot';
  static const String COMMAND_NONE = '';

  // สถานะ
  static const String STATUS_PENDING = 'pending';
  static const String STATUS_PROCESSING = 'processing';
  static const String STATUS_COMPLETED = 'completed';
  static const String STATUS_FAILED = 'failed';

  /// ส่งคำสั่งถ่ายภาพหน้าจอจาก Overlay ไปยัง Main App
  static Future<void> sendCommand(String command) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ipc_command.json');

      final data = {
        'command': command,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': STATUS_PENDING
      };

      await file.writeAsString(json.encode(data));
      print('IPC: Command sent: $command');
    } catch (e) {
      print('IPC: Error sending command: $e');
    }
  }

  /// ตรวจสอบคำสั่งจาก Overlay (เรียกจาก Main App)
  static Future<String?> checkCommand() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ipc_command.json');

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      final command = data['command'] as String?;
      final status = data['status'] as String?;

      print('IPC: Checking command - found: $command, status: $status');

      if (command == COMMAND_TAKE_SCREENSHOT && status == STATUS_PENDING) {
        // อัปเดตสถานะเป็นกำลังประมวลผล
        data['status'] = STATUS_PROCESSING;
        await file.writeAsString(json.encode(data));
        return command;
      }

      return null;
    } catch (e) {
      print('IPC: Error checking command: $e');
      return null;
    }
  }

  /// แจ้งผลลัพธ์จาก Main App ไปยัง Overlay
  static Future<void> sendResult(bool success, String? path) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ipc_command.json');

      if (!await file.exists()) {
        return;
      }

      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;

      data['status'] = success ? STATUS_COMPLETED : STATUS_FAILED;
      if (path != null) {
        data['path'] = path;
      }

      await file.writeAsString(json.encode(data));
      print('IPC: Result sent - success: $success, path: $path');
    } catch (e) {
      print('IPC: Error sending result: $e');
    }
  }

  /// รอผลลัพธ์จาก Main App (เรียกจาก Overlay)
  static Future<String?> waitForResult(int timeoutSeconds) async {
    final stopwatch = Stopwatch()..start();
    print('IPC: Waiting for result');

    while (stopwatch.elapsed.inSeconds < timeoutSeconds) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/ipc_command.json');

        if (!await file.exists()) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;

        final status = data['status'] as String?;

        if (status == STATUS_COMPLETED) {
          final path = data['path'] as String?;
          print('IPC: Result received - path: $path');

          // รีเซ็ตคำสั่ง
          data['command'] = COMMAND_NONE;
          data['status'] = '';
          await file.writeAsString(json.encode(data));

          return path;
        } else if (status == STATUS_FAILED) {
          print('IPC: Result received - failed');

          // รีเซ็ตคำสั่ง
          data['command'] = COMMAND_NONE;
          data['status'] = '';
          await file.writeAsString(json.encode(data));

          return null;
        }

        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('IPC: Error waiting for result: $e');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    print('IPC: Timeout waiting for result');

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ipc_command.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;

        data['command'] = COMMAND_NONE;
        data['status'] = '';
        await file.writeAsString(json.encode(data));
      }
    } catch (e) {
      print('IPC: Error resetting command after timeout: $e');
    }

    return null;
  }

  /// เคลียร์คำสั่งทั้งหมด
  static Future<void> clearCommand() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/ipc_command.json');

      if (await file.exists()) {
        await file.delete();
      }

      print('IPC: Command cleared');
    } catch (e) {
      print('IPC: Error clearing command: $e');
    }
  }
}