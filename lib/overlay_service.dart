import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'main.dart';

class OverlayService {
  static Future<void> showFloatingButton() async {
    try {
      print("showFloatingButton called");

      final bool? isActive = await FlutterOverlayWindow.isActive();
      print("Current isActive status: $isActive");

      if (isActive == true) {
        print("Closing existing overlay");
        await FlutterOverlayWindow.closeOverlay();
      }

      print("About to show overlay");
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: 100,
        width: 100,
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
      );
      print("showOverlay function completed");

      // ตรวจสอบอีกครั้งว่า overlay กำลังแสดงหรือไม่
      final bool? newIsActive = await FlutterOverlayWindow.isActive();
      print("New isActive status: $newIsActive");

    } catch (e) {
      print("Error showing overlay: $e");
    }
  }

  static Future<void> hideFloatingButton() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}