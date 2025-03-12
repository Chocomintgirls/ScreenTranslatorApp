import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';

// Add this class to handle the floating button
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Translate'),
        content: const Text('Screen content is being translated...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
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

// Shared background gradient for all screens
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.3),
          radius: 1.5,
          colors: [
            Color(0xFF8CA0E0), // Light blue
            Color(0xFF3854AF), // Darker blue
          ],
          stops: [0.0, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                // App title (ในบรรทัดเดียว)
                Text(
                  'Screen Translator',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const Spacer(flex: 1),

                // รูปภาพมือถือโทรศัพท์
                Image.asset(
                  'assets/images/translate_illustration.png', // ต้องแน่ใจว่ามีรูปภาพนี้ในโฟลเดอร์ assets
                  height: 400,
                ),

                const Spacer(flex: 1),

                // กล่องข้อความและปุ่ม
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Translate instantly, understand effortlessly.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: const Color(0xFF3854AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3854AF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TutorialScreen()),
                            );
                          },
                          child: Text(
                            'Get Started',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _currentPage = 0;

  final List<Map<String, dynamic>> tutorialData = [
    {
      'title': 'Press the button to start translation',
      'image': 'assets/images/tutorial_button.png',
    },
    {
      'title': 'A floating button will appear on all apps',
      'image': 'assets/images/tutorial_floating.png',
    },
    {
      'title': 'Tap the floating button to translate text on the screen',
      'image': 'assets/images/tutorial_translate.png',
    },
  ];

  void _nextPage() {
    setState(() {
      if (_currentPage < tutorialData.length - 1) {
        _currentPage++;
      } else {
        // Navigate to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // รูปภาพตรงกลาง (มือกดปุ่ม)
              Image.asset(
                tutorialData[_currentPage]['image'],
                height: 400,
              ),

              const SizedBox(height: 40),

              // ข้อความใต้รูปภาพ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  tutorialData[_currentPage]['title'],
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(flex: 1),

              // จุดแสดงหน้า (Pagination dots)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  tutorialData.length,
                      (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ปุ่ม Next
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3854AF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: _nextPage,
                    child: Text(
                      'Next',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // ข้อความ Skip
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                child: Text(
                  'skip',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isTranslationEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.3),
            radius: 1.5,
            colors: [
              Color(0xFF8CA0E0), // Light blue
              Color(0xFF3854AF), // Darker blue
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App title
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Screen',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Translator',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    // Settings button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        iconSize: 20,
                        onPressed: () {
                          // Open settings
                        },
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Center power button
                Center(
                  child: Column(
                    children: [
                      // Power button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isTranslationEnabled = !_isTranslationEnabled;
                            if (_isTranslationEnabled) {
                              // Show the floating button
                              _requestOverlayPermission();
                            } else {
                              // Hide the floating button
                              FloatingButtonService.hideFloatingButton();
                            }
                          });
                        },
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.power_settings_new,
                              size: 150,
                              color: _isTranslationEnabled
                                  ? const Color(0xFF51D95E)
                                  : const Color(0xFF3854AF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      // Status text
                      Text(
                        _isTranslationEnabled
                            ? 'Disable Translation Mode'
                            : 'Enable Translation Mode',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Method to request overlay permission and show floating button
  Future<void> _requestOverlayPermission() async {
    // In a real app, you would need to implement platform-specific code
    // to request the SYSTEM_ALERT_WINDOW permission on Android

    // For this example, we'll just show the floating button
    FloatingButtonService.showFloatingButton(context);

    // In reality, you would check permission status first:
    // bool hasPermission = await checkOverlayPermission();
    // if (hasPermission) {
    //   FloatingButtonService.showFloatingButton(context);
    // } else {
    //   // Request permission
    //   await requestOverlayPermission();
    // }
  }
}