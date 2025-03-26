import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screentranslator/screenshot_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'TranslationService.dart';
import 'ipc_service.dart';

class FloatingButton extends StatefulWidget {
  const FloatingButton({Key? key}) : super(key: key);

  @override
  _FloatingButtonState createState() => _FloatingButtonState();
}

class _FloatingButtonState extends State<FloatingButton> {
  bool _isExpanded = false;
  bool _isCapturing = false;
  bool _isProcessing = false;
  bool _showTranslateBar = false;
  String _extractedText = '';
  String _translatedText = '';
  String _targetLanguage = 'th';
  String _TranslateAPI = 'google';
  final screenshotController = ScreenshotController();
  bool _hasScreenshotPermission = false; // New variable to track permission

  final Map<String, String> _languageOptions = {
    'th': 'Thai',
    'en': 'English',
    'ja': 'Japanese',
    'zh-cn': 'Chinese',
    'ko': 'Korean',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
  };

  final Map<String, String> _translationAPIOptions = {
    'google': 'Google Translate',
    'microsoft': 'Microsoft Translator',
    'deepl': 'DeepL',
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPermissions();

    // Request screenshot permission at startup
    _requestScreenshotPermission();
  }

  Future<void> _requestScreenshotPermission() async {
    try {
      _hasScreenshotPermission = await ScreenshotService.requestPermission();
      print('Screenshot permission status: $_hasScreenshotPermission');
    } catch (e) {
      print('Error requesting screenshot permission: $e');
    }
  }

  Future<void> _checkPermissions() async {
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
    }

    if (Platform.isAndroid && int.parse(Platform.version.split('.')[0]) >= 13) {
      var status = await Permission.photos.request();
      if (!status.isGranted) print('Media permission denied');
    } else {
      var status = await Permission.storage.request();
      if (!status.isGranted) print('Storage permission denied');
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _targetLanguage = prefs.getString('targetLanguage') ?? 'th';
        _TranslateAPI = prefs.getString('TranslateAPI') ?? 'google';
      });
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('targetLanguage', _targetLanguage);
      await prefs.setString('TranslateAPI', _TranslateAPI);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

