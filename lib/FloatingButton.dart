import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screentranslator/SettingsScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'TranslationService.dart';

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
  final ValueNotifier<void> _settingsNotifier = ValueNotifier<void>(null);

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
    _settingsNotifier.addListener(_loadPreferences);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPreferences(); // โหลดค่าใหม่เมื่อมีการเปลี่ยนแปลง
  }

  @override
  void dispose() {
    _settingsNotifier.removeListener(_loadPreferences); // ลบ listener เมื่อ Widget ถูกทำลาย
    super.dispose();
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
        _targetLanguage = prefs.getString('defaultTargetLanguage') ?? 'th';
        _TranslateAPI = prefs.getString('selectedTranslationAPI') ?? 'google';
      });
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('defaultTargetLanguage', _targetLanguage);
      await prefs.setString('selectedTranslationAPI', _TranslateAPI);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  Future<void> _captureScreen() async {
    if (_isProcessing) return;

    setState(() {
      _isCapturing = true;
      _isProcessing = true;
      _extractedText = '';
      _translatedText = '';
    });

    try {
      await FlutterOverlayWindow.closeOverlay();
      await Future.delayed(const Duration(milliseconds: 500));

      final screenshotBytes = await screenshotController.capture();
      if (screenshotBytes != null) {
        final extractedText = await TranslationService.extractText(
          screenshotBytes,
          ocrEngine: 'tesseract',
        );

        setState(() {
          _extractedText = extractedText;
          _isCapturing = false;
        });

        if (_extractedText.isNotEmpty) {
          final translatedText = await TranslationService.translateText(
            _extractedText,
            toLanguage: _targetLanguage,
          );

          setState(() {
            _translatedText = translatedText;
          });
        }
      }
    } catch (e) {
      print('Error capturing screen: $e');
      setState(() {
        _extractedText = 'Error: $e';
      });
    } finally {
      setState(() {
        _isCapturing = false;
        _isProcessing = false;
      });

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: _isExpanded ? 500 : 100,
        width: _isExpanded ? 300 : 100,
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
      );
    }
  }

  void _toggleTranslateBar() {
    setState(() {
      _showTranslateBar = !_showTranslateBar;
    });
    _resizeOverlay();
  }

  void _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(settingsNotifier: _settingsNotifier),
      ),
    );
  }

  Future<void> _resizeOverlay() async {
    try {
      if (_showTranslateBar) {
        // Make sure we provide enough width for the translate bar to prevent overflow
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
    return ValueListenableBuilder<void>(
      valueListenable: _settingsNotifier,
      builder: (context, _, __) {
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
      },
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
    const double closeButtonWidth = 60.0;
    const double totalWidth = 320.0;
    const double whiteBarWidth = totalWidth - closeButtonWidth;

    return Container(
      width: totalWidth,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleTranslateBar,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      Expanded(
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
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
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF3854AF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () async {
                      setState(() => _isExpanded = false);
                      _toggleTranslateBar();
                    },
                  ),
                ],
              )
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _targetLanguage,
                      isExpanded: true,
                      items: _languageOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _targetLanguage = value);
                          _savePreferences();
                          if (_extractedText.isNotEmpty) _translateText();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _captureScreen,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                          _isProcessing ? 'Processing...' : 'Capture Screen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3854AF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  if (_isProcessing && !_isCapturing)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_extractedText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Extracted Text:',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _extractedText,
                        style: const TextStyle(fontSize: 14),
                        softWrap: true,
                      ),
                    ),
                  ],
                  if (_translatedText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Translated Text:',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F3FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _translatedText,
                        style: const TextStyle(fontSize: 14),
                        softWrap: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _translatedText.isEmpty
                      ? null
                      : () {
                    Clipboard.setData(
                        ClipboardData(text: _translatedText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied to clipboard')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: _translatedText.isEmpty ? null : () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {},
                ),
              ],
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