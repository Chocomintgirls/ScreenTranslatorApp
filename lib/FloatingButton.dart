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
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

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
  String _targetLanguage = '';
  String _TranslateAPI = '';
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
    'gemini': 'Gemini AI',
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
      print("Overlay: Sending screenshot command");
      await IPCService.sendCommand(IPCService.COMMAND_TAKE_SCREENSHOT);

      print("Overlay: Closing overlay window");
      await FlutterOverlayWindow.closeOverlay();
      await Future.delayed(const Duration(milliseconds: 500));

      try {
        print("Overlay: Waiting for screenshot result");
        final screenshotPath = await IPCService.waitForResult(15);

        if (screenshotPath == null || screenshotPath.isEmpty) {
          print("Overlay: Screenshot path is null or empty.");
          return;
        }

        final file = File(screenshotPath);
        if (!await file.exists()) {
          print("Overlay: Screenshot file does not exist.");
          return;
        }

        print("Overlay: Screenshot saved at: $screenshotPath");

        // ดึงข้อความจากภาพ
        final extractedText = await FlutterTesseractOcr.extractText(
          screenshotPath,
          language: "eng+tha+chi_sim+chi_tra+kor+fra+deu+por+jpn",
          args: {
            "preserve_interword_spaces": "1",
            "psm": "6",
            "oem": "3"
          },
        );


        if (extractedText == null || extractedText.isEmpty) {
          print("Overlay: OCR did not extract any text.");
          return;
        }

        print("Overlay: Extracted Text: \n$extractedText");

        if (mounted) {
          setState(() {
            _extractedText = extractedText;
          });
        }

        await _translateText();

      } catch (e) {
        print("Overlay: Error processing image with Tesseract OCR: $e");
      }
    } catch (e) {
      print('Overlay: Error during screenshot process: $e');
    } finally {
      try {
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // แสดงภาษาที่เลือกแบบ text เฉยๆ
                      Expanded(
                        child: Row(
                          children: [
                            // ไอคอนภาษา
                            Icon(Icons.language, size: 16, color: Color(0xFF3854AF)),
                            SizedBox(width: 4),
                            // แสดงค่าภาษาที่เลือก
                            Text(
                              _languageOptions[_targetLanguage] ?? _targetLanguage.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF3854AF),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // เส้นแบ่ง
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),

                      // แสดง API ที่เลือกแบบ text เฉยๆ
                      Expanded(
                        child: Row(
                          children: [
                            // ไอคอน API
                            Icon(Icons.transform, size: 16, color: Color(0xFF3854AF)),
                            SizedBox(width: 4),
                            // แสดงค่า API ที่เลือก
                            Text(
                              _TranslateAPI.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF3854AF),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // ปุ่มแปล
                      GestureDetector(
                        onTap: _captureScreen,
                        child: Container(
                          width: 36,
                          height: 36,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF3854AF).withOpacity(0.1),
                          ),
                          child: const Icon(Icons.translate, size: 20, color: Color(0xFF3854AF)),
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
          // Header with controls
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3854AF),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button - ปรับให้เล็กกว่าเดิม
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = false;
                    });
                    _resizeOverlay();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                  ),
                ),

                // แสดงข้อมูลภาษาแบบกระชับ ใช้ SizedBox จำกัดขนาด
                SizedBox(
                  width: 120, // จำกัดความกว้าง
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "To: ",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      DropdownButton<String>(
                        value: _targetLanguage,
                        isDense: true, // ทำให้ dropdown กระชับมากขึ้น
                        underline: Container(), // ซ่อนเส้นใต้ปกติ
                        icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                        dropdownColor: Color(0xFF3854AF),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _targetLanguage = newValue;
                            });
                            _savePreferences(); // บันทึกค่าที่เลือกไว้
                          }
                        },
                        items: _languageOptions.entries
                            .map<DropdownMenuItem<String>>((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // API selector - ปรับให้เล็กลง
                DropdownButton<String>(
                  value: _TranslateAPI,
                  isDense: true,
                  underline: Container(),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                  dropdownColor: Color(0xFF3854AF),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _TranslateAPI = newValue;
                      });
                      _savePreferences();
                    }
                  },
                  items: _translationAPIOptions.entries
                      .map<DropdownMenuItem<String>>((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // ส่วนแสดงเนื้อหา (ไม่เปลี่ยนแปลง)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original text section
                  if (_extractedText.isNotEmpty) ...[
                    Text(
                      "Original Text:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _extractedText,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],

                  // Translated text section
                  if (_translatedText.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Translated (${_languageOptions[_targetLanguage] ?? _targetLanguage}):",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isProcessing)
                          IconButton(
                            icon: Icon(Icons.refresh, size: 18),
                            onPressed: _translateText,
                            tooltip: "Translate again",
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(width: 24, height: 24),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF3854AF).withOpacity(0.3)),
                      ),
                      child: _isProcessing
                          ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                          : Text(
                        _translatedText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ] else if (_isProcessing) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Translating..."),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Actions
                  const SizedBox(height: 16),
                  if (_translatedText.isNotEmpty && !_isProcessing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _translatedText));
                            // Show snackbar for feedback
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Translation copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          tooltip: "Copy translation",
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: (){
                            setState(() {
                              _isExpanded = false;
                            });
                            _resizeOverlay();
                          },
                          tooltip: "Close and return to floating button",
                        ),
                      ],
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
        translationAPI: _TranslateAPI, // ส่งค่า API ที่เลือกไป
      );

      setState(() {
        _translatedText = translatedText;
        _isProcessing = false;
      });

      // เมื่อแปลเรียบร้อยแล้ว ให้เปลี่ยนสถานะเป็น _isExpanded = true
      // เพื่อแสดงผลลัพธ์การแปลในมุมมองแบบขยาย
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _isExpanded = true;
      });
      await _resizeOverlay();

    } catch (e) {
      setState(() {
        _translatedText = 'Translation error: $e';
        _isProcessing = false;
      });
    }
  }
}