// Updated captureScreen method with error handling for foreground service restrictions
  Future<void> _captureScreen() async {
    if (_isProcessing) return;

    setState(() {
      _isCapturing = true;
      _isProcessing = true;
      _extractedText = '';
      _translatedText = '';
    });

    try {
      // Request notification permission for Android 13+ (required for foreground services)
      if (Platform.isAndroid) {
        // Check if we have POST_NOTIFICATIONS permission on Android 13+
        if (int.parse(Platform.version.split('.')[0]) >= 13) {
          var status = await Permission.notification.status;
          if (!status.isGranted) {
            status = await Permission.notification.request();
            if (!status.isGranted) {
              print("Notification permission denied. Foreground service may fail.");
            }
          }
        }
      }

      // Send screenshot command to Main App
      print("Overlay: Sending screenshot command");
      await IPCService.sendCommand(IPCService.COMMAND_TAKE_SCREENSHOT);

      // Close overlay temporarily so it doesn't appear in the screenshot
      print("Overlay: Closing overlay window");
      await FlutterOverlayWindow.closeOverlay();

      // Wait for overlay to disappear from screen
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        // Wait for result from Main App (timeout 15 seconds)
        print("Overlay: Waiting for screenshot result");
        final screenshotPath = await IPCService.waitForResult(15);

        if (screenshotPath != null) {
          print("Overlay: Screenshot saved at: $screenshotPath");
          // TODO: In the future, process the image here
          // For example, extract text and translate
        } else {
          print("Overlay: Failed to take screenshot");
        }
      } catch (e) {
        print("Overlay: Error waiting for screenshot: $e");
      }
    } catch (e) {
      print('Overlay: Error during screenshot process: $e');
    } finally {
      try {
        // Reopen overlay
        print("Overlay: Reopening overlay window");
        final overlayWidth = _showTranslateBar ? 320 : (_isExpanded ? 300 : 60);
        final overlayHeight = _showTranslateBar ? 60 : (_isExpanded ? 500 : 60);

        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          height: overlayHeight,
          width: overlayWidth,
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
        );
      } catch (e) {
        print("Overlay: Error reopening overlay: $e");
        // Try fallback method if showing overlay fails
        try {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: true,
            height: 60,
            width: 60,
            flag: OverlayFlag.defaultFlag,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
          );
        } catch (fallbackError) {
          print("Overlay: Fallback also failed: $fallbackError");
        }
      }

      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isProcessing = false;
        });
      }
    }
  }

  void _toggleTranslateBar() async {
    final newShowTranslateBar = !_showTranslateBar;

    // ปรับขนาด Overlay ก่อนอัปเดต UI
    await _resizeOverlay(newShowTranslateBar: newShowTranslateBar);

    if (mounted) {
      setState(() {
        _showTranslateBar = newShowTranslateBar;
      });
    }
  }

  Future<void> _resizeOverlay({bool? newShowTranslateBar}) async {
    final showTranslateBar = newShowTranslateBar ?? _showTranslateBar;

    try {
      if (showTranslateBar) {
        await FlutterOverlayWindow.resizeOverlay(320, 60, true);
      } else if (_isExpanded) {
        await FlutterOverlayWindow.resizeOverlay(300, 500, true);
      } else {
        await FlutterOverlayWindow.resizeOverlay(60, 60, true);
      }
    } catch (e) {
      print('Resize error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.topLeft,
        child: Screenshot(
          controller: screenshotController,
          child: _showTranslateBar
              ? _buildTranslateBar()
              : (_isExpanded ? _buildExpandedView() : _buildCollapsedView()),
        ),
      ),
    );
  }

  Widget _buildCollapsedView() {
    return GestureDetector(
      onTap: _toggleTranslateBar,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF3854AF),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.translate, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildTranslateBar() {
    // Calculate how much space we have for the white bar
    // Total width minus close button width (60) minus some padding
    const double closeButtonWidth = 60.0;
    const double totalWidth = 320.0; // Match this with the resizeOverlay width
    const double whiteBarWidth = totalWidth - closeButtonWidth;

    return Container(
      width: totalWidth,
      child: Stack(
        children: [
          // The actual translate bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min, // Do not stretch
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Close button
              GestureDetector(
              onTap: _toggleTranslateBar,
              child: Container(
                width: closeButtonWidth,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF3854AF),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),

            // White bar - with fixed width to prevent overflow
            Container(
              width: whiteBarWidth,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12), // Reduced padding
              child: Row(
                  mainAxisSize: MainAxisSize.min, // Do not stretch
                  children: [
              // Language dropdown - with smaller max width
              Container(
              constraints: const BoxConstraints(maxWidth: 60),
              child: DropdownButton<String>(
                value: _targetLanguage,
                underline: Container(),
                isDense: true, // Make dropdown more compact
                iconSize: 16, // Smaller icon
                icon: const Icon(Icons.keyboard_arrow_down),
                items: _languageOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // Smaller text
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _targetLanguage = value);
                    _savePreferences();
                  }
                },
              ),
            ),

            // Divider
            Container(
              height: 30,
              width: 1,
              color: Colors.grey[300],
              margin: const EdgeInsets.symmetric(horizontal: 4), // Reduced margin
            ),

            // API Dropdown - more compact
            Expanded(
              child: DropdownButton<String>(
                value: _TranslateAPI,
                underline: Container(),
                isDense: true, // Make dropdown more compact
                iconSize: 16, // Smaller icon
                icon: const Icon(Icons.keyboard_arrow_down),
                items: _translationAPIOptions.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // Smaller text
                      ),
                      overflow: TextOverflow.ellipsis, // Handle text overflow
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _TranslateAPI = value);
                    _savePreferences();
                  }
                },
              ),
            ),

                      // Camera icon - smaller
                      GestureDetector(
                        onTap: _captureScreen,
                        child: Container(
                          width: 30, // Reduced size
                          height: 30, // Reduced size
                          padding: const EdgeInsets.all(4), // Reduced padding
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[100],
                          ),
                          child: const Icon(Icons.translate, size: 18), // Smaller icon
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
// Container ของแถบสีขาว เปลี่ยนจากกำหนด width เป็น Expanded
          Expanded(
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8), // ลด padding
              child: Row(
                mainAxisSize: MainAxisSize.min, // Do not stretch
                children: [
                  // Language Dropdown
                  Container(
                    constraints: const BoxConstraints(maxWidth: 60),
                    child: DropdownButton<String>(
                      value: _targetLanguage,
                      underline: Container(),
                      isDense: true,
                      iconSize: 16,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _languageOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _targetLanguage = value);
                          _savePreferences();
                        }
                      },
                    ),
                  ),
                  // Divider
                  Container(
                    height: 30,
                    width: 1,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  // API Dropdown
                  Expanded( // ใช้ Expanded ที่นี่
                    child: DropdownButton<String>(
                      value: _TranslateAPI,
                      underline: Container(),
                      isDense: true,
                      iconSize: 16,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: _translationAPIOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _TranslateAPI = value);
                          _savePreferences();
                        }
                      },
                    ),
                  ),
                  // Camera Icon
                  GestureDetector(
                    onTap: _captureScreen,
                    child: Container(
                      width: 30,
                      height: 30,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                      ),
                      child: const Icon(Icons.translate, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  Future<void> _translateText() async {
    if (_extractedText.isEmpty) {
      setState(() {
        _translatedText = 'No text to translate';
        _isProcessing = false;
      });
      return;
    }

    try {
      final translatedText = await TranslationService.translateText(
        _extractedText,
        toLanguage: _targetLanguage,
      );

      setState(() {
        _translatedText = translatedText;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _translatedText = 'Translation error: $e';
        _isProcessing = false;
      });
    }
  }
}