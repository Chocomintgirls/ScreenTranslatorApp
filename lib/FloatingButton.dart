import 'package:flutter/material.dart';

class FloatingButtonService {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  static void showFloatingButton(BuildContext context) {
    if (_isShowing) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => FloatingTranslateButton(),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isShowing = true;
  }

  static void hideFloatingButton() {
    if (!_isShowing) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }

  static bool get isShowing => _isShowing;
}

class FloatingTranslateButton extends StatefulWidget {
  const FloatingTranslateButton({Key? key}) : super(key: key);

  @override
  State<FloatingTranslateButton> createState() => _FloatingTranslateButtonState();
}

class _FloatingTranslateButtonState extends State<FloatingTranslateButton> {
  Offset position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            position = Offset(
              position.dx + details.delta.dx,
              position.dy + details.delta.dy,
            );
          });
        },
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF3854AF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.translate, color: Colors.white),
              onPressed: () {
                // Show translation UI or trigger translation
                _showTranslateDialog(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showTranslateDialog(BuildContext context) {
    String sourceLanguage = 'Thai';
    String targetLanguage = 'English';
    String translator = 'ChatGPT';
    List<String> languages = ['Thai', 'English', 'Chinese', 'Japanese', 'Korean'];
    List<String> translators = ['ChatGPT', 'Google Translate'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Translator selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: translators.map((option) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () {
                        translator = option;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: translator == option
                            ? const Color(0xFF3854AF)
                            : const Color(0xFFF2F2F2),
                        foregroundColor: translator == option
                            ? Colors.white
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(option),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Language selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _languageButton(sourceLanguage, languages, (newValue) {
                  sourceLanguage = newValue!;
                }),
                const Icon(Icons.arrow_forward, color: Colors.black),
                _languageButton(targetLanguage, languages, (newValue) {
                  targetLanguage = newValue!;
                }),
              ],
            ),
            const SizedBox(height: 20),

            // Translate button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                debugPrint('Translating from $sourceLanguage to $targetLanguage using $translator');
              },
              icon: const Icon(Icons.translate),
              label: const Text('Translate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3854AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageButton(String selectedLanguage, List<String> languages, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedLanguage,
          items: languages.map((String language) {
            return DropdownMenuItem<String>(
              value: language,
              child: Text(language),
            );
          }).toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
        ),
      ),
    );
  }


}