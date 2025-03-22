import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _defaultTargetLanguage = 'th';
  String _selectedOCREngine = 'tesseract';
  String _selectedTranslationAPI = 'google';
  bool _autoTranslate = true;
  bool _showOriginalText = true;

  final List<Map<String, String>> _languageOptions = [
    {'code': 'th', 'name': 'Thai'},
    {'code': 'en', 'name': 'English'},
    {'code': 'ja', 'name': 'Japanese'},
    {'code': 'zh-cn', 'name': 'Chinese (Simplified)'},
    {'code': 'ko', 'name': 'Korean'},
    {'code': 'fr', 'name': 'French'},
    {'code': 'de', 'name': 'German'},
    {'code': 'es', 'name': 'Spanish'},
    {'code': 'ru', 'name': 'Russian'},
    {'code': 'vi', 'name': 'Vietnamese'},
  ];

  final List<Map<String, String>> _ocrEngineOptions = [
    {'value': 'tesseract', 'name': 'Tesseract OCR'},
    {'value': 'mlkit', 'name': 'Google ML Kit'},
  ];

  final List<Map<String, String>> _translationAPIOptions = [
    {'value': 'google', 'name': 'Google Translate'},
    {'value': 'microsoft', 'name': 'Microsoft Translator'},
    {'value': 'deepl', 'name': 'DeepL'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultTargetLanguage = prefs.getString('defaultTargetLanguage') ?? 'th';
      _selectedOCREngine = prefs.getString('selectedOCREngine') ?? 'tesseract';
      _selectedTranslationAPI = prefs.getString('selectedTranslationAPI') ?? 'google';
      _autoTranslate = prefs.getBool('autoTranslate') ?? true;
      _showOriginalText = prefs.getBool('showOriginalText') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultTargetLanguage', _defaultTargetLanguage);
    await prefs.setString('selectedOCREngine', _selectedOCREngine);
    await prefs.setString('selectedTranslationAPI', _selectedTranslationAPI);
    await prefs.setBool('autoTranslate', _autoTranslate);
    await prefs.setBool('showOriginalText', _showOriginalText);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3854AF),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8CA0E0),
              Color(0xFFF8E7D5),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSettingSection(
              'Translation Settings',
              [
                _buildDropdownSetting(
                  'Default Target Language',
                  _defaultTargetLanguage,
                  _languageOptions.map((lang) => {
                    'value': lang['code']!,
                    'label': lang['name']!,
                  }).toList(),
                      (value) {
                    setState(() {
                      _defaultTargetLanguage = value!;
                    });
                  },
                ),
                _buildDropdownSetting(
                  'Translation API',
                  _selectedTranslationAPI,
                  _translationAPIOptions.map((api) => {
                    'value': api['value']!,
                    'label': api['name']!,
                  }).toList(),
                      (value) {
                    setState(() {
                      _selectedTranslationAPI = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingSection(
              'OCR Settings',
              [
                _buildDropdownSetting(
                  'OCR Engine',
                  _selectedOCREngine,
                  _ocrEngineOptions.map((engine) => {
                    'value': engine['value']!,
                    'label': engine['name']!,
                  }).toList(),
                      (value) {
                    setState(() {
                      _selectedOCREngine = value!;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingSection(
              'Behavior Settings',
              [
                _buildSwitchSetting(
                  'Auto Translate',
                  'Automatically translate text after OCR',
                  _autoTranslate,
                      (value) {
                    setState(() {
                      _autoTranslate = value;
                    });
                  },
                ),
                _buildSwitchSetting(
                  'Show Original Text',
                  'Display original text alongside translation',
                  _showOriginalText,
                      (value) {
                    setState(() {
                      _showOriginalText = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3854AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Save Settings',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3854AF),
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSetting<T>(
      String label,
      T value,
      List<Map<String, String>> options,
      Function(T?) onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: Container(),
              onChanged: onChanged,
              items: options.map((option) {
                return DropdownMenuItem<T>(
                  value: option['value'] as T,
                  child: Text(option['label']!),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting(
      String title,
      String subtitle,
      bool value,
      Function(bool) onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3854AF),
          ),
        ],
      ),
    );
  }
}