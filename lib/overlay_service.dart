import 'dart:ui';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/material.dart';
import 'FloatingButton.dart';

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
        height: 150,
        width: 150,
        flag: OverlayFlag.focusPointer,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
      );
      print("showOverlay function completed");

      // Check if overlay is active
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