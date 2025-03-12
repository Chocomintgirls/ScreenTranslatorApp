import 'package:flutter/material.dart';
import 'GradientBackground.dart';
import 'package:google_fonts/google_fonts.dart';
import 'HomeScreen.dart';

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